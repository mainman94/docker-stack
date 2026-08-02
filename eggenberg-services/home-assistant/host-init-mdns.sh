#!/usr/bin/env bash
# TrueNAS Pre-Init script: let avahi + CHIP (matter-server) share UDP 5353.
# Register: System Settings > Advanced > Init/Shutdown Scripts > Add
#   Type: Script | When: Pre Init | Script: <path to this file on a dataset>
# Idempotent — safe to run repeatedly.
set -euo pipefail

AVAHI_CONF=/etc/avahi/avahi-daemon.conf

# 1. avahi: allow other stacks to bind 5353 (enables SO_REUSEPORT sharing)
if [ -f "$AVAHI_CONF" ]; then
  if grep -qE '^\s*#*\s*disallow-other-stacks=' "$AVAHI_CONF"; then
    sed -i 's/^\s*#*\s*disallow-other-stacks=.*/disallow-other-stacks=no/' "$AVAHI_CONF"
  else
    sed -i '/^\[server\]/a disallow-other-stacks=no' "$AVAHI_CONF"
  fi
  systemctl restart avahi-daemon || service avahi-daemon restart || true
fi

# 2. kernel: raise multicast group limit (default 20; CHIP joins many groups)
sysctl -w net.ipv4.igmp_max_memberships=1024
