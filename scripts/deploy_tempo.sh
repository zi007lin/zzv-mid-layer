#!/usr/bin/env bash
source "$(dirname "$0")/require_env.sh"

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
NAMESPACE="observability"
kubectl get ns "$NAMESPACE" &>/dev/null || kubectl create namespace "$NAMESPACE"

echo "⏱️ Deploying Tempo (tracing backend) into namespace: $NAMESPACE..."

kubectl apply -f "${SCRIPT_DIR}/../kubernetes/tempo.yaml" -n "$NAMESPACE" && \
echo "✅ Tempo deployed." || {
    echo "❌ Failed to deploy Tempo."
    exit 1
}
