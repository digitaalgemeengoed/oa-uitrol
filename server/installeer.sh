#!/usr/bin/env bash
# INRICHTING.md stap 6 — de Office Assistent installeren en starten. Volgorde:
#   eerst VPS 3 (diensten), dan VPS 2 (platform), als laatste VPS 1 (toegang).
#
#   sudo /opt/oa-uitrol/server/installeer.sh
#
# Schrijft de eerste keer .env met nieuwe, willekeurige wachtwoorden en houdt
# die bij een volgende keer. Haalt de broncode op, bouwt de images en start.

HIER="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$HIER/lib.sh"
moet_root

ROL="$(rol)"
[ -s "$OA_MAP/gedeeld.env" ] || stop "Deze VPS is nog niet gekoppeld. Draai eerst koppelen.sh."
lees_env "$OA_MAP/gedeeld.env"
cd "$OA_UITROL" || exit 1
COMPOSE="$(compose_bestand "$ROL")"
dc() { docker compose -f "$COMPOSE" --env-file .env "$@"; }
NET="$WG_NET"

# Wacht tot een adres antwoordt; $3 is het aantal pogingen van 5 seconden.
wacht_op() {
  local omschrijving="$1" adres="$2" n="${3:-36}"
  printf '  wachten op %s ' "$omschrijving"
  for _ in $(seq "$n"); do
    if curl -fsS -o /dev/null --max-time 4 "$adres"; then echo; ok "$omschrijving antwoordt"; return 0; fi
    printf '.'; sleep 5
  done
  echo; return 1
}

meld "Installeren op $(vps_naam "$ROL")"

# --- Afhankelijkheden: draaien de VPS'en die deze nodig heeft al? ------------
case "$ROL" in
  platform)
    curl -s -o /dev/null --max-time 5 "http://$NET.3:8200/v1/sys/health" \
      || stop "OpenBao op VPS 3 is niet bereikbaar. Installeer eerst VPS 3 en kijk of koppelen gelukt is (controleer.sh)."
    ;;
  toegang)
    for doel in "platform http://$NET.2:4100/gezondheid" "diensten http://$NET.3:4200/gezondheid" \
                "Keycloak http://$NET.3:8080/realms/gemeenten/.well-known/openid-configuration"; do
      read -r naam url <<<"$doel"
      curl -fsS -o /dev/null --max-time 5 "$url" || stop "$naam is niet bereikbaar ($url). Installeer eerst VPS 3 en VPS 2."
      ok "$naam bereikbaar"
    done
    IP="$(publiek_ip)"
    for naam in "oa.$DOMEIN" "id.$DOMEIN"; do
      gevonden="$(getent ahostsv4 "$naam" | awk 'NR==1{print $1}')"
      [ "$gevonden" = "$IP" ] || stop "$naam wijst naar '${gevonden:-niets}', niet naar deze server ($IP). Maak in je DNS een A-record $naam → $IP, wacht een kwartier en probeer opnieuw."
      ok "$naam wijst naar deze server"
    done
    gevonden="$(getent ahostsv4 "office.$DOMEIN" | awk 'NR==1{print $1}')"
    if [ "$gevonden" = "$IP" ]; then
      ok "office.$DOMEIN wijst naar deze server (Collabora Online)"
    else
      waarschuw "office.$DOMEIN wijst nog niet naar deze server. Collabora Online werkt pas als je dat DNS-record maakt (A-record of CNAME naar $IP). De rest werkt wel."
    fi
    gevonden="$(getent ahostsv4 "oa-admin.$DOMEIN" | awk 'NR==1{print $1}')"
    if [ "$gevonden" = "$IP" ]; then
      ok "oa-admin.$DOMEIN wijst naar deze server (beheerportaal)"
    else
      waarschuw "oa-admin.$DOMEIN wijst nog niet naar deze server. Het beheerportaal werkt pas als je dat DNS-record maakt (A-record of CNAME naar $IP). De rest werkt wel."
    fi
    ;;
esac

# --- .env -------------------------------------------------------------------
if [ -s .env ]; then
  ok ".env bestaat al; wachtwoorden blijven gelijk"
else
  umask 077
  {
    echo "# Geschreven door server/installeer.sh op $(date -I). Bevat wachtwoorden: niet delen."
    echo "OA_VERSIE=0.2.0"
    echo "DOMEIN=$DOMEIN"
    echo "PRIVAAT_ADRES=$(wg_ip "$ROL")"
    case "$ROL" in
      toegang)
        echo "OA_AUTH=oidc"
        echo "PLATFORM_INTERN=http://$NET.2:4100"
        echo "DIENSTEN_INTERN=http://$NET.3:4200"
        echo "KEYCLOAK_INTERN=$NET.3:8080"
        echo "PLATFORM_DIENSTSLEUTEL=$PLATFORM_DIENSTSLEUTEL"
        echo "DIENSTEN_DIENSTSLEUTEL=$DIENSTEN_DIENSTSLEUTEL"
        echo "OIDC_CLIENT_SECRET=$OIDC_CLIENT_SECRET"
        echo "COMPOSE_PROFILES=collabora"
        echo "COLLABORA_INTERN=http://collabora:9980"
        echo "COLLABORA_VERSIE=26.04.5.2.1"
        ;;
      platform)
        echo "PLATFORM_DIENSTSLEUTEL=$PLATFORM_DIENSTSLEUTEL"
        echo "PG_BEHEER_WACHTWOORD=$(geheim 24)"
        echo "PG_APP_WACHTWOORD=$(geheim 24)"
        echo "S3_SLEUTEL=oa-$(geheim 6)"
        echo "S3_GEHEIM=$(geheim 24)"
        echo "SILO_VERSIE=RELEASE.2026-10-26T00-00-00Z"
        echo "GEMEENTEN=\"haarlem:Gemeente Haarlem,zandvoort:Gemeente Zandvoort\""
        echo "COMPOSE_PROFILES=zoeken"
        echo "ZOEKINDEX=opensearch"
        echo "OPENSEARCH_VERSIE=3.8.0"
        echo "OPENSEARCH_GEHEUGEN=2g"
        echo "SLEUTELBEHEER=openbao"
        echo "OPENBAO_INTERN=http://$NET.3:8200"
        echo "OPENBAO_TOKEN="
        ;;
      diensten)
        echo "DIENSTEN_DIENSTSLEUTEL=$DIENSTEN_DIENSTSLEUTEL"
        echo "OIDC_CLIENT_SECRET=$OIDC_CLIENT_SECRET"
        echo "KC_DB_WACHTWOORD=$(geheim 24)"
        echo "KC_BEHEERDER=beheer"
        echo "KC_BEHEERDER_WACHTWOORD=$(geheim 12)"
        echo "OA_TESTWACHTWOORD=Test-$(geheim 6)"
        echo "COMPOSE_PROFILES=sleutels"
        echo "OPENBAO_VERSIE=2.7.2"
        ;;
    esac
  } > .env
  umask 022
  ok ".env geschreven met nieuwe wachtwoorden"
fi
[ "$ROL" = toegang ] && vul_toegang_aan .env

# --- Token voor OpenBao (alleen platform) -----------------------------------
if [ "$ROL" = platform ] && ! grep -qE '^OPENBAO_TOKEN=.+' .env; then
  echo
  echo "  Plak het 'Token platform' dat installeer.sh op VPS 3 liet zien."
  while :; do
    read -r -s -p "  Token (je ziet niets terwijl je plakt): " TOKEN; echo
    TOKEN="${TOKEN%$'\r'}"; TOKEN="${TOKEN// /}"
    if [[ "$TOKEN" =~ ^[A-Za-z0-9._-]{20,}$ ]] && \
       curl -fsS -o /dev/null --max-time 5 -H "X-Vault-Token: $TOKEN" "http://$NET.3:8200/v1/auth/token/lookup-self"; then
      sed -i "s|^OPENBAO_TOKEN=.*|OPENBAO_TOKEN=$TOKEN|" .env
      ok "Token werkt"; break
    fi
    waarschuw "OpenBao kent dit token niet (of OpenBao is verzegeld: draai op VPS 3 ontzegel.sh). Probeer opnieuw."
  done
fi

# --- Broncode en images -----------------------------------------------------
meld "Broncode ophalen en bouwen (de eerste keer 5 tot 15 minuten)"
git -C "$OA_UITROL" pull --ff-only --quiet || waarschuw "oa-uitrol kon niet worden bijgewerkt; ik ga verder met deze versie"
./haal-op.sh >/dev/null || stop "De broncode ophalen van GitHub lukte niet. Probeer het straks opnieuw."
ok "Broncode opgehaald"
dc pull --quiet --ignore-buildable --ignore-pull-failures 2>/dev/null || true
dc build --quiet
ok "Images gebouwd"

meld "Starten"
dc up -d --remove-orphans
case "$ROL" in
  diensten)
    wacht_op "assistent-services" "http://$NET.3:4200/gezondheid" 24 || stop "De services starten niet. Kijk met: sudo docker compose -f $COMPOSE logs diensten"
    printf '  wachten op OpenBao '
    # bao status: 0 = open, 2 = verzegeld, 1 = niet bereikbaar
    for _ in $(seq 24); do
      rc=0; dc exec -T sleutelbeheer bao status >/dev/null 2>&1 || rc=$?
      [ "$rc" -ne 1 ] && break; printf '.'; sleep 5
    done; echo
    if dc exec -T sleutelbeheer bao status -format=json 2>/dev/null | grep -q '"initialized": true'; then
      ok "OpenBao was al ingericht"
      dc exec -T sleutelbeheer bao status 2>/dev/null | grep -q 'Sealed *false' || waarschuw "OpenBao is verzegeld. Ontzegel met: sudo $OA_UITROL/server/ontzegel.sh"
    else
      UIT="$(OA_ROOT_INTREKKEN=1 sh openbao/init.sh)" || { echo "$UIT"; stop "OpenBao inrichten mislukt."; }
      ONTZEGEL="$(echo "$UIT" | sed -n 's/^ *Ontzegelsleutel: *//p')"
      PLATFORMTOKEN="$(echo "$UIT" | sed -n 's/^ *Token platform: *//p')"
      cat <<EOF

  ┌──────────────────────────────────────────────────────────────────────┐
  │  BELANGRIJK — sla dit NU op in je wachtwoordmanager                  │
  └──────────────────────────────────────────────────────────────────────┘

  OpenBao-ontzegelsleutel:  $ONTZEGEL
      Nodig na elke herstart van deze VPS. Kwijt = alle versleutelde
      documenten onleesbaar. Hij staat NIET op de server.

  Token platform:           $PLATFORMTOKEN
      Alleen nodig bij de installatie van VPS 2; daarna niet meer bewaren.

EOF
      until vraag_ja "Heb je de ontzegelsleutel opgeslagen?"; do :; done
    fi
    wacht_op "Keycloak" "http://$NET.3:8080/realms/gemeenten/.well-known/openid-configuration" 36 \
      || stop "Keycloak start niet. Kijk met: sudo docker compose -f $COMPOSE logs keycloak"
    KC_BEHEERDER="$(sed -n 's/^KC_BEHEERDER=//p' .env)"
    KC_BEHEERDER_WACHTWOORD="$(sed -n 's/^KC_BEHEERDER_WACHTWOORD=//p' .env)"
    OA_TESTWACHTWOORD="$(sed -n 's/^OA_TESTWACHTWOORD=//p' .env)"
    cat <<EOF

  Keycloak-beheer (via de SSH-tunnel, zie INRICHTING.md):
      gebruiker $KC_BEHEERDER, wachtwoord $KC_BEHEERDER_WACHTWOORD
  Testgebruikers test.haarlem, test.zandvoort en beheer.haarlem:
      eerste wachtwoord $OA_TESTWACHTWOORD (bij de eerste inlog kies je een nieuw)
  Deze staan ook in $OA_UITROL/.env (alleen leesbaar voor root).

  Volgende stap: installeer.sh op VPS 2.
EOF
    ;;
  platform)
    wacht_op "platform" "http://$NET.2:4100/gezondheid" 36 || stop "Het platform start niet. Kijk met: sudo docker compose -f $COMPOSE logs platform migreer"
    curl -fsS "http://$NET.2:4100/gezondheid" | jq -r '"  opslag: \(.opslag), sleutelbeheer: \(.sleutelbeheer), zoekindex: \(.zoekindex)"'
    echo; echo "  Volgende stap: installeer.sh op VPS 1."
    ;;
  toegang)
    wacht_op "https://oa.$DOMEIN" "https://oa.$DOMEIN/" 36 || stop "De site antwoordt niet. Kijk met: sudo docker compose -f $COMPOSE logs proxy"
    cat <<EOF

  De Office Assistent draait:  https://oa.$DOMEIN
  De demo-werkomgeving:        https://oa.$DOMEIN/werkomgeving
  Collabora Online:            https://oa.$DOMEIN/collabora
  LibreOffice (extensie):      https://oa.$DOMEIN/libreoffice
  Word (manifest):             https://oa.$DOMEIN/word/manifest.xml
  Het beheerportaal:           https://oa-admin.$DOMEIN
  Log in met een testgebruiker (wachtwoord: zie de uitvoer op VPS 3).

  Het beheerportaal instellen: INRICHTING.md stap 9, te beginnen met
      sudo $OA_UITROL/server/beheer.sh nood
EOF
    ;;
esac
echo
