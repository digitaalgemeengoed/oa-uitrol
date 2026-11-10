#!/usr/bin/env bash
# Het gemeenschapsplatform bijwerken: images (Keycloak, MariaDB, Postgres,
# Redmine, Caddy), en met wp-cli WordPress, de plugins, de vertalingen en
# CiviCRM. Wachtwoorden in .env blijven gelijk. Wordt gestart door
# server/bijwerken.sh op een VPS met de rol "gemeenschap".

HIER="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../server/lib.sh
. "$HIER/../server/lib.sh"
moet_root
[ "$(rol)" = gemeenschap ] || stop "Dit is geen VPS 4 (gemeenschap)."
cd "$OA_UITROL" || exit 1
[ -s .env ] || stop "Nog niet geïnstalleerd. Gebruik installeer.sh."
COMPOSE=vps4-gemeenschap.yml
dc() { docker compose -f "$COMPOSE" --env-file .env "$@"; }

meld "Bijwerken op $(vps_naam gemeenschap)"
vul_env_aan .env CIVICRM_VERSIE 6.20.0
dc pull --quiet --ignore-buildable --ignore-pull-failures 2>/dev/null || true
dc build --quiet
dc up -d --remove-orphans
if dc exec -T proxy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null 2>&1; then
  ok "Caddy herladen"
else
  waarschuw "Caddy herladen lukte niet; kijk met: sudo docker compose -f $COMPOSE logs proxy"
fi
printf '  wachten op WordPress '
for _ in $(seq 24); do dc exec -T wordpress curl -fsS -o /dev/null http://localhost/wp-includes/images/blank.gif 2>/dev/null && break; printf '.'; sleep 5; done; echo
dc run --rm -T wpcli dg-inrichten || waarschuw "WordPress bijwerken lukte niet helemaal; kijk in de uitvoer hierboven."
printf '  wachten op Redmine '
for _ in $(seq 36); do dc exec -T redmine ruby -rnet/http -e 'exit Net::HTTP.get_response(URI("http://localhost:3000/login")).code.to_i < 400' 2>/dev/null && break; printf '.'; sleep 5; done; echo
dc exec -T redmine bundle exec rails runner /usr/local/share/dg/inrichten.rb >/dev/null || waarschuw "Redmine inrichten lukte niet; kijk met: sudo docker compose -f $COMPOSE logs redmine"
docker image prune -f >/dev/null
ok "Bijgewerkt"
echo
