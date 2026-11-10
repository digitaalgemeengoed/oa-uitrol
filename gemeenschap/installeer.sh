#!/usr/bin/env bash
# INRICHTING.md stap 12 — het gemeenschapsplatform op VPS 4 installeren:
# Keycloak (realm gemeenschap), WordPress met BuddyPress, bbPress en CiviCRM,
# en Redmine. Wordt gestart door server/installeer.sh op een VPS met de rol
# "gemeenschap"; zelf starten kan ook:
#
#   sudo /opt/oa-uitrol/gemeenschap/installeer.sh
#
# Schrijft de eerste keer .env met nieuwe, willekeurige wachtwoorden en houdt
# die bij een volgende keer. Opnieuw draaien kan zonder schade.

HIER="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../server/lib.sh
. "$HIER/../server/lib.sh"
moet_root
[ "$(rol)" = gemeenschap ] || stop "Dit is geen VPS 4 (gemeenschap). Kies de rol met inrichten.sh."
cd "$OA_UITROL" || exit 1
COMPOSE=vps4-gemeenschap.yml
dc() { docker compose -f "$COMPOSE" --env-file .env "$@"; }

meld "Gemeenschapsplatform installeren op $(vps_naam gemeenschap)"

# --- Domein en DNS --------------------------------------------------------------
DOMEIN="$(sed -n 's/^DOMEIN=//p' .env 2>/dev/null || true)"
while [ -z "${DOMEIN:-}" ]; do
  read -r -p "  Domein van het platform (bijvoorbeeld digitaalgemeengoed.nl): " DOMEIN
  DOMEIN="${DOMEIN,,}"; DOMEIN="${DOMEIN#https://}"; DOMEIN="${DOMEIN%/}"
  geldig_domein "$DOMEIN" || { waarschuw "Dat is geen geldig domein."; DOMEIN=""; }
done
IP="$(publiek_ip)"
ONTBREEKT=0
for naam in "$DOMEIN" "www.$DOMEIN" "aanmelden.$DOMEIN" "projecten.$DOMEIN" "forum.$DOMEIN"; do
  gevonden="$(getent ahostsv4 "$naam" | awk 'NR==1{print $1}')"
  if [ "$gevonden" = "$IP" ]; then ok "$naam wijst naar deze server"; else waarschuw "$naam wijst naar '${gevonden:-niets}', niet naar $IP"; ONTBREEKT=1; fi
done
for naam in "$DOMEIN" "aanmelden.$DOMEIN" "projecten.$DOMEIN"; do
  gevonden="$(getent ahostsv4 "$naam" | awk 'NR==1{print $1}')"
  [ "$gevonden" = "$IP" ] || stop "Maak eerst in je DNS A-records naar $IP voor $DOMEIN, aanmelden.$DOMEIN en projecten.$DOMEIN (en liefst www. en forum.), wacht een kwartier en probeer opnieuw. Zonder die records kan Caddy geen certificaten halen."
done
[ "$ONTBREEKT" = 0 ] || waarschuw "www. en forum. zijn alleen doorverwijzingen; die kun je later toevoegen."

# --- .env -----------------------------------------------------------------------
if [ -s .env ]; then
  ok ".env bestaat al; wachtwoorden blijven gelijk"
else
  umask 077
  {
    echo "# Geschreven door gemeenschap/installeer.sh op $(date -I). Bevat wachtwoorden: niet delen."
    echo "DOMEIN=$DOMEIN"
    echo "KC_DB_WACHTWOORD=$(geheim 24)"
    echo "KC_BEHEERDER=beheer"
    echo "KC_BEHEERDER_WACHTWOORD=$(geheim 12)"
    echo "WP_DB_WACHTWOORD=$(geheim 24)"
    echo "WP_DB_ROOT_WACHTWOORD=$(geheim 24)"
    echo "WP_CLIENT_SECRET=$(geheim 32)"
    echo "WP_BEHEER_WACHTWOORD=$(geheim 12)"
    echo "REDMINE_DB_WACHTWOORD=$(geheim 24)"
    echo "REDMINE_CLIENT_SECRET=$(geheim 32)"
    echo "REDMINE_SYNC_SECRET=$(geheim 32)"
    echo "REDMINE_SECRET_KEY_BASE=$(geheim 64)"
    echo "REDMINE_API_KEY=$(geheim 20)"
    echo "REDMINE_ADMIN_WACHTWOORD=$(geheim 12)"
    echo "CIVICRM_VERSIE=6.20.0"
    echo "SMTP_HOST="
    echo "SMTP_POORT=587"
    echo "SMTP_GEBRUIKER="
    echo "SMTP_WACHTWOORD="
    echo "SMTP_AFZENDER=noreply@$DOMEIN"
  } > .env
  umask 022
  ok ".env geschreven met nieuwe wachtwoorden"
fi

# --- Mail ----------------------------------------------------------------------
# Zonder SMTP-dienst gaat er geen mail weg: geen bevestiging van het e-mailadres
# bij het aanmelden, geen nieuwsbrief, geen meldingen uit Redmine.
if ! grep -qE '^SMTP_HOST=.+' .env; then
  echo
  echo "  Mail gaat via een SMTP-dienst (bij voorkeur een Europese aanbieder). Zonder"
  echo "  SMTP kan niemand zich aanmelden: Keycloak stuurt een mail om het adres te bevestigen."
  if vraag_ja "  Nu de SMTP-gegevens invullen?"; then
    read -r -p "  Server (bijvoorbeeld smtp.aanbieder.nl): " H
    read -r -p "  Poort [587]: " P; P="${P:-587}"
    read -r -p "  Gebruiker: " U
    read -r -s -p "  Wachtwoord (je ziet niets terwijl je typt): " W; echo
    read -r -p "  Afzender [noreply@$DOMEIN]: " A; A="${A:-noreply@$DOMEIN}"
    for v in "$H" "$P" "$U" "$W" "$A"; do
      [[ "$v" =~ ^[A-Za-z0-9+/=.:_,@-]*$ ]] || stop "De SMTP-gegevens bevatten tekens die .env niet aankan (alleen letters, cijfers en + / = . : _ , @ -). Gebruik een ander wachtwoord of vul .env zelf in."
    done
    zet_env .env SMTP_HOST "$H"; zet_env .env SMTP_POORT "$P"; zet_env .env SMTP_GEBRUIKER "$U"
    zet_env .env SMTP_WACHTWOORD "$W"; zet_env .env SMTP_AFZENDER "$A"
    ok "SMTP ingesteld"
  else
    waarschuw "Geen SMTP: vul SMTP_HOST en de rest later in .env in en draai dan bijwerken.sh."
  fi
fi

# --- Images en starten -----------------------------------------------------------
meld "Images ophalen en bouwen (de eerste keer 5 tot 10 minuten)"
git -C "$OA_UITROL" pull --ff-only --quiet || waarschuw "oa-uitrol kon niet worden bijgewerkt; ik ga verder met deze versie"
dc pull --quiet --ignore-buildable --ignore-pull-failures 2>/dev/null || true
dc build --quiet
dc up -d --remove-orphans
ok "Gestart"

wacht() {
  local omschrijving="$1" n="$2"; shift 2
  printf '  wachten op %s ' "$omschrijving"
  for _ in $(seq "$n"); do
    if "$@" >/dev/null 2>&1; then echo; ok "$omschrijving antwoordt"; return 0; fi
    printf '.'; sleep 5
  done
  echo; return 1
}
wacht "Keycloak" 48 curl -fsS http://127.0.0.1:8080/realms/gemeenschap/.well-known/openid-configuration \
  || stop "Keycloak start niet. Kijk met: sudo docker compose -f $COMPOSE logs keycloak"
wacht "WordPress" 36 dc exec -T wordpress curl -fsS -o /dev/null http://localhost/wp-includes/images/blank.gif \
  || stop "WordPress start niet. Kijk met: sudo docker compose -f $COMPOSE logs wordpress"
wacht "Redmine" 60 dc exec -T redmine ruby -rnet/http -e 'exit Net::HTTP.get_response(URI("http://localhost:3000/login")).code.to_i < 400' \
  || stop "Redmine start niet. Kijk met: sudo docker compose -f $COMPOSE logs redmine"

# --- Inrichten -----------------------------------------------------------------------
meld "WordPress inrichten (BuddyPress, bbPress, CiviCRM)"
dc run --rm -T wpcli dg-inrichten || stop "WordPress inrichten mislukt. Kijk in de uitvoer hierboven; opnieuw draaien kan."
meld "Redmine inrichten"
dc exec -T redmine bundle exec rails runner /usr/local/share/dg/inrichten.rb || stop "Redmine inrichten mislukt."
dc restart redmine-groepen >/dev/null

# --- Back-up -------------------------------------------------------------------------
if [ ! -f /etc/cron.d/dg-gemeenschap ]; then
  echo "30 3 * * * root $OA_UITROL/gemeenschap/back-up.sh >/var/log/dg-back-up.log 2>&1" > /etc/cron.d/dg-gemeenschap
  ok "Dagelijkse back-up om 03:30 (gemeenschap/back-up.sh)"
fi

KC_BEHEERDER_WACHTWOORD="$(sed -n 's/^KC_BEHEERDER_WACHTWOORD=//p' .env)"
WP_BEHEER_WACHTWOORD="$(sed -n 's/^WP_BEHEER_WACHTWOORD=//p' .env)"
REDMINE_ADMIN_WACHTWOORD="$(sed -n 's/^REDMINE_ADMIN_WACHTWOORD=//p' .env)"
cat <<EOF

  Klaar. Het platform staat op:
      https://$DOMEIN                 site, leden, fora
      https://$DOMEIN/lid-worden/     aanmelden
      https://projecten.$DOMEIN       Redmine

  Noodaccounts (bewaar ze in je wachtwoordmanager; ze staan ook in $OA_UITROL/.env):
      Keycloak-beheer (via de SSH-tunnel):  beheer / $KC_BEHEERDER_WACHTWOORD
      WordPress (alleen met wp-cli):        beheer / $WP_BEHEER_WACHTWOORD
      Redmine (Inloggen met wachtwoord):    admin / $REDMINE_ADMIN_WACHTWOORD

  Volgende stappen (INRICHTING.md, stap 12):
    1. Meld jezelf aan via /lid-worden/ en zet jezelf in Keycloak in de groepen
       /site/beheer en /netwerk/kerngroep.
    2. Maak in Keycloak per gemeente een organisatie met het e-maildomein.
    3. Publiceer de pagina's Voorwaarden en Privacyverklaring (nu concept).
    4. Zet SPF, DKIM en DMARC voor $DOMEIN bij je SMTP-aanbieder.
EOF
