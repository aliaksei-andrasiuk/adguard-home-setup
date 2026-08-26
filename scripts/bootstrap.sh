#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
ENC_FILE="$ROOT_DIR/.env.age"
SETUP_PORT=3000

log() { printf '\n==> %s\n' "$*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

install_age() {
  if command -v age >/dev/null 2>&1; then
    return
  fi
  log "Installing age"
  sudo apt-get update
  sudo apt-get install -y age
}

if [[ ! -f "$ENV_FILE" ]]; then
  [[ -f "$ENC_FILE" ]] || die "Neither .env nor .env.age exists. Run: cp .env.example .env"
  install_age
  log "Decrypting .env.age"
  umask 077
  age -d -o "$ENV_FILE" "$ENC_FILE"
  chmod 600 "$ENV_FILE"
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

required=(SERVER_IP SERVER_INTERFACE ROUTER_IP ADGUARD_WEB_PORT ADGUARD_DNS_PORT)
for name in "${required[@]}"; do
  [[ -n "${!name:-}" ]] || die "$name is not set in .env"
done

[[ "$ADGUARD_WEB_PORT" != "$SETUP_PORT" ]] || die "ADGUARD_WEB_PORT cannot be 3000; AdGuard Home uses port 3000 for first-run setup."

if ! ip link show dev "$SERVER_INTERFACE" >/dev/null 2>&1; then
  die "Network interface '$SERVER_INTERFACE' does not exist."
fi

if ! ip -4 -o addr show dev "$SERVER_INTERFACE" scope global | awk '{print $4}' | cut -d/ -f1 | grep -Fxq "$SERVER_IP"; then
  echo "Expected server IP $SERVER_IP is not currently assigned to $SERVER_INTERFACE." >&2
  echo "Current addresses:" >&2
  ip -br addr show dev "$SERVER_INTERFACE" >&2 || true
  echo >&2
  echo "Fix the router reservation / host network configuration first, then rerun this script." >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1 || ! command -v python3 >/dev/null 2>&1; then
  log "Installing bootstrap dependencies"
  sudo apt-get update
  sudo apt-get install -y curl python3
fi

if ! command -v docker >/dev/null 2>&1; then
  log "Installing Docker"
  sudo apt-get update
  sudo apt-get install -y docker.io
fi

if ! sudo docker compose version >/dev/null 2>&1; then
  log "Installing Docker Compose"
  sudo apt-get update
  if apt-cache show docker-compose-v2 >/dev/null 2>&1; then
    sudo apt-get install -y docker-compose-v2
  elif apt-cache show docker-compose-plugin >/dev/null 2>&1; then
    sudo apt-get install -y docker-compose-plugin
  else
    die "Could not find a Docker Compose v2 package. Install Docker Compose v2 and rerun."
  fi
fi

DATA_DIR="${ADGUARD_DATA_DIR:-/opt/adguardhome}"
log "Preparing persistent directories at $DATA_DIR"
sudo mkdir -p "$DATA_DIR/work" "$DATA_DIR/conf"

log "Pulling and starting AdGuard Home"
sudo docker compose --env-file "$ENV_FILE" -f "$ROOT_DIR/compose.yaml" pull
sudo docker compose --env-file "$ENV_FILE" -f "$ROOT_DIR/compose.yaml" up -d

configured=false
if [[ -s "$DATA_DIR/conf/AdGuardHome.yaml" ]] && curl -fsS --max-time 2 "http://${SERVER_IP}:${ADGUARD_WEB_PORT}/" >/dev/null 2>&1; then
  configured=true
fi

if [[ "$configured" != true ]]; then
  log "Waiting for AdGuard Home first-run API"
  ready=false
  for _ in {1..30}; do
    if curl -fsS --max-time 2 "http://${SERVER_IP}:${SETUP_PORT}/control/install/get_addresses" >/dev/null 2>&1; then
      ready=true
      break
    fi
    sleep 1
  done
  [[ "$ready" == true ]] || die "AdGuard first-run API did not become available on ${SERVER_IP}:${SETUP_PORT}. Check: sudo docker logs adguardhome"

  echo
  echo "Fresh AdGuard Home installation detected."
  echo "Create a new LOCAL admin account. These credentials are not saved in .env or Git."
  read -r -p "Admin username: " ADMIN_USERNAME
  [[ -n "$ADMIN_USERNAME" ]] || die "Admin username cannot be empty."

  while true; do
    read -r -s -p "Admin password (minimum 8 characters): " ADMIN_PASSWORD
    echo
    read -r -s -p "Confirm password: " ADMIN_PASSWORD_2
    echo
    [[ "$ADMIN_PASSWORD" == "$ADMIN_PASSWORD_2" ]] || { echo "Passwords do not match."; continue; }
    (( ${#ADMIN_PASSWORD} >= 8 )) || { echo "Password must be at least 8 characters."; continue; }
    break
  done

  PAYLOAD="$({ ADMIN_USERNAME="$ADMIN_USERNAME" ADMIN_PASSWORD="$ADMIN_PASSWORD" python3 - <<'PY'
import json, os
print(json.dumps({
    "web": {"ip": os.environ["SERVER_IP"], "port": int(os.environ["ADGUARD_WEB_PORT"])},
    "dns": {"ip": os.environ["SERVER_IP"], "port": int(os.environ["ADGUARD_DNS_PORT"])},
    "username": os.environ["ADMIN_USERNAME"],
    "password": os.environ["ADMIN_PASSWORD"],
    "language": os.environ.get("ADGUARD_LANGUAGE", "en"),
}))
PY
  })"

  log "Applying initial AdGuard Home configuration"
  HTTP_CODE="$(printf '%s' "$PAYLOAD" | curl -sS -o /tmp/adguard-install-response.$$ -w '%{http_code}' \
    -H 'Content-Type: application/json' \
    --data-binary @- \
    "http://${SERVER_IP}:${SETUP_PORT}/control/install/configure" || true)"
  unset PAYLOAD ADMIN_PASSWORD ADMIN_PASSWORD_2

  if [[ "$HTTP_CODE" != "200" ]]; then
    echo "AdGuard install API returned HTTP $HTTP_CODE:" >&2
    cat /tmp/adguard-install-response.$$ >&2 || true
    rm -f /tmp/adguard-install-response.$$
    exit 1
  fi
  rm -f /tmp/adguard-install-response.$$

  log "Waiting for final web UI"
  ready=false
  for _ in {1..30}; do
    if curl -fsS --max-time 2 "http://${SERVER_IP}:${ADGUARD_WEB_PORT}/" >/dev/null 2>&1; then
      ready=true
      break
    fi
    sleep 1
  done
  [[ "$ready" == true ]] || die "AdGuard was configured but the final web UI did not become available. Check container logs."
else
  log "Existing AdGuard Home configuration detected; leaving it unchanged"
fi

log "Verification"
bash "$ROOT_DIR/scripts/verify.sh"

log "Remaining manual network settings"
bash "$ROOT_DIR/scripts/print-network-steps.sh"

echo
echo "Bootstrap complete."
