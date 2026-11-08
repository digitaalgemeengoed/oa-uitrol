#!/usr/bin/env bash
# Keycloak voorbereiden voor het beheerportaal. Op VPS 3 (diensten), na
# installeer.sh. Zie INRICHTING.md stap 9. Mag vaker worden gestart; wat er al
# is, blijft staan.
#
#   sudo /opt/oa-uitrol/server/keycloak-beheer.sh
#
# Doet in de realm 'gemeenten':
#   - een vertrouwelijke client 'oa-beheer' (alleen authorization code + PKCE),
#   - de AMR-mapper, zodat het id_token meldt dat er een tweede factor was,
#   - op de OTP-stap van de inlogflow de referentiewaarde 'otp',
#   - brute-force-detectie aan,
#   - op verzoek een Keycloak-gebruiker voor jezelf (e-mail geverifieerd,
#     bij de eerste inlog een eigen wachtwoord en een authenticator-app).
# En toont het client-geheim voor beheer.sh keycloak op VPS 1.

HIER="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$HIER/lib.sh"
moet_root
[ "$(rol)" = diensten ] || stop "Keycloak draait op VPS 3 (diensten). Dit is $(vps_naam "$(rol)")."
cd "$OA_UITROL" || exit 1
[ -s .env ] || stop "Nog niet geïnstalleerd. Gebruik eerst installeer.sh."
command -v jq >/dev/null || apt-get install -y -qq jq >/dev/null
dc() { docker compose -f vps3-diensten.yml --env-file .env "$@"; }
waarde() { sed -n "s/^$1=//p" .env | tail -1; }
DOMEIN="$(waarde DOMEIN)"
PORTAAL="https://oa-admin.$DOMEIN"
R=gemeenten

kc() { dc exec -T keycloak /opt/keycloak/bin/kcadm.sh "$@" --config /tmp/oa-kcadm.config; }

meld "Keycloak voor het beheerportaal ($PORTAAL)"
kc config credentials --server http://localhost:8080 --realm master \
  --user "$(waarde KC_BEHEERDER)" --password "$(waarde KC_BEHEERDER_WACHTWOORD)" >/dev/null 2>&1 \
  || stop "Inloggen op Keycloak lukte niet. Draait Keycloak? (sudo docker compose -f vps3-diensten.yml ps)"
ok "Ingelogd op Keycloak"

# --- Client --------------------------------------------------------------------
ID="$(kc get clients -r $R -q clientId=oa-beheer --fields id 2>/dev/null | jq -r '.[0].id // empty')"
if [ -z "$ID" ]; then
  kc create clients -r $R \
    -s clientId=oa-beheer -s name="Beheerportaal Office Assistent" -s enabled=true \
    -s protocol=openid-connect -s publicClient=false -s clientAuthenticatorType=client-secret \
    -s secret="$(geheim 32)" \
    -s standardFlowEnabled=true -s implicitFlowEnabled=false \
    -s directAccessGrantsEnabled=false -s serviceAccountsEnabled=false \
    -s "redirectUris=[\"$PORTAAL/api/auth/terug\"]" -s "webOrigins=[\"$PORTAAL\"]" -s "rootUrl=$PORTAAL" \
    -s "attributes.\"post.logout.redirect.uris\"=$PORTAAL/" \
    -s 'attributes."pkce.code.challenge.method"=S256' >/dev/null
  ID="$(kc get clients -r $R -q clientId=oa-beheer --fields id | jq -r '.[0].id')"
  ok "Client oa-beheer aangemaakt"
else
  ok "Client oa-beheer bestaat al"
fi

# --- AMR-mapper ------------------------------------------------------------------
if kc get "clients/$ID/protocol-mappers/models" -r $R | jq -e '.[] | select(.protocolMapper == "oidc-amr-mapper")' >/dev/null; then
  ok "AMR-mapper staat er al"
else
  kc create "clients/$ID/protocol-mappers/models" -r $R \
    -s name=amr -s protocol=openid-connect -s protocolMapper=oidc-amr-mapper \
    -s 'config."id.token.claim"=true' -s 'config."access.token.claim"=true' \
    -s 'config."introspection.token.claim"=true' >/dev/null
  ok "AMR-mapper toegevoegd"
fi

# --- Referentiewaarde op de OTP-stap -----------------------------------------------
FLOW="$(kc get "realms/$R" --fields browserFlow | jq -r '.browserFlow // "browser"')"
EXEC="$(kc get "authentication/flows/$(jq -rn --arg f "$FLOW" '$f|@uri')/executions" -r $R | jq -c '[.[] | select(.providerId == "auth-otp-form")][0] // empty')"
if [ -z "$EXEC" ]; then
  waarschuw "De inlogflow '$FLOW' heeft geen OTP-stap. Zonder tweede factor laat het portaal niemand binnen zolang 'mfa.vereist' aan staat."
elif [ "$(echo "$EXEC" | jq -r '.authenticationConfig // empty')" ]; then
  ok "De OTP-stap heeft al een configuratie (referentie: zelf nakijken als inloggen mislukt)"
else
  EID="$(echo "$EXEC" | jq -r .id)"
  if kc create "authentication/executions/$EID/config" -r $R \
       -s alias=oa-otp-referentie -s 'config."default.reference.value"=otp' >/dev/null 2>&1; then
    ok "OTP-stap meldt nu 'otp' in amr"
  else
    waarschuw "De referentiewaarde op de OTP-stap zetten lukte niet. Zet in het Keycloak-beheer bij Authentication → $FLOW → OTP Form → instellingen 'Authentication Reference' op otp."
  fi
fi

# --- Brute-force-detectie ------------------------------------------------------------
if [ "$(kc get "realms/$R" --fields bruteForceProtected | jq -r .bruteForceProtected)" = true ]; then
  ok "Brute-force-detectie staat al aan"
else
  kc update "realms/$R" -s bruteForceProtected=true -s failureFactor=10 >/dev/null
  ok "Brute-force-detectie aan (na 10 mislukte pogingen tijdelijk geblokkeerd)"
fi

# --- Een gebruiker voor jezelf ---------------------------------------------------------
echo
echo "  Je logt straks op het portaal in met een Keycloak-gebruiker met een"
echo "  geverifieerd e-mailadres. Zal ik er een voor je maken?"
read -r -p "  Jouw e-mailadres (leeg = overslaan): " EMAIL
EMAIL="${EMAIL,,}"
if [ -n "$EMAIL" ]; then
  [[ "$EMAIL" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[a-z]{2,}$ ]] || stop "Dat is geen e-mailadres."
  UID_="$(kc get users -r $R -q email="$EMAIL" -q exact=true --fields id | jq -r '.[0].id // empty')"
  if [ -n "$UID_" ]; then
    kc update "users/$UID_" -r $R -s emailVerified=true >/dev/null
    ok "$EMAIL bestaat al in Keycloak; e-mail als geverifieerd gemarkeerd"
  else
    read -r -p "  Voornaam: " VOOR
    read -r -p "  Achternaam: " ACHTER
    TIJDELIJK="Tijdelijk-$(geheim 6)"
    kc create users -r $R -s username="$EMAIL" -s email="$EMAIL" -s emailVerified=true -s enabled=true \
      -s firstName="$VOOR" -s lastName="$ACHTER" \
      -s 'requiredActions=["UPDATE_PASSWORD","CONFIGURE_TOTP"]' >/dev/null
    kc set-password -r $R --username "$EMAIL" --new-password "$TIJDELIJK" --temporary >/dev/null
    ok "Gebruiker $EMAIL aangemaakt"
    echo "      Tijdelijk wachtwoord: $TIJDELIJK"
    echo "      Bij de eerste inlog kies je een eigen wachtwoord en koppel je een authenticator-app."
  fi
  echo "      Maak in het portaal (via /emergency) een account met precies dit e-mailadres."
fi

SECRET="$(kc get "clients/$ID/client-secret" -r $R | jq -r .value)"
dc exec -T keycloak rm -f /tmp/oa-kcadm.config
cat <<UIT

  Client-geheim voor het beheerportaal:

      $SECRET

  Plak dit op VPS 1 in:  sudo $OA_UITROL/server/beheer.sh keycloak
  Daarna niet meer nodig; je kunt het hier altijd opnieuw laten zien.

UIT
