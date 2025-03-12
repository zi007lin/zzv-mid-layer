#!/usr/bin/env bash

. "$(dirname "$0")/utils.sh"

# Configuration options with defaults
SKIP_TEST_POD=${SKIP_TEST_POD:-false}
TEST_IMAGE=${TEST_IMAGE:-"alpine:3.15"}
CHECK_STORAGE=${CHECK_STORAGE:-true}
CHECK_NETWORKING=${CHECK_NETWORKING:-true}
CHECK_DNS=${CHECK_DNS:-true}
CHECK_METRICS=${CHECK_METRICS:-true}

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
  TIMEOUT=180  # 3 minutes timeout
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
  
  # Check node resource utilization
  log_info "Checking node resource utilization..."
  kubectl describe nodes | grep -A 5 "Allocated resources" || log_warning "⚠️ Could not retrieve resource allocation info"
  
  # Verify kubectl can access the cluster with better error handling
  if kubectl get namespaces &>/dev/null; then
    log_info "✅ kubectl can access the cluster"
  else
    log_error "❌ kubectl cannot access the cluster"
    log_error "Checking kubectl configuration:"
    kubectl config view
    return 1
  fi
  
  # Check core Kubernetes components
  log_info "Checking core Kubernetes components..."
  
  # Check CoreDNS
  if kubectl get pods -n kube-system -l k8s-app=kube-dns -o name | grep -q "pod/"; then
    log_info "✅ CoreDNS is running"
  else
    log_warning "⚠️ CoreDNS pods not found. This may be normal if using a different DNS provider."
  fi
  
  # Check kube-proxy
  if kubectl get pods -n kube-system -l k8s-app=kube-proxy -o name | grep -q "pod/"; then
    log_info "✅ kube-proxy is running"
  else
    log_warning "⚠️ kube-proxy pods not found. This may be expected in some K3s configurations."
  fi
  
  # Check metrics-server if requested
  if [ "$CHECK_METRICS" = true ]; then
    if kubectl get pods -n kube-system -l k8s-app=metrics-server -o name 2>/dev/null | grep -q "pod/"; then
      log_info "✅ metrics-server is running"
      # Test if metrics API is working
      if kubectl top nodes &>/dev/null; then
        log_info "✅ metrics API is functional"
      else
        log_warning "⚠️ metrics-server is running but the API is not yet functional"
      fi
    else
      log_warning "⚠️ metrics-server not found. You may want to install it for monitoring."
    fi
  fi
  
  # Skip pod tests if requested
  if [ "$SKIP_TEST_POD" = true ]; then
    log_info "Skipping test pod deployment as requested"
    log_info "🎉 K3s basic verification completed successfully!"
    return 0
  fi
  
  # Create test namespace
  TEST_NAMESPACE="k3s-test-$(date +%s)"
  log_info "Creating test namespace $TEST_NAMESPACE..."
  kubectl create namespace $TEST_NAMESPACE || {
    log_error "Failed to create test namespace"
    return 1
  }
  
  # Deploy a test pod with better error handling
  log_info "Deploying a test pod..."
  TEST_POD_YAML=$(cat <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  namespace: $TEST_NAMESPACE
spec:
  containers:
  - name: test-container
    image: $TEST_IMAGE
    command: ["sh", "-c", "sleep 300"]
  terminationGracePeriodSeconds: 5
EOF
)

  echo "$TEST_POD_YAML" | kubectl apply -f - || {
    log_error "Failed to create test pod"
    kubectl delete namespace $TEST_NAMESPACE --wait=false
    return 1
  }
  
  # Wait for the pod to be running with better error handling
  log_info "Waiting for test pod to be ready..."
  TIMEOUT=120  # 2 minutes timeout
  START_TIME=$(date +%s)
  
  while true; do
    POD_STATUS=$(kubectl get pod test-pod -n $TEST_NAMESPACE -o jsonpath='{.status.phase}' 2>/dev/null)
    if [ "$POD_STATUS" = "Running" ]; then
      log_info "✅ Test pod is running"
      break
    fi
    
    CURRENT_TIME=$(date +%s)
    if [ $((CURRENT_TIME - START_TIME)) -gt $TIMEOUT ]; then
      log_error "❌ Timeout waiting for test pod to be running"
      log_error "Pod details:"
      kubectl describe pod test-pod -n $TEST_NAMESPACE
      kubectl get events --sort-by='.lastTimestamp' -n $TEST_NAMESPACE | grep test-pod
      kubectl delete namespace $TEST_NAMESPACE --wait=false
      return 1
    fi
    
    REMAINING_TIME=$((TIMEOUT - (CURRENT_TIME - START_TIME)))
    log_info "Waiting for test pod to be ready... (${REMAINING_TIME}s remaining)"
    sleep 5
  done
  
  # Check DNS resolution if requested
  if [ "$CHECK_DNS" = true ]; then
    log_info "Testing DNS resolution..."
    if kubectl exec test-pod -n $TEST_NAMESPACE -- nslookup kubernetes.default.svc.cluster.local; then
      log_info "✅ DNS resolution is working"
    else
      log_warning "⚠️ DNS resolution test failed"
    fi
  fi
  
  # Check network connectivity if requested
  if [ "$CHECK_NETWORKING" = true ]; then
    log_info "Testing network connectivity..."
    
    # Create a second pod for network testing
    log_info "Creating second test pod for network tests..."
    NETWORK_TEST_POD_YAML=$(cat <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-pod-2
  namespace: $TEST_NAMESPACE
spec:
  containers:
  - name: test-container
    image: $TEST_IMAGE
    command: ["sh", "-c", "sleep 300"]
  terminationGracePeriodSeconds: 5
EOF
)

    echo "$NETWORK_TEST_POD_YAML" | kubectl apply -f - || {
      log_warning "⚠️ Failed to create second test pod for network testing"
    }
    
    # Wait for the second pod to be running
    TIMEOUT=60
    START_TIME=$(date +%s)
    SECOND_POD_READY=false
    
    while true; do
      POD_STATUS=$(kubectl get pod test-pod-2 -n $TEST_NAMESPACE -o jsonpath='{.status.phase}' 2>/dev/null)
      if [ "$POD_STATUS" = "Running" ]; then
        log_info "✅ Second test pod is running"
        SECOND_POD_READY=true
        break
      fi
      
      CURRENT_TIME=$(date +%s)
      if [ $((CURRENT_TIME - START_TIME)) -gt $TIMEOUT ]; then
        log_warning "⚠️ Timeout waiting for second test pod"
        break
      fi
      
      sleep 5
    done
    
    if [ "$SECOND_POD_READY" = true ]; then
      # Get the IP of the second pod
      POD2_IP=$(kubectl get pod test-pod-2 -n $TEST_NAMESPACE -o jsonpath='{.status.podIP}')
      
      # Test connectivity from first pod to second pod
      if kubectl exec test-pod -n $TEST_NAMESPACE -- ping -c 3 $POD2_IP; then
        log_info "✅ Pod-to-pod network connectivity is working"
      else
        log_warning "⚠️ Pod-to-pod ping failed (may be disabled in your CNI)"
        # Try alternative connectivity test with wget if ping fails
        if kubectl exec test-pod -n $TEST_NAMESPACE -- wget -T 5 -q -O - http://$POD2_IP:80 2>/dev/null; then
          log_info "✅ Pod-to-pod HTTP connectivity is working"
        else
          log_warning "⚠️ Pod-to-pod network connectivity test inconclusive"
        fi
      fi
    fi
  fi
  
  # Check storage provisioning if requested
  if [ "$CHECK_STORAGE" = true ]; then
    log_info "Testing storage provisioning..."
    
    # Create a test PVC
    TEST_PVC_YAML=$(cat <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
  namespace: $TEST_NAMESPACE
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Mi
EOF
)

    echo "$TEST_PVC_YAML" | kubectl apply -f - || {
      log_warning "⚠️ Failed to create test PVC"
    }
    
    # Wait briefly for the PVC
    sleep 5
    
    # Check PVC status
    PVC_STATUS=$(kubectl get pvc test-pvc -n $TEST_NAMESPACE -o jsonpath='{.status.phase}' 2>/dev/null)
    if [ "$PVC_STATUS" = "Bound" ]; then
      log_info "✅ Storage provisioning is working"
    else
      log_warning "⚠️ PVC not bound. Storage provisioning may need configuration."
    fi
  fi
  
  # Cleanup test resources with better error handling
  log_info "Cleaning up test resources..."
  log_info "Deleting namespace $TEST_NAMESPACE and all contained resources..."
  if ! kubectl delete namespace $TEST_NAMESPACE --wait=true --timeout=60s; then
    log_warning "Graceful namespace deletion failed, forcing removal..."
    kubectl delete namespace $TEST_NAMESPACE --wait=false
  fi

  log_info "🎉 K3s installation verified successfully!"
  return 0
}

# Main execution
main() {
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --skip-test-pod)
        SKIP_TEST_POD=true
        shift
        ;;
      --test-image=*)
        TEST_IMAGE="${1#*=}"
        shift
        ;;
      --no-storage-check)
        CHECK_STORAGE=false
        shift
        ;;
      --no-network-check)
        CHECK_NETWORKING=false
        shift
        ;;
      --no-dns-check)
        CHECK_DNS=false
        shift
        ;;
      --no-metrics-check)
        CHECK_METRICS=false
        shift
        ;;
      *)
        log_warning "Unknown option: $1"
        shift
        ;;
    esac
  done
  
  # Run verification
  verify_kubernetes
  RESULT=$?

  if [ $RESULT -eq 0 ]; then
    log_info "📦 K3s is now ready to use!"
    kubectl get nodes
    log_info "✨ Cluster info:"
    kubectl cluster-info
  else
    log_error "❌ K3s installation verification failed"
    exit 1
  fi
}

main "$@"