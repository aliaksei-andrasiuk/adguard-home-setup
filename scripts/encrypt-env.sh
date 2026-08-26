#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
ENC_FILE="$ROOT_DIR/.env.age"
TMP_FILE="$ROOT_DIR/.env.age.tmp"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE"
  echo "Create it first: cp .env.example .env && edit .env"
  exit 1
fi

if ! command -v age >/dev/null 2>&1; then
  echo "Installing age..."
  sudo apt-get update
  sudo apt-get install -y age
fi

umask 077
rm -f "$TMP_FILE"

echo "Encrypting .env with an age passphrase."
echo "Use a strong passphrase and store it in your password manager."
age -p -o "$TMP_FILE" "$ENV_FILE"
mv "$TMP_FILE" "$ENC_FILE"

echo
echo "Created: $ENC_FILE"
echo "Plaintext remains local: $ENV_FILE"
echo "Safe next step: git add .env.age && git commit && git push"
