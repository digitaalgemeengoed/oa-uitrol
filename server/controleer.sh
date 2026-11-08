#!/usr/bin/env bash
# Hoe staat deze VPS ervoor? Verandert niets.
#
#   sudo /opt/oa-uitrol/server/controleer.sh

HIER="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$HIER/lib.sh"
moet_root
set +e

ROL="$(rol)"
meld "$(vps_naam "$ROL") — $(hostname), $(publiek_ip)"

meld "Beveiliging"
sshd -T 2>/dev/null | grep -qx "passwordauthentication no" && ok "SSH: alleen sleutels" || waarschuw "SSH: wachtwoorden staan nog aan (draai ssh-afsluiten.sh)"
sshd -T 2>/dev/null | grep -qx "permitrootlogin no" && ok "SSH: root kan niet inloggen" || waarschuw "SSH: root kan nog inloggen"
ufw status | grep -q "Status: active" && ok "Firewall aan" || waarschuw "Firewall staat uit"
systemctl is-active -q fail2ban && ok "fail2ban actief ($(fail2ban-client status sshd 2>/dev/null | sed -n 's/.*Currently banned:\s*//p') adressen geblokkeerd)" || waarschuw "fail2ban draait niet"
systemctl is-active -q unattended-upgrades && ok "Automatische beveiligingsupdates aan" || waarschuw "Automatische updates staan uit"
iptables -w -S DOCKER-USER 2>/dev/null | grep -q -- "-i wg0 -j DROP" && ok "Filter voor containerpoorten actief" || waarschuw "Filter voor containerpoorten ontbreekt: sudo systemctl restart oa-docker-filter"
if [ -f /var/run/reboot-required ]; then
  waarschuw "Herstart nodig voor updates: sudo reboot$( [ "$ROL" = diensten ] && echo "  (daarna ontzegel.sh)")"
else
  ok "Geen herstart nodig"
fi

meld "Privénetwerk (WireGuard)"
if systemctl is-active -q wg-quick@wg0; then
  for r in "${ROLLEN[@]}"; do
    [ "$r" = "$ROL" ] && continue
    ping -c 1 -W 2 "$(wg_ip "$r")" >/dev/null 2>&1 && ok "$(vps_naam "$r") bereikbaar" || waarschuw "$(vps_naam "$r") ($(wg_ip "$r")) niet bereikbaar"
  done
else
  waarschuw "WireGuard draait niet (nog niet gekoppeld?)"
fi

meld "Office Assistent"
if [ -s "$OA_UITROL/.env" ]; then
  ( cd "$OA_UITROL" && docker compose -f "$(compose_bestand "$ROL")" --env-file .env ps --format '  {{.Service}}: {{.Status}}' )
  case "$ROL" in
    platform) curl -fsS --max-time 5 "http://$(wg_ip platform):4100/gezondheid" | jq -r '"  platform: opslag \(.opslag), sleutels \(.sleutelbeheer), zoeken \(.zoekindex)"' || waarschuw "platform antwoordt niet" ;;
    diensten)
      cd "$OA_UITROL" || exit 1
      if docker compose -f vps3-diensten.yml --env-file .env exec -T sleutelbeheer bao status 2>/dev/null | grep -q 'Sealed *false'; then
        ok "OpenBao ontzegeld"
      else
        waarschuw "OpenBao is verzegeld of draait niet: sudo $OA_UITROL/server/ontzegel.sh"
      fi ;;
    toegang)
      DOMEIN="$(sed -n 's/^DOMEIN=//p' "$OA_UITROL/.env")"
      code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "https://oa.$DOMEIN/")"
      [[ "$code" =~ ^[23] ]] && ok "https://oa.$DOMEIN antwoordt ($code)" || waarschuw "https://oa.$DOMEIN antwoordt niet goed ($code)" ;;
  esac
else
  echo "  Nog niet geïnstalleerd."
fi

meld "Schijf en geheugen"
df -h / | awk 'NR==2{print "  schijf: " $3 " van " $2 " gebruikt (" $5 ")"}'
free -h | awk '/^Mem/{print "  geheugen: " $3 " van " $2 " in gebruik"}'
echo
