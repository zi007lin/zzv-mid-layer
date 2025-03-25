#!/usr/bin/env bash

source "$(dirname "$0")/require_env.sh"

set -euo pipefail


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
NAMESPACE="observability"
kubectl get ns "$NAMESPACE" &>/dev/null || kubectl create namespace "$NAMESPACE"

echo "📡 Deploying OpenTelemetry Collector into namespace: $NAMESPACE..."

kubectl apply -f "${SCRIPT_DIR}/../kubernetes/otel-collector.yaml" -n "$NAMESPACE" && \
echo "✅ OTEL Collector deployed." || {
    echo "❌ Failed to deploy OTEL Collector."
    exit 1
}
