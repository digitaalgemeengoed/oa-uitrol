#!/usr/bin/env bash
# INRICHTING.md stap 4 — SSH dichtzetten: geen root, geen wachtwoorden, alleen de beheerder
# met een sleutel. Draai dit als beheerder, met sudo, NADAT je met je sleutel
# bent ingelogd. Het script controleert dat eerst; zo kun je jezelf niet
# buitensluiten.
#
#   sudo /opt/oa-uitrol/server/ssh-afsluiten.sh

HIER="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$HIER/lib.sh"
moet_root

WIE="${SUDO_USER:-}"
[ -n "$WIE" ] && [ "$WIE" != root ] || stop "Log in als beheerder (ssh beheer@<adres>) en start dit script met sudo. Niet als root."

meld "Controleren dat $WIE met een sleutel kan inloggen"
# Eerst de uitvoer vangen en dan zoeken: met pipefail kan "… | grep -q" vals
# mislukken, omdat grep na de eerste treffer stopt en de schrijver dan SIGPIPE krijgt.
LOG="$(journalctl -t sshd -t sshd-session -S -6h --no-pager 2>/dev/null || true)"
if grep -q "Accepted publickey for $WIE " <<<"$LOG"; then
  ok "$WIE is de afgelopen uren met een sleutel ingelogd"
else
  stop "Ik zie geen inlog van $WIE met een sleutel. Ben je met een wachtwoord ingelogd? Kijk bij stap 1 en 3 van INRICHTING.md en probeer opnieuw: ssh -i <jouw sleutel> $WIE@<adres>"
fi

meld "SSH dichtzetten"
cat > /etc/ssh/sshd_config.d/00-oa.conf <<EOF
# Office Assistent. Dit bestand gaat vóór de andere (ook vóór 50-cloud-init.conf).
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
AllowUsers $WIE
MaxAuthTries 3
LoginGraceTime 30
X11Forwarding no
AllowAgentForwarding no
# Alleen tunnels van jouw computer naar de server (voor Keycloak-beheer).
AllowTcpForwarding local
ClientAliveInterval 300
ClientAliveCountMax 2
EOF
sshd -t || { rm -f /etc/ssh/sshd_config.d/00-oa.conf; stop "De SSH-instellingen kloppen niet; er is niets veranderd."; }
SSHD="$(sshd -T 2>/dev/null || true)"
for instelling in "permitrootlogin no" "passwordauthentication no" "kbdinteractiveauthentication no"; do
  grep -qx "$instelling" <<<"$SSHD" || stop "Na het wijzigen geldt '$instelling' nog niet. Er staat een ander bestand in /etc/ssh/sshd_config.d dat voorgaat."
done
systemctl reload ssh 2>/dev/null || systemctl reload sshd
ok "Root kan niet meer inloggen via SSH; wachtwoorden werken niet meer; alleen $WIE met een sleutel"

cat <<EOF

  Test dit nu in een NIEUW venster, voordat je dit venster sluit:
      ssh $WIE@$(publiek_ip)      → moet werken
      ssh root@$(publiek_ip)      → moet geweigerd worden

  Het root-wachtwoord blijft geldig voor de noodconsole (VNC) van de
  provider. Bewaar het in je wachtwoordmanager.
EOF
if [ -f /var/run/reboot-required ]; then
  echo
  waarschuw "Herstart de server voor de nieuwe kernel: sudo reboot  (daarna verder met stap 5, koppelen)"
fi
echo
