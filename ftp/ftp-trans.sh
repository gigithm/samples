#!/bin/bash
set -e

# Usage validation
if [ -z "$1" ]; then
  echo "Usage: $0 <automation-details>.conf"
  exit 1
fi

CONFIG_FILE="$1"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ Config file '$CONFIG_FILE' not found"
  exit 1
fi

# Source variables from config
source "$CONFIG_FILE"

# Required vars check
if [ -z "$CLIENT_ID" ] || [ -z "$PROFILE" ]; then
  echo "❌ CLIENT_ID and PROFILE must be set in the config file"
  exit 1
fi

VAULT_NAME="gmg-kv"  # 🔁 Change this
SECRET_NAME="${CLIENT_ID}-${PROFILE}-sftp-config"

# Defaults
LOCAL_BASE_DIR="${LOCAL_BASE_DIR:-./downloads}"
REMOTE_SUBDIR="${REMOTE_SUBDIR:-}"
LOG_FILE="${LOG_FILE:-./sftp_download.log}"
LOCAL_DIR="${LOCAL_BASE_DIR}/${CLIENT_ID}/${PROFILE}"

# Dependencies check
for cmd in az jq lftp; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "❌ '$cmd' is required but not installed"
    exit 1
  fi
done

# Fetch secret from Azure Key Vault
echo "🔐 Fetching secret '$SECRET_NAME' from Vault '$VAULT_NAME'..." | tee -a "$LOG_FILE"
SFTP_JSON=$(az keyvault secret show --vault-name "$VAULT_NAME" --name "$SECRET_NAME" --query value -o tsv 2>/dev/null)

if [ -z "$SFTP_JSON" ]; then
  echo "❌ Secret '$SECRET_NAME' not found in Azure Key Vault" | tee -a "$LOG_FILE"
  exit 1
fi

# Parse JSON fields
HOST=$(echo "$SFTP_JSON" | jq -r '.host')
USER=$(echo "$SFTP_JSON" | jq -r '.username')
PASS=$(echo "$SFTP_JSON" | jq -r '.password')
PORT=$(echo "$SFTP_JSON" | jq -r '.port')
REMOTE_PATH=$(echo "$SFTP_JSON" | jq -r '.remote_path')
REMOTE_FULL_PATH="${REMOTE_PATH}/${REMOTE_SUBDIR}"

# Make local dir
mkdir -p "$LOCAL_DIR"

echo "📡 Connecting to $HOST:$PORT as $USER" | tee -a "$LOG_FILE"
echo "📁 Downloading from $REMOTE_FULL_PATH to $LOCAL_DIR" | tee -a "$LOG_FILE"

# Download files via lftp
lftp -u "$USER","$PASS" -p "$PORT" sftp://"$HOST" <<EOF
set ssl:verify-certificate no
cd $REMOTE_FULL_PATH
lcd $LOCAL_DIR
mirror --only-newer --verbose
bye
EOF

echo "✅ Download complete for $CLIENT_ID / $PROFILE" | tee -a "$LOG_FILE"

