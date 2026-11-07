#!/usr/bin/env bash
# OpenBao ontzegelen na een herstart van VPS 3. Zonder ontzegelen kan het
# platform geen documenten openen of opslaan.
#
#   sudo /opt/oa-uitrol/server/ontzegel.sh

HIER="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$HIER/lib.sh"
moet_root
[ "$(rol)" = diensten ] || stop "OpenBao draait op VPS 3 (diensten), niet hier."
cd "$OA_UITROL"
bao() { docker compose -f vps3-diensten.yml --env-file .env exec -T sleutelbeheer bao "$@"; }

if bao status 2>/dev/null | grep -q 'Sealed *false'; then ok "OpenBao is al ontzegeld"; exit 0; fi
read -r -s -p "Ontzegelsleutel (uit je wachtwoordmanager; je ziet niets terwijl je plakt): " SLEUTEL; echo
SLEUTEL="${SLEUTEL%$'\r'}"; SLEUTEL="${SLEUTEL// /}"
bao operator unseal "$SLEUTEL" >/dev/null 2>&1 || true
if bao status 2>/dev/null | grep -q 'Sealed *false'; then
  ok "OpenBao is ontzegeld; het platform kan weer bij de sleutels"
else
  stop "Ontzegelen mislukt. Klopt de sleutel? Draait OpenBao (sudo $OA_UITROL/server/controleer.sh)?"
fi
