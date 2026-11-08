#!/usr/bin/env bash
# De Office Assistent bijwerken naar de nieuwste versie op GitHub: scripts en
# broncode ophalen, opnieuw bouwen en de gewijzigde containers herstarten.
# Wachtwoorden in .env blijven gelijk.
#
#   sudo /opt/oa-uitrol/server/bijwerken.sh

HIER="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$HIER/lib.sh"
moet_root
ROL="$(rol)"
cd "$OA_UITROL" || exit 1
[ -s .env ] || stop "Nog niet geïnstalleerd. Gebruik installeer.sh."
COMPOSE="$(compose_bestand "$ROL")"

meld "Bijwerken op $(vps_naam "$ROL")"
git pull --ff-only --quiet && ok "oa-uitrol $(git rev-parse --short HEAD)"
[ "$ROL" = toegang ] && vul_toegang_aan .env
./haal-op.sh >/dev/null && ok "Broncode opgehaald"
docker compose -f "$COMPOSE" --env-file .env pull --quiet --ignore-buildable
docker compose -f "$COMPOSE" --env-file .env build --quiet
docker compose -f "$COMPOSE" --env-file .env up -d --remove-orphans
docker image prune -f >/dev/null
ok "Bijgewerkt"
[ "$ROL" = diensten ] && echo "  Is OpenBao opnieuw gestart? Dan eerst: sudo $OA_UITROL/server/ontzegel.sh"
echo
