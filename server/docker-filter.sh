#!/usr/bin/env bash
# Filter voor de poorten die containers publiceren (keten DOCKER-USER).
#
# Docker opent gepubliceerde poorten buiten ufw om. De compose-bestanden
# binden de interne diensten al aan het WireGuard-adres; dit filter maakt het
# strikt: een containerpoort is alleen bereikbaar via wg0, en alleen voor de
# VPS die hem nodig heeft. Wat hier niet staat, komt er niet in.
#
#   toegang  (10.66.0.1): niets van binnenuit; 80/443 zijn publiek
#   platform (10.66.0.2): 4100 (platform)  ← toegang
#   diensten (10.66.0.3): 4200 (services)  ← toegang
#                         8080 (Keycloak)  ← toegang
#                         8200 (OpenBao)   ← platform
#   gemeenschap (VPS 4):  geen WireGuard; alleen 80/443 zijn publiek en
#                         Keycloak luistert op 127.0.0.1
#
# Draait vóór Docker start (oa-docker-filter.service); Docker laat de keten
# DOCKER-USER zelf ongemoeid.
set -euo pipefail

ROL="${1:-$(cat "${OA_MAP:-/etc/oa}/rol")}"
NET=10.66.0
case "$ROL" in
  toegang)  EIGEN=$NET.1; TOEGESTAAN=() ;;
  platform) EIGEN=$NET.2; TOEGESTAAN=("$NET.1 4100") ;;
  diensten) EIGEN=$NET.3; TOEGESTAAN=("$NET.1 4200" "$NET.1 8080" "$NET.2 8200") ;;
  gemeenschap)
    iptables -w -N DOCKER-USER 2>/dev/null || true
    iptables -w -F DOCKER-USER
    iptables -w -A DOCKER-USER -j RETURN
    exit 0 ;;
  *) echo "Onbekende rol: $ROL" >&2; exit 1 ;;
esac

ipt() { iptables -w "$@"; }

ipt -N DOCKER-USER 2>/dev/null || true
ipt -F DOCKER-USER
# Antwoorden op verbindingen die al bestaan (ook die de containers zelf opzetten).
ipt -A DOCKER-USER -m conntrack --ctstate RELATED,ESTABLISHED -j RETURN
for regel in "${TOEGESTAAN[@]}"; do
  read -r bron poort <<<"$regel"
  ipt -A DOCKER-USER -i wg0 -s "$bron" -p tcp -m conntrack --ctorigdst "$EIGEN" --ctorigdstport "$poort" -j RETURN
done
# Al het andere dat via WireGuard binnenkomt: weg.
ipt -A DOCKER-USER -i wg0 -j DROP
# Wie het WireGuard-adres via een andere netwerkkaart probeert: weg.
ipt -A DOCKER-USER -m conntrack --ctorigdst "$EIGEN" -j DROP
ipt -A DOCKER-USER -j RETURN
