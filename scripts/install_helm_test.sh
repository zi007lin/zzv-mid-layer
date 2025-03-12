#!/usr/bin/env bash

. "$(dirname "$0")/utils.sh"

log_info "Testing Helm installation..."

# Check if Helm is installed
if command -v helm &> /dev/null; then
    log_info "✅ Helm is installed."
    
    # Get and check Helm version
    HELM_VERSION=$(helm version --template="{{.Version}}" | cut -d "." -f1,2 | sed 's/^v//')
    log_info "Detected Helm version: $HELM_VERSION"
    
    # Check if version meets minimum requirement (adjustable)
    if (( $(echo "$HELM_VERSION >= 3.0" | bc -l) )); then
        log_info "✅ Helm version meets minimum requirement."
    else
        log_warning "⚠️ Helm version is below recommended version (3.0+)."
    fi
else
    log_error "❌ Helm is NOT installed."
    exit 1
fi

# Check if Helm repositories exist
log_info "Checking Helm repositories..."

REPOS_TO_CHECK=("bitnami" "stable" "jetstack")
MISSING_REPOS=0

for repo in "${REPOS_TO_CHECK[@]}"; do
    if helm repo list | grep -q "$repo"; then
        log_info "✅ Helm repository '$repo' is configured."
    else
        log_warning "⚠️ Helm repository '$repo' not found."
        MISSING_REPOS=$((MISSING_REPOS + 1))
    fi
done

if [ $MISSING_REPOS -gt 0 ]; then
    log_warning "⚠️ $MISSING_REPOS repositories are missing. Consider running install_helm.sh again."
else
    log_info "✅ All expected repositories are configured."
fi

# Test basic Helm functionality
log_info "Testing Helm functionality..."
TEST_OUTPUT=$(helm repo update 2>&1)
if [ $? -eq 0 ]; then
    log_info "✅ Helm repository update works correctly."
else
    log_error "❌ Helm repository update failed: $TEST_OUTPUT"
    exit 1
fi

# Check if helm has proper permissions
HELM_CONFIG_DIR="$HOME/.config/helm"
HELM_CACHE_DIR="$HOME/.cache/helm"

if [ -d "$HELM_CONFIG_DIR" ]; then
    if [ -w "$HELM_CONFIG_DIR" ]; then
        log_info "✅ Helm configuration directory has correct permissions."
    else
        log_warning "⚠️ Helm configuration directory permissions issue: not writable."
    fi
else
    log_warning "⚠️ Helm configuration directory does not exist."
fi

log_info "✅ Helm test completed successfully!"