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

echo "=== Docker ==="
sudo docker compose -f "$ROOT_DIR/compose.yaml" ps

echo
echo "=== Listeners ==="
sudo ss -lntup | grep -E "(${SERVER_IP//./\\.}:(${ADGUARD_DNS_PORT}|${ADGUARD_WEB_PORT})\\b|127\\.0\\.0\\.(53|54):53\\b)" || true

echo
echo "=== DNS ==="
if command -v dig >/dev/null 2>&1; then
  dig +time=3 +tries=1 "@${SERVER_IP}" openai.com
else
  echo "dig is not installed; skipping DNS query test."
fi

echo
echo "=== Web UI ==="
if curl -fsS --max-time 5 "http://${SERVER_IP}:${ADGUARD_WEB_PORT}/" >/dev/null; then
  echo "OK: http://${SERVER_IP}:${ADGUARD_WEB_PORT}/"
else
  echo "WARNING: web UI did not answer at http://${SERVER_IP}:${ADGUARD_WEB_PORT}/"
fi
