#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
NAMESPACE="observability"
kubectl get ns "$NAMESPACE" &>/dev/null || kubectl create namespace "$NAMESPACE"

echo "📈 Installing Grafana into namespace: $NAMESPACE..."

kubectl apply -f "${SCRIPT_DIR}/../kubernetes/grafana.yaml" -n "$NAMESPACE" && \
echo "✅ Grafana installed." || {
    echo "❌ Failed to install Grafana."
    exit 1
}
