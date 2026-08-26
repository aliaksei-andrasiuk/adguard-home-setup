#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE"
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

cat <<EOF
Manual network steps
====================

PlayBox / router
----------------
1. Reserve the server address:
   IP:  ${SERVER_IP}
   MAC: ${SERVER_MAC:-<server MAC>}

2. Reserve the Samsung TV address:
   IP:  ${TV_IP}
   MAC: ${TV_MAC:-<TV MAC>}

Samsung TV
----------
Set IP Settings -> Enter manually:
   IP address:   ${TV_IP}
   Subnet mask:  255.255.255.0
   Gateway:      ${ROUTER_IP}

Set DNS Setting -> Enter manually:
   DNS server:   ${SERVER_IP}

AdGuard Home UI
---------------
   http://${SERVER_IP}:${ADGUARD_WEB_PORT}
EOF
