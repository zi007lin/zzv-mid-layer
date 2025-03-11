verify_kubernetes_simple() {
  log_info "Verifying K3s installation..."
  
  # Check if K3s service is running
  if ! systemctl is-active --quiet k3s; then
    log_error "❌ K3s service is not running"
    return 1
  fi
  
  # Check if kubectl works
  if ! kubectl version --short; then
    log_error "❌ kubectl is not functioning properly"
    return 1
  fi
  
  # Check if at least one node is available
  if [ "$(kubectl get nodes --no-headers 2>/dev/null | wc -l)" -lt 1 ]; then
    log_error "❌ No nodes found in the cluster"
    return 1
  fi
  
  log_info "✅ K3s installation verified successfully!"
  return 0
}