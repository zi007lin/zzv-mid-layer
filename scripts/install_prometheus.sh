#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
NAMESPACE="observability"
kubectl get ns "$NAMESPACE" &>/dev/null || kubectl create namespace "$NAMESPACE"

echo "📊 Installing Prometheus into namespace: $NAMESPACE..."

kubectl apply -f "${SCRIPT_DIR}/../kubernetes/prometheus.yaml" -n "$NAMESPACE" && \
echo "✅ Prometheus installed." || {
    echo "❌ Failed to install Prometheus."
    exit 1
}
