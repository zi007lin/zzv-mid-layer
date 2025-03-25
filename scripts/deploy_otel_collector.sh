#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "📡 Deploying OpenTelemetry Collector..."

kubectl apply -f "${SCRIPT_DIR}/../kubernetes/otel-collector.yaml" && \
echo "✅ OTEL Collector deployed successfully." || {
    echo "❌ Failed to deploy OTEL Collector."
    exit 1
}
