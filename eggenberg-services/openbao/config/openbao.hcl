ui = true

storage "file" {
  path = "/openbao/data"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

# ponytail: TLS terminated by the reverse proxy / tailscale in front of this.
# api_addr on 127.0.0.1 is fine for a single non-HA node.
api_addr = "http://127.0.0.1:8200"
