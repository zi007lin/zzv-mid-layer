#!/usr/bin/env bash

# Modern Service Setup Script
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "${SCRIPT_DIR}/scripts/utils.sh"

log_info "🚀 Starting modern service deployment..."

# Runner helper
run_script() {
    local script=$1
    local description=$2
    log_info "$description"
    if [ -f "scripts/$script" ]; then
        bash "scripts/$script" || {
            log_error "❌ Failed to execute $script"
            exit 1
        }
    else
        log_error "⚠️ Script not found: scripts/$script"
        exit 1
    fi
}

# Ensure K8s is ready
log_info "🔍 Verifying Kubernetes readiness..."
if ! kubectl get nodes &>/dev/null; then
    log_error "❌ Kubernetes not ready. Please run run_infra_setup.sh first."
    exit 1
fi

# Core Services
run_script "deploy_kafka.sh" "🟡 Deploying Kafka..."
run_script "deploy_elixir_phoenix.sh" "🟣 Deploying Elixir Phoenix..."

# Observability Stack
run_script "deploy_otel_collector.sh" "📡 Deploying OpenTelemetry Collector..."
run_script "deploy_tempo.sh" "⏱️ Deploying Tempo (tracing backend)..."
run_script "install_prometheus.sh" "📊 Installing Prometheus..."
run_script "install_grafana.sh" "📈 Installing Grafana dashboards..."

# Final Testing
log_info "✅ Validating observability pipeline readiness..."

# Check Prometheus
if curl -s http://localhost:9090/api/v1/status/runtimeinfo | grep -q "status"; then
    log_info "🟢 Prometheus is up."
else
    log_error "🔴 Prometheus not responding on :9090"
    exit 1
fi

# Check Grafana
if curl -s http://localhost:3000/login | grep -q "Grafana"; then
    log_info "🟢 Grafana is up."
else
    log_error "🔴 Grafana not responding on :3000"
    exit 1
fi

# Check OTEL Collector /metrics
if curl -s http://localhost:8888/metrics | grep -q "otelcol_receiver_"; then
    log_info "🟢 OpenTelemetry Collector is exposing metrics."
else
    log_error "🔴 OpenTelemetry Collector not exposing metrics on :8888"
    exit 1
fi

# Check Tempo
if curl -s http://localhost:3200/metrics | grep -q "tempo_ingester"; then
    log_info "🟢 Tempo trace backend is reachable."
else
    log_error "🔴 Tempo not responding on :3200"
    exit 1
fi


log_info "🎉 Services setup completed successfully!"
exit 0
