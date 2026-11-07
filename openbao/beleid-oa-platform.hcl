# Wat het platform mag: per object een transit-sleutel aanmaken, een verpakte
# datasleutel opvragen, uitpakken en de sleutel vernietigen. Alleen sleutels
# met het voorvoegsel oa-. Geen export, geen backup, geen andere engines.

path "transit/keys/oa-*" {
  capabilities = ["create", "update", "delete"]
}
path "transit/keys/oa-*/config" {
  capabilities = ["update"]
}
path "transit/datakey/wrapped/oa-*" {
  capabilities = ["update"]
}
path "transit/decrypt/oa-*" {
  capabilities = ["update"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
