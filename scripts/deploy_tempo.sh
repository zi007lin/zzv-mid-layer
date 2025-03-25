#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "⏱️ Deploying Grafana Tempo (trace backend)..."

kubectl apply -f "${SCRIPT_DIR}/../kubernetes/tempo.yaml" && \
echo "✅ Tempo deployed successfully." || {
    echo "❌ Failed to deploy Tempo."
    exit 1
}
