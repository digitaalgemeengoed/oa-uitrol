#!/usr/bin/env bash
# INRICHTING.md stap 3 — de basis van een VPS: bijwerken, beheerder, firewall, fail2ban,
# kernelinstellingen, automatische beveiligingsupdates, Docker en een
# WireGuard-sleutel. Draai als root, op elke VPS één keer:
#
#   /opt/oa-uitrol/server/inrichten.sh
#
# Het script zet het inloggen met wachtwoorden nog NIET uit; dat doet
# ssh-afsluiten.sh, pas nadat je hebt laten zien dat inloggen met je sleutel
# werkt. Opnieuw draaien kan zonder schade.

HIER="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$HIER/lib.sh"

BEHEERDER="${OA_BEHEERDER:-beheer}"
export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a

moet_root

# --- Besturingssysteem ------------------------------------------------------
. /etc/os-release
case "${ID}:${VERSION_ID}" in
  ubuntu:24.04|ubuntu:22.04|debian:12|debian:13) ok "Besturingssysteem: $PRETTY_NAME" ;;
  *) stop "Dit script is gemaakt voor Ubuntu 24.04/22.04 of Debian 12/13; deze server draait $PRETTY_NAME. Installeer bij de provider Ubuntu 24.04 opnieuw." ;;
esac

# --- Rol --------------------------------------------------------------------
meld "Welke VPS is dit?"
mkdir -p "$OA_MAP"; chmod 700 "$OA_MAP"
if [ -s "$OA_MAP/rol" ]; then
  ROL="$(cat "$OA_MAP/rol")"
  ok "Deze server is al ingericht als $(vps_naam "$ROL")."
else
  echo "  1) VPS 1 — toegang  (reverse proxy en integratielaag; de enige die van buiten bereikbaar is)"
  echo "  2) VPS 2 — platform (database, opslag, zoekindex)"
  echo "  3) VPS 3 — diensten (assistent-services, Keycloak, OpenBao)"
  echo "  4) VPS 4 — gemeenschap (WordPress, fora, CiviCRM, Redmine; los van de Office Assistent)"
  while :; do
    read -r -p "Kies 1, 2, 3 of 4: " k
    case "$k" in 1) ROL=toegang ;; 2) ROL=platform ;; 3) ROL=diensten ;; 4) ROL=gemeenschap ;; *) continue ;; esac
    vraag_ja "Dit is $(vps_naam "$ROL"). Klopt dat?" && break
  done
  echo "$ROL" > "$OA_MAP/rol"
fi

# --- Bijwerken en pakketten -------------------------------------------------
meld "Server bijwerken en pakketten installeren (duurt een paar minuten)"
apt-get update -q
apt-get -q -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold full-upgrade
apt-get -q -y install ufw fail2ban python3-systemd wireguard wireguard-tools unattended-upgrades \
  sudo curl ca-certificates git jq openssl gnupg
ok "Bijgewerkt"

# --- Naam en tijd -----------------------------------------------------------
NAAM="oa-$ROL"
[ "$ROL" = gemeenschap ] && NAAM="dg-gemeenschap"
hostnamectl set-hostname "$NAAM"
if grep -q '^127\.0\.1\.1' /etc/hosts; then
  sed -i "s/^127\.0\.1\.1.*/127.0.1.1 $NAAM/" /etc/hosts
else
  echo "127.0.1.1 $NAAM" >> /etc/hosts
fi
timedatectl set-timezone Europe/Amsterdam
timedatectl set-ntp true 2>/dev/null || true
ok "Servernaam $NAAM, tijdzone Europe/Amsterdam"

# --- Beheerder --------------------------------------------------------------
meld "Beheerder '$BEHEERDER'"
if ! id "$BEHEERDER" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "Beheer OA" "$BEHEERDER" >/dev/null
  ok "Gebruiker aangemaakt"
fi
usermod -aG sudo "$BEHEERDER"
SSHMAP="/home/$BEHEERDER/.ssh"
install -d -m 700 -o "$BEHEERDER" -g "$BEHEERDER" "$SSHMAP"
touch "$SSHMAP/authorized_keys"
if [ -s /root/.ssh/authorized_keys ] && ! [ -s "$SSHMAP/authorized_keys" ]; then
  cp /root/.ssh/authorized_keys "$SSHMAP/authorized_keys"
  ok "SSH-sleutel overgenomen van root (opgegeven bij de bestelling)"
fi
if ! grep -qE '^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp[0-9]+) ' "$SSHMAP/authorized_keys"; then
  echo "  Plak je publieke SSH-sleutel (één regel, begint met ssh-ed25519) en druk op Enter."
  echo "  Zie stap 1 van INRICHTING.md als je er nog geen hebt."
  while :; do
    read -r -p "  Sleutel: " SLEUTEL
    SLEUTEL="${SLEUTEL%$'\r'}"
    if [[ "$SLEUTEL" =~ ^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp[0-9]+)\ [A-Za-z0-9+/=]+(\ .*)?$ ]]; then
      echo "$SLEUTEL" >> "$SSHMAP/authorized_keys"; break
    fi
    if [[ "$SLEUTEL" == SHA256:* ]]; then
      waarschuw "Dat is de vingerafdruk, niet de sleutel. Typ op je eigen computer: cat ~/.ssh/<naam>.pub en plak die regel (begint met ssh-ed25519)."
    else
      waarschuw "Dat lijkt geen publieke sleutel. Let op: plak het bestand dat eindigt op .pub, niet de geheime sleutel."
    fi
  done
  ok "Sleutel toegevoegd"
fi
chown "$BEHEERDER:$BEHEERDER" "$SSHMAP/authorized_keys"; chmod 600 "$SSHMAP/authorized_keys"
if passwd -S "$BEHEERDER" | awk '{exit ($2 == "P") ? 0 : 1}'; then
  ok "Wachtwoord voor sudo is al ingesteld"
else
  echo "  Kies een wachtwoord voor '$BEHEERDER'. Dat heb je nodig bij 'sudo', niet bij het inloggen."
  echo "  Bewaar het in je wachtwoordmanager. (Je ziet niets terwijl je typt; dat hoort zo.)"
  until passwd "$BEHEERDER"; do :; done
fi

# --- Firewall ---------------------------------------------------------------
meld "Firewall (ufw)"
ufw --force default deny incoming >/dev/null
ufw --force default allow outgoing >/dev/null
ufw limit 22/tcp comment 'SSH' >/dev/null
if [ "$ROL" = toegang ] || [ "$ROL" = gemeenschap ]; then
  ufw allow 80/tcp comment 'HTTP (certificaten)' >/dev/null
  ufw allow 443/tcp comment 'HTTPS' >/dev/null
fi
ufw --force enable >/dev/null
case "$ROL" in
  toegang)     ok "Alleen SSH, HTTP en HTTPS open; WireGuard volgt bij het koppelen" ;;
  gemeenschap) ok "Alleen SSH, HTTP en HTTPS open" ;;
  *)           ok "Alleen SSH open; WireGuard volgt bij het koppelen" ;;
esac

# --- fail2ban ---------------------------------------------------------------
cat > /etc/fail2ban/jail.d/oa.conf <<'EOF'
[sshd]
enabled  = true
backend  = systemd
maxretry = 5
findtime = 10m
bantime  = 1h
EOF
systemctl enable --now fail2ban >/dev/null 2>&1
systemctl restart fail2ban
ok "fail2ban blokkeert wie vaker dan vijf keer fout inlogt"

# --- Kernel -----------------------------------------------------------------
cat > /etc/sysctl.d/90-oa.conf <<'EOF'
# Office Assistent — netwerk
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.default.rp_filter = 2
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
# Kernel
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.unprivileged_bpf_disabled = 1
net.core.bpf_jit_harden = 2
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
# Geheugen; OpenSearch heeft max_map_count nodig
vm.swappiness = 10
vm.max_map_count = 262144
EOF
sysctl -q --system
ok "Kernelinstellingen"

if ! swapon --show | grep -q .; then
  fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap -q /swapfile && swapon /swapfile
  grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
  ok "Wisselgeheugen van 2 GB als reserve"
fi

mkdir -p /etc/systemd/journald.conf.d
printf '[Journal]\nSystemMaxUse=500M\n' > /etc/systemd/journald.conf.d/oa.conf
systemctl restart systemd-journald

# --- Automatische beveiligingsupdates ---------------------------------------
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
# Bewust geen automatische herstart: na een herstart moet OpenBao op VPS 3
# met de hand worden ontzegeld, anders kan het platform niets ontsleutelen.
cat > /etc/apt/apt.conf.d/52oa <<'EOF'
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
EOF
systemctl enable --now unattended-upgrades >/dev/null 2>&1 || true
ok "Beveiligingsupdates worden elke dag automatisch geïnstalleerd (zonder herstart)"

# --- Docker -----------------------------------------------------------------
meld "Docker"
if ! command -v docker >/dev/null || ! docker compose version >/dev/null 2>&1; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/$ID/gpg" -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$ID $VERSION_CODENAME stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -q
  apt-get -q -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'EOF'
{
  "log-driver": "local",
  "log-opts": { "max-size": "20m", "max-file": "5" },
  "live-restore": true
}
EOF

# Docker pas starten als WireGuard er is: de containers luisteren op het
# WireGuard-adres en starten anders niet na een herstart. (Niet op VPS 4.)
if [ "$ROL" != gemeenschap ]; then
  mkdir -p /etc/systemd/system/docker.service.d
  cat > /etc/systemd/system/docker.service.d/oa-wireguard.conf <<'EOF'
[Unit]
After=wg-quick@wg0.service
Wants=wg-quick@wg0.service
EOF
fi

# Docker zet gepubliceerde poorten langs ufw heen. Dit filter bepaalt welke
# VPS welke containerpoort mag bereiken, en alleen via WireGuard.
install -m 755 "$HIER/docker-filter.sh" /usr/local/sbin/oa-docker-filter
cat > /etc/systemd/system/oa-docker-filter.service <<'EOF'
[Unit]
Description=OA: containerpoorten alleen via WireGuard en alleen voor de juiste VPS
Before=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/oa-docker-filter

[Install]
WantedBy=docker.service
EOF
systemctl daemon-reload
systemctl enable oa-docker-filter.service >/dev/null 2>&1
systemctl restart docker
/usr/local/sbin/oa-docker-filter
ok "Docker $(docker version --format '{{.Server.Version}}'), met filter voor containerpoorten"

# --- VPS 4: geen WireGuard, geen koppelen ----------------------------------
if [ "$ROL" = gemeenschap ]; then
  IP="$(publiek_ip)"
  meld "Klaar met de basis op $(vps_naam "$ROL")"
  cat <<EOF

  Volgende stap: log in een NIEUW venster in als $BEHEERDER:
      ssh $BEHEERDER@$IP
  en voer daar uit:
      sudo $OA_UITROL/server/ssh-afsluiten.sh
  Sluit dit venster pas als dat gelukt is. Daarna (geen koppelen nodig):
      sudo $OA_UITROL/server/installeer.sh
EOF
  [ -f /var/run/reboot-required ] && waarschuw "Er is een nieuwe kernel geïnstalleerd. Herstart de server na ssh-afsluiten.sh: sudo reboot"
  echo
  exit 0
fi

# --- WireGuard-sleutel ------------------------------------------------------
umask 077
mkdir -p "$WG_MAP"
[ -s "$WG_MAP/oa.key" ] || wg genkey > "$WG_MAP/oa.key"
wg pubkey < "$WG_MAP/oa.key" > "$WG_MAP/oa.pub"
umask 022

IP="$(publiek_ip)"
KIP="$(koppel_ip)"
meld "Klaar met de basis op $(vps_naam "$ROL")"
cat <<EOF

  Kopieer deze koppelregel naar Kladblok; je hebt hem nodig bij stap 5 (koppelen):

  OA-KOPPEL $ROL $KIP $(cat "$WG_MAP/oa.pub")

  Volgende stap: log in een NIEUW venster in als $BEHEERDER:
      ssh $BEHEERDER@$IP
  en voer daar uit:
      sudo $OA_UITROL/server/ssh-afsluiten.sh
  Sluit dit venster pas als dat gelukt is.
EOF
if [ "$KIP" = "$IP" ]; then
  waarschuw "Geen privénetwerk van de provider gevonden; WireGuard loopt via het publieke adres. Dat werkt ook (versleuteld)."
else
  ok "WireGuard loopt over het privénetwerk van de provider ($KIP); de WireGuard-poort gaat niet open op internet"
fi
if [ -f /var/run/reboot-required ]; then
  waarschuw "Er is een nieuwe kernel geïnstalleerd. Herstart de server na ssh-afsluiten.sh: sudo reboot"
fi
echo
