# OpenBao voor het prototype van de Office Assistent (OA-ADR-008).
#
# Luistert zonder TLS, alleen op het private netwerk tussen de VPS'en.
# Voor productie: TLS (of mTLS) aanzetten en auto-unseal met een HSM of KMS.

ui = false
# Bij raft-opslag aanbevolen: mlock uit (raft gebruikt mmap).
disable_mlock = true

storage "raft" {
  path    = "/openbao/file"
  node_id = "oa-sleutelbeheer-1"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = true
}

api_addr     = "http://127.0.0.1:8200"
cluster_addr = "http://127.0.0.1:8201"
