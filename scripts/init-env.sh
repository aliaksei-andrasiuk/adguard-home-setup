#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="$ROOT_DIR/.env"
TEMPLATE="$ROOT_DIR/.env.example"

if [[ -e "$TARGET" ]]; then
  echo "$TARGET already exists; refusing to overwrite it."
  exit 1
fi

cp "$TEMPLATE" "$TARGET"
chmod 600 "$TARGET"

DEFAULT_IFACE="$(ip route show default 2>/dev/null | awk 'NR==1 {print $5}')"
DEFAULT_GW="$(ip route show default 2>/dev/null | awk 'NR==1 {print $3}')"
DEFAULT_IP=""
DEFAULT_MAC=""

if [[ -n "$DEFAULT_IFACE" ]]; then
  DEFAULT_IP="$(ip -4 -o addr show dev "$DEFAULT_IFACE" scope global 2>/dev/null | awk 'NR==1 {split($4,a,"/"); print a[1]}')"
  DEFAULT_MAC="$(cat "/sys/class/net/$DEFAULT_IFACE/address" 2>/dev/null || true)"
fi

python3 - "$TARGET" "$DEFAULT_IFACE" "$DEFAULT_IP" "$DEFAULT_GW" "$DEFAULT_MAC" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
iface, ip, gw, mac = sys.argv[2:]
text = p.read_text()
repls = {
    'SERVER_INTERFACE=enp3s0': f'SERVER_INTERFACE={iface or "enp3s0"}',
    'SERVER_IP=192.168.0.216': f'SERVER_IP={ip or "192.168.0.216"}',
    'ROUTER_IP=192.168.0.1': f'ROUTER_IP={gw or "192.168.0.1"}',
    'SERVER_MAC=': f'SERVER_MAC={mac}',
}
for old, new in repls.items():
    text = text.replace(old, new)
p.write_text(text)
PY

echo "Created $TARGET with detected server network values where possible."
echo "Review and edit it before installing:"
echo "  nano $TARGET"
