#!/usr/bin/env bash
# INRICHTING.md stap 5 — de drie VPS'en aan elkaar koppelen met WireGuard (een versleuteld
# privénetwerk 10.66.0.0/24) en de gedeelde sleutels verdelen.
#
#   Eerst op VPS 1:   sudo /opt/oa-uitrol/server/koppelen.sh
#                     plak de koppelregels van VPS 2 en VPS 3, geef het domein op;
#                     je krijgt een koppelblok voor VPS 2 en een voor VPS 3.
#   Dan op VPS 2 en 3: sudo /opt/oa-uitrol/server/koppelen.sh
#                     plak het koppelblok voor die VPS.
#
# De koppelblokken bevatten sleutels. Plak ze nergens anders dan op de VPS
# zelf en wis ze daarna uit Kladblok.

HIER="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$HIER/lib.sh"
moet_root

ROL="$(rol)"
EIGEN_SLEUTEL="$(cat "$WG_MAP/oa.pub" 2>/dev/null)" || stop "Geen WireGuard-sleutel. Draai eerst inrichten.sh."
EIGEN_IP="$(publiek_ip)"
GEDEELD="$OA_MAP/gedeeld.env"

# Schrijft wg0.conf uit de adressen en sleutels in gedeeld.env en zet de
# firewall open voor WireGuard vanaf de twee andere VPS'en.
maak_wireguard() {
  lees_env "$GEDEELD"
  local conf="$WG_MAP/wg0.conf" r ip sleutel
  umask 077
  {
    echo "# Office Assistent — privénetwerk tussen de drie VPS'en"
    echo "[Interface]"
    echo "Address = $(wg_ip "$ROL")/24"
    echo "ListenPort = $WG_POORT"
    echo "PrivateKey = $(cat "$WG_MAP/oa.key")"
    for r in "${ROLLEN[@]}"; do
      [ "$r" = "$ROL" ] && continue
      ip="$(printenv "${r^^}_IP")"; sleutel="$(printenv "${r^^}_SLEUTEL")"
      echo
      echo "# $(vps_naam "$r")"
      echo "[Peer]"
      echo "PublicKey = $sleutel"
      echo "Endpoint = $ip:$WG_POORT"
      echo "AllowedIPs = $(wg_ip "$r")/32"
      echo "PersistentKeepalive = 25"
    done
  } > "$conf"
  umask 022
  for r in "${ROLLEN[@]}"; do
    [ "$r" = "$ROL" ] && continue
    ufw allow from "$(printenv "${r^^}_IP")" to any port "$WG_POORT" proto udp comment "WireGuard $(vps_naam "$r")" >/dev/null
  done
  systemctl enable wg-quick@wg0 >/dev/null 2>&1
  systemctl restart wg-quick@wg0
  ok "WireGuard draait: dit is $(wg_ip "$ROL")"
}

test_verbindingen() {
  local r goed=1
  for r in "${ROLLEN[@]}"; do
    [ "$r" = "$ROL" ] && continue
    if ping -c 2 -W 2 "$(wg_ip "$r")" >/dev/null 2>&1; then
      ok "$(vps_naam "$r") bereikbaar via $(wg_ip "$r")"
    else
      waarschuw "$(vps_naam "$r") ($(wg_ip "$r")) nog niet bereikbaar"; goed=0
    fi
  done
  [ "$goed" = 1 ] || echo "  Dat is normaal zolang je die VPS nog niet hebt gekoppeld. Test later opnieuw: sudo $OA_UITROL/server/controleer.sh"
}

blok_voor() {
  local voor="$1"; shift
  { echo "VOOR=$voor"; printf '%s\n' "$@"; } | base64 -w0 | sed "s/^/OA-BLOK-$voor:/"
}

if [ "$ROL" = toegang ]; then
  meld "Koppelen op VPS 1 (toegang)"
  if [ -s "$GEDEELD" ] && ! vraag_ja "Deze VPS is al gekoppeld. Opnieuw beginnen (nieuwe sleutels; VPS 2 en 3 moeten dan ook opnieuw)?"; then
    lees_env "$GEDEELD"
  else
    echo "  Plak de koppelregels van VPS 2 en VPS 3 (ze beginnen met OA-KOPPEL)."
    PLATFORM_IP=""; DIENSTEN_IP=""
    while [ -z "$PLATFORM_IP" ] || [ -z "$DIENSTEN_IP" ]; do
      read -r regel || stop "Invoer afgebroken"
      regel="${regel%$'\r'}"
      read -r woord r ip sleutel _ <<<"$regel" || true
      [ "${woord:-}" = OA-KOPPEL ] || continue
      geldig_ip "$ip" && geldige_wg "$sleutel" || { waarschuw "Deze regel klopt niet, plak hem opnieuw: $regel"; continue; }
      case "$r" in
        platform) PLATFORM_IP="$ip"; PLATFORM_SLEUTEL="$sleutel"; ok "VPS 2 (platform): $ip" ;;
        diensten) DIENSTEN_IP="$ip"; DIENSTEN_SLEUTEL="$sleutel"; ok "VPS 3 (diensten): $ip" ;;
        toegang)  waarschuw "Dat is de regel van deze VPS zelf; die is niet nodig." ;;
        *)        waarschuw "Onbekende rol in: $regel" ;;
      esac
    done
    while :; do
      read -r -p "Domein (bijvoorbeeld prototype.digitaalgemeengoed.nl): " DOMEIN
      DOMEIN="${DOMEIN,,}"; DOMEIN="${DOMEIN%$'\r'}"
      geldig_domein "$DOMEIN" && break
      waarschuw "Dat is geen geldige domeinnaam."
    done
    umask 077
    cat > "$GEDEELD" <<EOF
DOMEIN=$DOMEIN
TOEGANG_IP=$EIGEN_IP
TOEGANG_SLEUTEL=$EIGEN_SLEUTEL
PLATFORM_IP=$PLATFORM_IP
PLATFORM_SLEUTEL=$PLATFORM_SLEUTEL
DIENSTEN_IP=$DIENSTEN_IP
DIENSTEN_SLEUTEL=$DIENSTEN_SLEUTEL
PLATFORM_DIENSTSLEUTEL=$(geheim)
DIENSTEN_DIENSTSLEUTEL=$(geheim)
OIDC_CLIENT_SECRET=$(geheim)
EOF
    umask 022
    lees_env "$GEDEELD"
  fi
  maak_wireguard

  NETWERK=(
    "DOMEIN=$DOMEIN"
    "TOEGANG_IP=$TOEGANG_IP" "TOEGANG_SLEUTEL=$TOEGANG_SLEUTEL"
    "PLATFORM_IP=$PLATFORM_IP" "PLATFORM_SLEUTEL=$PLATFORM_SLEUTEL"
    "DIENSTEN_IP=$DIENSTEN_IP" "DIENSTEN_SLEUTEL=$DIENSTEN_SLEUTEL"
  )
  meld "Koppelblokken"
  cat <<EOF

  Plak dit blok op VPS 2 (platform, $PLATFORM_IP):

$(blok_voor platform "${NETWERK[@]}" "PLATFORM_DIENSTSLEUTEL=$PLATFORM_DIENSTSLEUTEL")

  Plak dit blok op VPS 3 (diensten, $DIENSTEN_IP):

$(blok_voor diensten "${NETWERK[@]}" "DIENSTEN_DIENSTSLEUTEL=$DIENSTEN_DIENSTSLEUTEL" "OIDC_CLIENT_SECRET=$OIDC_CLIENT_SECRET")

  Elk blok is één lange regel. Ze bevatten sleutels: wis ze na gebruik uit Kladblok.
EOF
  test_verbindingen
  echo
  exit 0
fi

# --- VPS 2 en VPS 3 ---------------------------------------------------------
meld "Koppelen op $(vps_naam "$ROL")"
echo "  Plak het koppelblok voor deze VPS (het begint met OA-BLOK-$ROL:)."
while :; do
  read -r blok || stop "Invoer afgebroken"
  blok="${blok%$'\r'}"; blok="${blok// /}"
  case "$blok" in
    "OA-BLOK-$ROL:"*) break ;;
    OA-BLOK-*) waarschuw "Dit blok is voor een andere VPS (${blok%%:*}). Plak het blok voor $ROL." ;;
    "") ;;
    *) waarschuw "Dat is geen koppelblok." ;;
  esac
done
TIJDELIJK="$(mktemp)"; trap 'rm -f "$TIJDELIJK"' EXIT
printf '%s' "${blok#*:}" | base64 -d > "$TIJDELIJK" 2>/dev/null || stop "Het blok is beschadigd. Kopieer het opnieuw, als één regel."
lees_env "$TIJDELIJK"
[ "${VOOR:-}" = "$ROL" ] || stop "Het blok is niet voor deze VPS."
EIGEN_IN_BLOK="$(printenv "${ROL^^}_SLEUTEL")"
[ "$EIGEN_IN_BLOK" = "$EIGEN_SLEUTEL" ] || stop "De WireGuard-sleutel in het blok hoort niet bij deze server. Heb je de koppelregel van de goede VPS gebruikt?"
grep -v '^VOOR=' "$TIJDELIJK" > "$GEDEELD"; chmod 600 "$GEDEELD"
ok "Domein $DOMEIN en sleutels opgeslagen in $GEDEELD"
maak_wireguard
test_verbindingen
echo
echo "  Volgende stap: sudo $OA_UITROL/server/installeer.sh"
echo
