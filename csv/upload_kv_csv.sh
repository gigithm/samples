#!/bin/bash

# Upload SFTP secrets to Azure Key Vault from CSV
KEYVAULT_NAME="gmg-kv"
CSV_FILE="sftp_creds.csv"

if [[ ! -f "$CSV_FILE" ]]; then
  echo "❌ CSV file not found: $CSV_FILE"
  exit 1
fi

echo "📤 Uploading secrets to Key Vault [$KEYVAULT_NAME]..."

# Skip header and read lines
tail -n +2 "$CSV_FILE" | while IFS=',' read -r client_id profile hostname port username password; do
  secret_name="${client_id}-${profile}-sftp-config"

  if [[ -z "$client_id" || -z "$profile" || -z "$hostname" || -z "$port" || -z "$username" || -z "$password" ]]; then
    echo "⚠️ Skipping incomplete row: $client_id,$profile,..."
    continue
  fi

  sftp_json=$(jq -n \
    --arg hostname "$hostname" \
    --arg port "$port" \
    --arg username "$username" \
    --arg password "$password" \
    '{hostname: $hostname, port: $port, username: $username, password: $password}')

  az keyvault secret set \
    --vault-name "$KEYVAULT_NAME" \
    --name "$secret_name" \
    --value "$sftp_json" \
    --output none

  echo "✅ Stored $secret_name"
done

