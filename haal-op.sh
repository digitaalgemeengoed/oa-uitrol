#!/usr/bin/env sh
# Haalt de repositories van het prototype op in ./bron, naast elkaar, en
# zet daar de workspace neer die ze lokaal aan elkaar koppelt.
#
# Gebruik: ./haal-op.sh [github-account] [branch]
#   standaard: ./haal-op.sh digitaalgemeengoed main
set -eu

ACCOUNT="${1:-digitaalgemeengoed}"
TAK="${2:-main}"
HIER="$(cd "$(dirname "$0")" && pwd)"
BRON="$HIER/bron"

mkdir -p "$BRON"

# Een tijdelijke hapering in DNS of netwerk: tot drie keer proberen.
probeer() {
  for poging in 1 2 3; do
    "$@" && return 0
    [ "$poging" -lt 3 ] && { echo "  opnieuw over 5 seconden ($poging/3)…" >&2; sleep 5; }
  done
  echo "Mislukt na drie pogingen: $*" >&2
  return 1
}

for REPO in oa-contract opendop-mini oa-services oa-kern oa-paneel oa-adapters oa-integratielaag oa-beheer; do
  if [ -d "$BRON/$REPO/.git" ]; then
    probeer git -C "$BRON/$REPO" fetch --quiet origin "$TAK"
    git -C "$BRON/$REPO" checkout --quiet "$TAK"
    git -C "$BRON/$REPO" merge --quiet --ff-only "origin/$TAK"
  else
    probeer git clone --quiet --branch "$TAK" "https://github.com/$ACCOUNT/$REPO.git" "$BRON/$REPO"
  fi
  echo "✓ $REPO"
done
cp "$HIER/werkplaats/package.json" "$HIER/werkplaats/package-lock.json" "$BRON/"
echo "Klaar. Bouw met: docker compose -f lokaal.yml build"
