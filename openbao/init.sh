#!/usr/bin/env sh
# Eerste inrichting van OpenBao op VPS 3, na
#   docker compose -f vps3-diensten.yml --profile sleutels up -d sleutelbeheer
#
# Initialiseert met één ontzegelsleutel (prototype; in productie 3 van 5 en
# auto-unseal), ontzegelt, zet de transit-engine aan en maakt een periodiek
# token voor het platform. Bewaar de uitvoer buiten de server.
set -eu
cd "$(dirname "$0")/.."
BAO="docker compose -f vps3-diensten.yml exec -T sleutelbeheer bao"

if $BAO status -format=json 2>/dev/null | grep -q '"initialized": true'; then
  echo "OpenBao is al geïnitialiseerd. Ontzegelen: $BAO operator unseal <sleutel>"
  exit 1
fi

# De JSON komt over meerdere regels; eerst op één regel zetten.
UIT=$($BAO operator init -key-shares=1 -key-threshold=1 -format=json | tr -d '\n')
ONTZEGEL=$(echo "$UIT" | sed -n 's/.*"unseal_keys_b64": *\[ *"\([^"]*\)".*/\1/p' | head -1)
ROOT=$(echo "$UIT" | sed -n 's/.*"root_token": *"\([^"]*\)".*/\1/p' | head -1)
[ -n "$ONTZEGEL" ] && [ -n "$ROOT" ] || { echo "Initialiseren mislukt:"; echo "$UIT"; exit 1; }

$BAO operator unseal "$ONTZEGEL" >/dev/null
export BAO_TOKEN="$ROOT"
BAOT="docker compose -f vps3-diensten.yml exec -T -e BAO_TOKEN=$ROOT sleutelbeheer bao"
$BAOT secrets enable transit >/dev/null
docker compose -f vps3-diensten.yml exec -T -e BAO_TOKEN=$ROOT sleutelbeheer bao policy write oa-platform - < openbao/beleid-oa-platform.hcl >/dev/null
PLATFORM=$($BAOT token create -policy=oa-platform -period=768h -orphan -display-name=oa-platform -format=json \
  | tr -d '\n' | sed -n 's/.*"client_token": *"\([^"]*\)".*/\1/p' | head -1)

[ -n "$PLATFORM" ] || { echo "Token voor het platform maken mislukt."; exit 1; }

# OA_ROOT_INTREKKEN=1 (zo roept server/installeer.sh dit aan): het root-token
# meteen intrekken. Met de ontzegelsleutel kun je later een nieuw maken
# (bao operator generate-root).
if [ "${OA_ROOT_INTREKKEN:-0}" = 1 ]; then
  $BAOT token revoke -self >/dev/null
  ROOT="(ingetrokken)"
fi

cat <<UIT
OpenBao is ingericht.

  Ontzegelsleutel: $ONTZEGEL
  Root-token:      $ROOT
  Token platform:  $PLATFORM

Bewaar de ontzegelsleutel veilig, buiten deze server. Trek een root-token in
zodra het niet meer nodig is: bao token revoke <root-token>.
Zet op VPS 2 in .env:  SLEUTELBEHEER=openbao  OPENBAO_TOKEN=$PLATFORM
UIT
