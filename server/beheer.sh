#!/usr/bin/env bash
# Het beheerportaal (oa-admin.<domein>) op VPS 1 instellen. Zie INRICHTING.md stap 9.
#
#   sudo /opt/oa-uitrol/server/beheer.sh nood       wachtwoord en TOTP van het noodaccount (opnieuw) instellen
#   sudo /opt/oa-uitrol/server/beheer.sh keycloak   het client-geheim uit keycloak-beheer.sh (VPS 3) plakken
#   sudo /opt/oa-uitrol/server/beheer.sh smtp       het e-mailaccount instellen
#   sudo /opt/oa-uitrol/server/beheer.sh status     draait het, en wat staat aan
#   sudo /opt/oa-uitrol/server/beheer.sh logs       de laatste regels van het portaal

HIER="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$HIER/lib.sh"
moet_root
[ "$(rol)" = toegang ] || stop "Het beheerportaal draait op VPS 1 (toegang). Dit is $(vps_naam "$(rol)")."
cd "$OA_UITROL" || exit 1
[ -s .env ] || stop "Nog niet geïnstalleerd. Gebruik eerst installeer.sh."
COMPOSE=vps1-toegang.yml
dc() { docker compose -f "$COMPOSE" --env-file .env "$@"; }
waarde() { sed -n "s/^$1=//p" .env | tail -1 | sed "s/^'\(.*\)'$/\1/"; }
DOMEIN="$(waarde DOMEIN)"

draait() { [ -n "$(dc ps -q --status running beheer 2>/dev/null)" ]; }

herstart() {
  dc up -d beheer >/dev/null
  printf '  wachten op het portaal '
  for _ in $(seq 24); do
    if dc exec -T beheer wget -q -O /dev/null --header="Host: oa-admin.$DOMEIN" http://127.0.0.1:4300/api/gezondheid 2>/dev/null; then
      echo; ok "Het portaal draait"; return 0
    fi
    printf '.'; sleep 5
  done
  echo
  dc logs --tail 20 beheer
  stop "Het portaal start niet; hierboven staat waarom."
}

case "${1:-}" in
  nood)
    meld "Noodaccount beheerder@$DOMEIN instellen"
    draait || stop "Het portaal draait niet. Draai eerst installeer.sh of bijwerken.sh."
    echo "  Een eerder wachtwoord en TOTP-geheim werken hierna niet meer; een open"
    echo "  noodsessie wordt beëindigd."
    vraag_ja "Doorgaan?" || exit 0
    dc run --rm --no-deps -T beheer-migreer node backend/dist/cli.js nood-instellen
    echo "  Daarna: https://oa-admin.$DOMEIN/emergency"
    echo
    ;;

  keycloak)
    meld "Inloggen via Keycloak aanzetten"
    echo "  Draai eerst op VPS 3:  sudo $OA_UITROL/server/keycloak-beheer.sh"
    echo "  Dat maakt de client 'oa-beheer' en toont het client-geheim."
    echo
    KC="$(waarde KEYCLOAK_INTERN)"
    while :; do
      read -r -s -p "  Client-geheim (je ziet niets terwijl je plakt): " S; echo
      S="${S%$'\r'}"; S="${S// /}"
      [[ "$S" =~ ^[A-Za-z0-9_-]{32,}$ ]] || { waarschuw "Dat lijkt geen client-geheim (minstens 32 letters en cijfers)."; continue; }
      # Keycloak zegt invalid_client bij een verkeerd geheim, en
      # unauthorized_client als het klopt (de client mag geen client_credentials).
      ANTWOORD="$(curl -s --max-time 10 -u "oa-beheer:$S" -d grant_type=client_credentials "http://$KC/realms/gemeenten/protocol/openid-connect/token" || true)"
      if echo "$ANTWOORD" | grep -q '"invalid_client"'; then
        waarschuw "Keycloak kent dit geheim niet voor oa-beheer. Kopieer het opnieuw uit de uitvoer op VPS 3."
        continue
      fi
      [ -n "$ANTWOORD" ] || waarschuw "Keycloak antwoordde niet; ik kan het geheim niet controleren en ga toch verder."
      break
    done
    zet_env .env BEHEER_OIDC_ISSUER "https://id.$DOMEIN/realms/gemeenten"
    zet_env .env BEHEER_OIDC_SECRET "$S"
    ok "Opgeslagen in .env"
    herstart
    cat <<UIT

  Log in op https://oa-admin.$DOMEIN met een Keycloak-gebruiker die in het
  portaal een account heeft (maak dat eerst aan via /emergency). Komt niemand
  binnen omdat Keycloak geen tweede factor meldt? Zet dan via /emergency bij
  Instellingen 'mfa.vereist' uit en kijk INRICHTING.md stap 9 na.

UIT
    ;;

  smtp)
    meld "E-mail instellen"
    echo "  De gegevens van je SMTP-account (bij je mailprovider te vinden)."
    read -r -p "  Server (bijvoorbeeld smtp.example.nl): " H
    [[ "$H" =~ ^[A-Za-z0-9.-]+$ ]] || stop "Dat is geen servernaam."
    read -r -p "  Poort [587]: " P; P="${P:-587}"
    [[ "$P" =~ ^[0-9]+$ ]] || stop "De poort is een getal."
    case "$P" in 465) T=tls ;; 25) T=geen ;; *) T=starttls ;; esac
    read -r -p "  Gebruikersnaam (vaak het e-mailadres): " G
    read -r -s -p "  Wachtwoord (je ziet niets): " W; echo
    read -r -p "  Afzender [OA-beheer <$G>]: " A; A="${A:-OA-beheer <$G>}"
    for v in "$G" "$W" "$A"; do
      [[ "$v" == *"'"* || "$v" == *$'\n'* ]] && stop "Een enkel aanhalingsteken (') kan niet in deze waarden."
    done
    # Het portaal start niet met een zwak SMTP-wachtwoord: minstens 8 tekens, 10 verschillende.
    if [ -n "$G" ] && { [ "${#W}" -lt 8 ] || [ "$(printf '%s' "$W" | fold -w1 | sort -u | wc -l)" -lt 10 ]; }; then
      stop "Het portaal weigert dit wachtwoord: het moet minstens 8 tekens hebben, waarvan 10 verschillende. Maak bij je mailprovider een sterker (app-)wachtwoord."
    fi
    zet_env .env SMTP_HOST "$H"
    zet_env .env SMTP_POORT "$P"
    zet_env .env SMTP_TLS "$T"
    zet_env .env SMTP_GEBRUIKER "'$G'"
    zet_env .env SMTP_WACHTWOORD "'$W'"
    zet_env .env SMTP_AFZENDER "'$A'"
    ok "Opgeslagen in .env (versleuteling: $T)"
    herstart
    echo "  Proberen: maak in het portaal een account aan; de uitnodiging gaat per e-mail."
    echo "  Komt er niets aan? sudo $0 logs"
    echo
    ;;

  status)
    meld "Beheerportaal"
    dc ps beheer beheer-db
    if draait; then ok "Het portaal draait"; else waarschuw "Het portaal draait niet"; fi
    if curl -fsS -o /dev/null --max-time 10 "https://oa-admin.$DOMEIN/api/gezondheid"; then ok "https://oa-admin.$DOMEIN antwoordt"; else waarschuw "https://oa-admin.$DOMEIN antwoordt niet (DNS-record oa-admin?)"; fi
    if [ -n "$(waarde BEHEER_OIDC_SECRET)" ]; then ok "Inloggen via Keycloak staat aan"; else waarschuw "Inloggen via Keycloak staat uit; alleen /emergency (beheer.sh keycloak)"; fi
    if [ -n "$(waarde SMTP_HOST)" ]; then ok "E-mail via $(waarde SMTP_HOST)"; else waarschuw "Geen e-mail ingesteld (beheer.sh smtp)"; fi
    echo
    ;;

  logs)
    dc logs --tail "${2:-50}" beheer
    ;;

  *)
    sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
