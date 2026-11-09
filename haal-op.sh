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

for REPO in oa-contract opendop-mini oa-services oa-kern oa-paneel oa-adapters oa-integratielaag oa-beheer oa-wcag; do
  if [ -d "$BRON/$REPO/.git" ]; then
    probeer git -C "$BRON/$REPO" fetch --quiet origin "$TAK"
    git -C "$BRON/$REPO" checkout --quiet "$TAK"
    git -C "$BRON/$REPO" merge --quiet --ff-only "origin/$TAK"
  else
    probeer git clone --quiet --branch "$TAK" "https://github.com/$ACCOUNT/$REPO.git" "$BRON/$REPO"
  fi
  echo "✓ $REPO"
done

# OpenAnonymiser (Conduction, EUPL-1.2): herkenning van persoonsgegevens voor
# de module Anonimiseren. Op een vaste versie: een nieuwe versie kies je hier
# bewust, nadat je hem hebt bekeken. We bouwen het image zelf uit de broncode.
OPENANONYMISER_REPO="https://github.com/ConductionNL/anonymiq-light.git"
OPENANONYMISER_VERSIE="3dbe833d1705eb0e7928badbb55de424fe9beee5"
if [ ! -d "$BRON/openanonymiser/.git" ]; then
  probeer git clone --quiet "$OPENANONYMISER_REPO" "$BRON/openanonymiser"
fi
if ! git -C "$BRON/openanonymiser" cat-file -e "$OPENANONYMISER_VERSIE^{commit}" 2>/dev/null; then
  probeer git -C "$BRON/openanonymiser" fetch --quiet origin
fi
git -C "$BRON/openanonymiser" -c advice.detachedHead=false checkout --quiet "$OPENANONYMISER_VERSIE"
echo "✓ openanonymiser (${OPENANONYMISER_VERSIE%"${OPENANONYMISER_VERSIE#???????}"})"

cp "$HIER/werkplaats/package.json" "$HIER/werkplaats/package-lock.json" "$BRON/"
echo "Klaar. Bouw met: docker compose -f lokaal.yml build"
