#!/bin/bash
source scripts/utils.sh

verify_kubernetes() {
  log_info "Verifying K3s installation..."
  
  # Ensure we're running as root or with sudo
  if [ "$EUID" -ne 0 ]; then 
    log_error "Please run with sudo"
    return 1
  fi
  
  # Check if K3s service is running
  if systemctl is-active --quiet k3s; then
    log_info "✅ K3s service is running"
  else
    log_error "❌ K3s service is not running"
    systemctl status k3s --no-pager
    return 1
  fi
  
  # Ensure KUBECONFIG is set correctly
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  
  # Wait for node to become ready with better error handling
  log_info "Waiting for node to be ready..."
  TIMEOUT=180  # 3 minutes timeout (increased from 2 minutes)
  START_TIME=$(date +%s)
  
  while true; do
    if ! kubectl get nodes &>/dev/null; then
      log_error "Failed to connect to the cluster. Checking kubectl configuration..."
      kubectl config view
      return 1
    fi
    
    NODE_STATUS=$(kubectl get nodes --no-headers 2>/dev/null | grep -v "NotReady" | wc -l)
    if [ "$NODE_STATUS" -ge 1 ]; then
      log_info "✅ Node is Ready"
      break
    fi
    
    CURRENT_TIME=$(date +%s)
    if [ $((CURRENT_TIME - START_TIME)) -gt $TIMEOUT ]; then
      log_error "❌ Timeout waiting for node to be ready"
      kubectl describe nodes
      return 1
    fi
    
    REMAINING_TIME=$((TIMEOUT - (CURRENT_TIME - START_TIME)))
    log_info "Waiting for node to be ready... (${REMAINING_TIME}s remaining)"
    sleep 5
  done
  
  # Verify kubectl can access the cluster with better error handling
  if kubectl get namespaces &>/dev/null; then
    log_info "✅ kubectl can access the cluster"
  else
    log_error "❌ kubectl cannot access the cluster"
    log_error "Checking kubectl configuration:"
    kubectl config view
    return 1
  fi
  
  # Deploy a test pod with better error handling
  log_info "Deploying a test pod..."
  TEST_POD_YAML=$(cat <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: default
spec:
  containers:
  - name: alpine
    image: alpine:3.15
    command: ["sh", "-c", "sleep 300"]
  terminationGracePeriodSeconds: 5
EOF
)

  echo "$TEST_POD_YAML" | kubectl apply -f - || {
    log_error "Failed to create test pod"
    return 1
  }
  
  # Wait for the pod to be running with better error handling
  log_info "Waiting for test pod to be ready..."
  TIMEOUT=120  # 2 minutes timeout (increased from 1 minute)
  START_TIME=$(date +%s)
  
  while true; do
    POD_STATUS=$(kubectl get pod test-pod -o jsonpath='{.status.phase}' 2>/dev/null)
    if [ "$POD_STATUS" = "Running" ]; then
      log_info "✅ Test pod is running"
      break
    fi
    
    CURRENT_TIME=$(date +%s)
    if [ $((CURRENT_TIME - START_TIME)) -gt $TIMEOUT ]; then
      log_error "❌ Timeout waiting for test pod to be running"
      log_error "Pod details:"
      kubectl describe pod test-pod
      kubectl get events --sort-by='.lastTimestamp' | grep test-pod
      return 1
    fi
    
    REMAINING_TIME=$((TIMEOUT - (CURRENT_TIME - START_TIME)))
    log_info "Waiting for test pod to be ready... (${REMAINING_TIME}s remaining)"
    sleep 5
  done
  
  # Cleanup test pod with better error handling
  log_info "Cleaning up test pod..."
  if kubectl get pod test-pod &>/dev/null; then
    log_info "Attempting graceful pod deletion..."
    if ! kubectl delete pod test-pod --wait=true --timeout=30s; then
      log_warning "Graceful deletion failed, forcing pod removal..."
      kubectl delete pod test-pod --force --grace-period=0
      # Wait briefly to ensure pod is removed
      sleep 5
    fi
  fi
  
  # Verify pod is gone
  if kubectl get pod test-pod &>/dev/null; then
    log_warning "Pod deletion may not be complete, but continuing..."
  else
    log_info "✅ Test pod cleaned up successfully"
  fi

  log_info "🎉 K3s installation verified successfully!"
  return 0
}

# Main execution
main() {
  # Ensure utils.sh is available
  if [ ! -f "scripts/utils.sh" ]; then
    echo "Error: utils.sh not found in scripts directory"
    exit 1
  fi    
  
  # Run verification
  verify_kubernetes
  RESULT=$?

  if [ $RESULT -eq 0 ]; then
    log_info "📦 K3s is now ready to use!"
    kubectl get nodes
  else
    log_error "❌ K3s installation verification failed"
    exit 1
  fi
}

main