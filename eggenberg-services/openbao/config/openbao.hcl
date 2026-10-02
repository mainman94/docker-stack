ui = true

# 2.7 dropped the file backend. Raft lives in a subdir of the old data dir
# so the file-backend data stays put as a rollback copy after migration.
storage "raft" {
  path    = "/openbao/data/raft"
  node_id = "openbao-1"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

# ponytail: TLS terminated by the reverse proxy / tailscale in front of this.
# api_addr on 127.0.0.1 is fine for a single non-HA node.
api_addr     = "http://127.0.0.1:8200"
cluster_addr = "http://127.0.0.1:8201"
