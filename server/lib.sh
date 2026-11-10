# Gedeelde hulpfuncties voor de serverscripts. Wordt ingelezen, niet gestart.
# shellcheck shell=bash

set -euo pipefail

OA_MAP="${OA_MAP:-/etc/oa}"
WG_MAP="${WG_MAP:-/etc/wireguard}"
OA_UITROL="${OA_UITROL:-/opt/oa-uitrol}"
WG_NET="10.66.0"
# shellcheck disable=SC2034  # gebruikt in de scripts die dit inlezen
WG_POORT=51820
# shellcheck disable=SC2034
ROLLEN=(toegang platform diensten)
# VPS 4 (gemeenschap) staat los van de Office Assistent: geen WireGuard, geen
# gedeeld.env. Daarom staat die rol niet in ROLLEN.

meld()     { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()       { printf '  \033[32m✓\033[0m %s\n' "$*"; }
waarschuw(){ printf '  \033[33m!\033[0m %s\n' "$*"; }
stop()     { printf '\n\033[1;31mGestopt:\033[0m %s\n\n' "$*" >&2; exit 1; }

moet_root() {
  [ "$(id -u)" -eq 0 ] || stop "Start dit script met sudo ervoor, bijvoorbeeld: sudo $0"
}

# Het nummer van een rol in het WireGuard-netwerk: 10.66.0.1, .2, .3
wg_nr() {
  case "$1" in toegang) echo 1 ;; platform) echo 2 ;; diensten) echo 3 ;; *) stop "Onbekende rol: $1" ;; esac
}
wg_ip() { echo "$WG_NET.$(wg_nr "$1")"; }

vps_naam() {
  case "$1" in toegang) echo "VPS 1 (toegang)" ;; platform) echo "VPS 2 (platform)" ;; diensten) echo "VPS 3 (diensten)" ;; gemeenschap) echo "VPS 4 (gemeenschap)" ;; esac
}

compose_bestand() {
  case "$1" in toegang) echo vps1-toegang.yml ;; platform) echo vps2-platform.yml ;; diensten) echo vps3-diensten.yml ;; gemeenschap) echo vps4-gemeenschap.yml ;; esac
}

rol() {
  [ -s "$OA_MAP/rol" ] || stop "Deze server heeft nog geen rol. Begin met inrichten.sh."
  cat "$OA_MAP/rol"
}

# Het publieke IPv4-adres: het bronadres van de route naar buiten.
publiek_ip() {
  ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i = 1; i < NF; i++) if ($i == "src") { print $(i + 1); exit }}'
}

# Het adres waarover WireGuard loopt: het adres in het privénetwerk van de
# provider als dat er is (bij Contabo 10.0.20.0/22), anders het publieke.
# Docker-, WireGuard- en veth-kaarten tellen niet mee.
koppel_ip() {
  local p
  p="$(ip -4 -o addr show scope global 2>/dev/null \
    | awk '$2 !~ /^(docker|br-|veth|wg|lo)/ {split($4, a, "/"); print a[1]}' \
    | grep -E '^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.)' | grep -v "^$WG_NET\." | head -1)"
  echo "${p:-$(publiek_ip)}"
}

vraag_ja() {
  local a
  read -r -p "$1 [ja/nee] " a
  [[ "${a,,}" =~ ^(j|ja|y|yes)$ ]]
}

# Willekeurig geheim, alleen hexadecimale tekens: veilig in .env, JSON en URL's.
geheim() { openssl rand -hex "${1:-32}"; }

# Leest een KEY=waarde-bestand zonder het als script uit te voeren.
# Alleen hoofdletters, cijfers en _ als naam; waarden zonder spaties of quotes.
lees_env() {
  local bestand="$1" regel naam waarde
  [ -f "$bestand" ] || return 0
  while IFS= read -r regel || [ -n "$regel" ]; do
    regel="${regel%$'\r'}"
    [[ -z "$regel" || "$regel" == \#* ]] && continue
    [[ "$regel" =~ ^([A-Z][A-Z0-9_]*)=([A-Za-z0-9+/=.:_,@-]*)$ ]] || stop "Onverwachte regel in $bestand: $regel"
    naam="${BASH_REMATCH[1]}"
    waarde="${BASH_REMATCH[2]}"
    printf -v "$naam" '%s' "$waarde"
    export "${naam?}"
  done < "$bestand"
}

# Voegt KEY=waarde aan .env toe als KEY er nog niet in staat. Zo krijgt een
# bestaande installatie nieuwe instellingen zonder dat wachtwoorden veranderen.
vul_env_aan() {
  local bestand="$1" naam="$2" waarde="$3"
  grep -q "^${naam}=" "$bestand" 2>/dev/null && return 0
  echo "${naam}=${waarde}" >> "$bestand"
  ok "Nieuwe instelling in .env: $naam"
}

# Nieuwe instellingen op VPS 1: Collabora Online (profiel "collabora", staat
# standaard aan) en het beheerportaal.
vul_toegang_aan() {
  # Beheerportaal: geheimen nieuw; Keycloak en SMTP leeg tot beheer.sh ze zet.
  vul_env_aan "$1" BEHEER_ADMIN_SECRET "$(geheim 32)"
  vul_env_aan "$1" BEHEER_DB_EIGENAAR_WACHTWOORD "$(geheim 24)"
  vul_env_aan "$1" BEHEER_DB_APP_WACHTWOORD "$(geheim 24)"
  vul_env_aan "$1" BEHEER_OIDC_ISSUER ""
  vul_env_aan "$1" BEHEER_OIDC_SECRET ""
  vul_env_aan "$1" COLLABORA_INTERN "http://collabora:9980"
  vul_env_aan "$1" COLLABORA_VERSIE "26.04.5.2.1"
  if grep -q '^COMPOSE_PROFILES=' "$1"; then
    grep -q '^COMPOSE_PROFILES=.*collabora' "$1" || sed -i 's/^COMPOSE_PROFILES=\(.*\)$/COMPOSE_PROFILES=\1,collabora/; s/^COMPOSE_PROFILES=,/COMPOSE_PROFILES=/' "$1"
  else
    vul_env_aan "$1" COMPOSE_PROFILES collabora
  fi
}

# Zet KEY=waarde in .env: vervangt een bestaande regel of voegt toe. De waarde
# komt er letterlijk in; aanhalingstekens moet de aanroeper zelf zetten.
zet_env() {
  local bestand="$1" naam="$2" waarde="$3" tijdelijk
  tijdelijk="$(mktemp "$bestand.XXXXXX")"
  grep -v "^${naam}=" "$bestand" > "$tijdelijk" || true
  printf '%s=%s\n' "$naam" "$waarde" >> "$tijdelijk"
  chmod 600 "$tijdelijk"
  mv "$tijdelijk" "$bestand"
}

geldig_domein() { [[ "$1" =~ ^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$ ]]; }
geldig_ip()     { [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; }
geldige_wg()    { [[ "$1" =~ ^[A-Za-z0-9+/]{42}[AEIMQUYcgkosw048]=$ ]]; }
