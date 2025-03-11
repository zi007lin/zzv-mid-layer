verify_kubernetes() {
  log_info "Verifying K3s installation..."
  
  # Check if K3s service is running
  if systemctl is-active --quiet k3s; then
    log_info "✅ K3s service is running"
  else
    log_error "❌ K3s service is not running"
    return 1
  fi
  
  # Wait for node to become ready
  log_info "Waiting for node to be ready..."
  TIMEOUT=120  # 2 minutes timeout
  START_TIME=$(date +%s)
  
  while true; do
    NODE_STATUS=$(kubectl get nodes --no-headers 2>/dev/null | grep -v "NotReady" | wc -l)
    if [ "$NODE_STATUS" -ge 1 ]; then
      log_info "✅ Node is Ready"
      break
    fi
    
    CURRENT_TIME=$(date +%s)
    if [ $((CURRENT_TIME - START_TIME)) -gt $TIMEOUT ]; then
      log_error "❌ Timeout waiting for node to be ready"
      return 1
    fi
    
    log_info "Waiting for node to be ready... ($(($TIMEOUT - $CURRENT_TIME + $START_TIME))s remaining)"
    sleep 5
  done
  
  # Verify kubectl can access the cluster
  if kubectl get namespaces &>/dev/null; then
    log_info "✅ kubectl can access the cluster"
  else
    log_error "❌ kubectl cannot access the cluster"
    return 1
  fi
  
  # Deploy a test pod
  log_info "Deploying a test pod..."
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: default
spec:
  containers:
  - name: alpine
    image: alpine:3.15
    command: ["sleep", "300"]
EOF
  
  # Wait for the pod to be running
  log_info "Waiting for test pod to be ready..."
  TIMEOUT=60  # 1 minute timeout
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
      kubectl describe pod test-pod
      return 1
    fi
    
    log_info "Waiting for test pod to be ready... ($(($TIMEOUT - $CURRENT_TIME + $START_TIME))s remaining)"
    sleep 5
  done
  
  # Cleanup test pod
  kubectl delete pod test-pod
  
  log_info "🎉 K3s installation verified successfully!"
  return 0
}

# Run installation and verification
install_kubernetes && verify_kubernetes
RESULT=$?

if [ $RESULT -eq 0 ]; then
  log_info "📦 K3s is now ready to use!"
  kubectl get nodes
else
  log_error "❌ K3s installation verification failed"
  exit 1
fi