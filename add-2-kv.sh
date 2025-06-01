#!/bin/bash

# ----------------------------
# Store SFTP config in Azure Key Vault with validation and masked output
# ----------------------------

set -e

KEYVAULT_NAME="gmg-kv"

# Function to prompt until input is not empty
prompt_non_empty() {
  local var_name="$1"
  local prompt_msg="$2"
  while true; do
    read -rp "$prompt_msg: " value
    if [[ -n "$value" ]]; then
      eval "$var_name='$value'"
      break
    else
      echo "❌ $prompt_msg cannot be empty. Please try again."
    fi
  done
}

# Function to validate and prompt for port
prompt_valid_port() {
  while true; do
    read -rp "Enter SFTP Port [default 22]: " PORT
    PORT=${PORT:-22}
    if [[ "$PORT" =~ ^[0-9]+$ ]] && ((PORT >= 1 && PORT <= 65535)); then
      break
    else
      echo "❌ Port must be a number between 1 and 65535."
    fi
  done
}

# Function to securely prompt for password with confirmation
prompt_password() {
  while true; do
    read -rsp "Enter SFTP Password: " PASSWORD
    echo
    read -rsp "Confirm SFTP Password: " PASSWORD_CONFIRM
    echo
    if [[ -z "$PASSWORD" ]]; then
      echo "❌ Password cannot be empty."
    elif [[ "$PASSWORD" != "$PASSWORD_CONFIRM" ]]; then
      echo "❌ Passwords do not match. Try again."
    else
      break
    fi
  done
}

# ------- Prompt for all inputs with validation -------

prompt_non_empty CLIENT_ID "Enter Client ID (e.g., client1)"
prompt_non_empty PROFILE "Enter Profile Name (e.g., user2)"
prompt_non_empty HOSTNAME "Enter SFTP Hostname"
prompt_valid_port
prompt_non_empty USERNAME "Enter SFTP Username"
prompt_password

# Compose secret name
SECRET_NAME="${CLIENT_ID}-${PROFILE}-sftp-config"

# Create JSON payload
SFTP_JSON=$(jq -n \
  --arg hostname "$HOSTNAME" \
  --arg port "$PORT" \
  --arg username "$USERNAME" \
  --arg password "$PASSWORD" \
  '{hostname: $hostname, port: $port, username: $username, password: $password}'
)

# Store secret
echo "🔐 Storing secret [$SECRET_NAME] in Key Vault [$KEYVAULT_NAME]..."
az keyvault secret set \
  --vault-name "$KEYVAULT_NAME" \
  --name "$SECRET_NAME" \
  --value "$SFTP_JSON" \
  --output none

# Display masked result
echo "✅ Secret stored. Showing stored values with password masked:"
STORED_SECRET=$(az keyvault secret show --vault-name "$KEYVAULT_NAME" --name "$SECRET_NAME" --query value -o tsv)
echo "$STORED_SECRET" | jq '.password = "********"'

