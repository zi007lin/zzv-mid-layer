#!/usr/bin/env bash
# ✅ Standard environment validator for ZZV scripts

ENV_FILE="$HOME/zzv.env"

# Load .env file
if [ -f "$ENV_FILE" ]; then
  source "$ENV_FILE"
else
  echo "❌ Environment file not found at $ENV_FILE"
  echo "   Please run setup_env.sh before executing this script."
  exit 1
fi

# Validate required vars
: "${DOMAIN_NAME:?❌ DOMAIN_NAME is not set.}"
: "${REGION:?❌ REGION is not set.}"
: "${VPS_NAME:?❌ VPS_NAME is not set.}"

echo "✅ Environment validated: $DOMAIN_NAME | $REGION | $VPS_NAME"
