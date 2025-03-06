#!/bin/bash

# Exit on error
set -e

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Functions for formatted output
print_header() {
    echo -e "\n${YELLOW}=== $1 ===${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "  $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if a service is active
service_active() {
    systemctl is-active --quiet "$1"
}

# Create log file
LOG_FILE="setup_test_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

print_header "SYSTEM SETUP TEST SCRIPT"
echo "This script will test if your system is properly configured with SSH and HTTPS sharing port 443"
echo "Test results will be saved to $LOG_FILE"
echo "Started at: $(date)"

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Some tests require root privileges."
    echo "Re-running script with sudo..."
    sudo "$0"
    exit
fi

# Get domain name
if [ -f /etc/nginx/sites-available/default ]; then
    DOMAIN=$(grep -E "server_name" /etc/nginx/sites-available/default | head -1 | awk '{print $2}' | sed 's/;//')
else
    DOMAIN="localhost"
fi

print_header "1. CHECKING CORE SERVICES"

# Check SSLH
echo "Testing SSLH service..."
if service_active sslh; then
    print_success "SSLH service is running"

    # Check SSLH config
    if grep -q "DAEMON_OPTS=" /etc/default/sslh; then
        print_success "SSLH configuration found"
        SSLH_CONFIG=$(grep "DAEMON_OPTS=" /etc/default/sslh)
        print_info "Config: $SSLH_CONFIG"

        # Check if SSLH is configured for port 443
        if echo "$SSLH_CONFIG" | grep -q -- "--listen.*:443"; then
            print_success "SSLH is configured to listen on port 443"
        else
            print_error "SSLH is not configured to listen on port 443"
        fi

        # Check SSH and SSL forwarding
        if echo "$SSLH_CONFIG" | grep -q -- "--ssh"; then
            print_success "SSLH is configured to forward SSH traffic"
            SSH_TARGET=$(echo "$SSLH_CONFIG" | grep -o -- "--ssh [^ ]*" | cut -d' ' -f2)
            print_info "SSH traffic forwarded to: $SSH_TARGET"
        else
            print_error "SSLH is not configured to forward SSH traffic"
        fi

        if echo "$SSLH_CONFIG" | grep -q -- "--ssl"; then
            print_success "SSLH is configured to forward SSL traffic"
            SSL_TARGET=$(echo "$SSLH_CONFIG" | grep -o -- "--ssl [^ ]*" | cut -d' ' -f2)
            print_info "SSL traffic forwarded to: $SSL_TARGET"
        else
            print_error "SSLH is not configured to forward SSL traffic"
        fi
    else
        print_error "SSLH configuration not found or incomplete"
    fi
else
    print_error "SSLH service is not running"
    print_info "Check SSLH status with: systemctl status sslh"
fi

# Check NGINX
echo -e "\nTesting NGINX service..."
if service_active nginx; then
    print_success "NGINX service is running"

    # Check NGINX config
    if [ -f /etc/nginx/sites-available/default ]; then
        print_success "NGINX configuration found"

        # Check if NGINX is configured to listen on port 4443 (for SSLH)
        if grep -q "listen.*4443 ssl" /etc/nginx/sites-available/default; then
            print_success "NGINX is configured to listen on port 4443 for SSL"
        else
            print_error "NGINX is not configured to listen on port 4443 for SSL"
            print_info "Make sure NGINX is configured to receive SSLH-forwarded traffic"
        fi

        # Check SSL certificate configuration
        if grep -q "ssl_certificate" /etc/nginx/sites-available/default; then
            print_success "NGINX has SSL certificates configured"
            SSL_CERT=$(grep -E "ssl_certificate .*;" /etc/nginx/sites-available/default | head -1 | awk '{print $2}' | sed 's/;//')
            print_info "Certificate path: $SSL_CERT"

            if [ -f "$SSL_CERT" ]; then
                print_success "SSL certificate file exists"
                # Check certificate expiration
                if command_exists openssl; then
                    CERT_EXPIRY=$(openssl x509 -enddate -noout -in "$SSL_CERT" | cut -d= -f2)
                    CERT_EXPIRY_EPOCH=$(date -d "$CERT_EXPIRY" +%s)
                    CURRENT_EPOCH=$(date +%s)
                    DAYS_LEFT=$(( (CERT_EXPIRY_EPOCH - CURRENT_EPOCH) / 86400 ))

                    if [ "$DAYS_LEFT" -gt 30 ]; then
                        print_success "SSL certificate is valid for $DAYS_LEFT more days"
                    elif [ "$DAYS_LEFT" -gt 0 ]; then
                        print_info "SSL certificate will expire in $DAYS_LEFT days - consider renewal"
                    else
                        print_error "SSL certificate has expired!"
                    fi
                else
                    print_info "openssl not available, skipping certificate expiry check"
                fi
            else
                print_error "SSL certificate file does not exist at $SSL_CERT"
            fi
        else
            print_error "No SSL certificate configuration found in NGINX"
        fi

        # Check if WebSocket configuration exists
        if grep -q "location /ws" /etc/nginx/sites-available/default; then
            print_success "WebSocket configuration found in NGINX"
        else
            print_info "No specific WebSocket configuration found in NGINX"
        fi
    else
        print_error "NGINX configuration not found"
    fi
else
    print_error "NGINX service is not running"
    print_info "Check NGINX status with: systemctl status nginx"
fi

print_header "2. CHECKING NETWORK CONFIGURATION"

# Check port 443 usage
echo "Checking port 443 usage..."
if command_exists netstat; then
    PORT_443_USAGE=$(netstat -tulnp | grep ":443 ")
    if [ -n "$PORT_443_USAGE" ]; then
        print_success "Port 443 is in use"
        print_info "$PORT_443_USAGE"

        # Check if SSLH is using port 443
        if echo "$PORT_443_USAGE" | grep -q "sslh"; then
            print_success "SSLH is listening on port 443"
        else
            print_error "SSLH is not the process listening on port 443"
            print_info "This may cause conflicts with SSH/HTTPS sharing"
        fi
    else
        print_error "Port 443 is not in use - SSLH may not be properly configured"
    fi
else
    print_info "netstat not available, using ss instead"
    PORT_443_USAGE=$(ss -tulnp | grep ":443 ")
    if [ -n "$PORT_443_USAGE" ]; then
        print_success "Port 443 is in use"
        print_info "$PORT_443_USAGE"
    else
        print_error "Port 443 is not in use - SSLH may not be properly configured"
    fi
fi

# Check port 4443 usage
echo -e "\nChecking port 4443 usage (for NGINX SSL)..."
if command_exists netstat; then
    PORT_4443_USAGE=$(netstat -tulnp | grep ":4443 ")
    if [ -n "$PORT_4443_USAGE" ]; then
        print_success "Port 4443 is in use"
        print_info "$PORT_4443_USAGE"

        # Check if NGINX is using port 4443
        if echo "$PORT_4443_USAGE" | grep -q "nginx"; then
            print_success "NGINX is listening on port 4443"
        else
            print_error "NGINX is not the process listening on port 4443"
            print_info "This may cause conflicts with SSLH forwarding"
        fi
    else
        print_error "Port 4443 is not in use - NGINX may not be properly configured"
    fi
else
    print_info "netstat not available, using ss instead"
    PORT_4443_USAGE=$(ss -tulnp | grep ":4443 ")
    if [ -n "$PORT_4443_USAGE" ]; then
        print_success "Port 4443 is in use"
        print_info "$PORT_4443_USAGE"
    else
        print_error "Port 4443 is not in use - NGINX may not be properly configured"
    fi
fi

# Check firewall
echo -e "\nChecking firewall configuration..."
if command_exists ufw; then
    UFW_STATUS=$(ufw status)
    if echo "$UFW_STATUS" | grep -q "Status: active"; then
        print_success "Firewall is active"

        # Check if port 443 is allowed
        if echo "$UFW_STATUS" | grep -q "443/tcp.*ALLOW"; then
            print_success "Firewall allows port 443 (SSH/HTTPS)"
        else
            print_error "Firewall may be blocking port 443 (SSH/HTTPS)"
        fi

        # Check if port 80 is allowed (for Let's Encrypt)
        if echo "$UFW_STATUS" | grep -q "80/tcp.*ALLOW"; then
            print_success "Firewall allows port 80 (HTTP for Let's Encrypt)"
        else
            print_info "Firewall may be blocking port 80 (needed for Let's Encrypt)"
        fi
    else
        print_info "Firewall is not active"
    fi
else
    print_info "UFW not installed, checking iptables"
    IPTABLES_443=$(iptables -L INPUT -v -n | grep "dpt:443")
    if [ -n "$IPTABLES_443" ]; then
        print_info "Found iptables rules for port 443:"
        print_info "$IPTABLES_443"
    else
        print_info "No specific iptables rules found for port 443"
    fi
fi

print_header "3. CHECKING APPLICATION COMPONENTS"

# Check Docker and Docker Compose
echo "Checking Docker service..."
if service_active docker; then
    print_success "Docker service is running"

    # Check if Docker Compose is installed
    if command_exists docker-compose; then
        print_success "Docker Compose is installed"
        DOCKER_COMPOSE_VERSION=$(docker-compose --version)
        print_info "$DOCKER_COMPOSE_VERSION"
    else
        print_error "Docker Compose is not installed"
    fi

    # Check running containers
    echo -e "\nChecking running containers..."
    RUNNING_CONTAINERS=$(docker ps --format "{{.Names}}")
    if [ -n "$RUNNING_CONTAINERS" ]; then
        print_success "Found running containers:"
        echo "$RUNNING_CONTAINERS" | while read container; do
            print_info "- $container"
        done

        # Check specifically for Kafka container
        if echo "$RUNNING_CONTAINERS" | grep -q "kafka"; then
            print_success "Kafka container is running"
        else
            print_info "No Kafka container found running"
        fi
    else
        print_info "No running containers found"
    fi
else
    print_error "Docker service is not running"
    print_info "Check Docker status with: systemctl status docker"
fi

# Check Kubernetes
echo -e "\nChecking Kubernetes service..."
if command_exists kubectl; then
    print_success "Kubernetes CLI (kubectl) is installed"

    # Check if Kubernetes service is running
    if service_active kubelet; then
        print_success "Kubernetes service (kubelet) is running"

        # Check Kubernetes nodes
        echo -e "\nChecking Kubernetes nodes..."
        KUBE_NODES=$(kubectl get nodes 2>/dev/null || echo "Error accessing Kubernetes API")
        if [ "$KUBE_NODES" != "Error accessing Kubernetes API" ]; then
            print_success "Kubernetes API is accessible"
            NODE_COUNT=$(echo "$KUBE_NODES" | tail -n +2 | wc -l)
            print_info "Found $NODE_COUNT node(s)"
            print_info "$KUBE_NODES"

            # Check Kubernetes pods
            echo -e "\nChecking Kubernetes pods..."
            KUBE_PODS=$(kubectl get pods --all-namespaces 2>/dev/null)
            POD_COUNT=$(echo "$KUBE_PODS" | tail -n +2 | wc -l)
            print_info "Found $POD_COUNT pod(s)"

            # Check for specific deployments
            echo -e "\nChecking for deployments..."
            KUBE_DEPLOYMENTS=$(kubectl get deployments --all-namespaces 2>/dev/null)
            DEPLOYMENT_COUNT=$(echo "$KUBE_DEPLOYMENTS" | tail -n +2 | wc -l)
            print_info "Found $DEPLOYMENT_COUNT deployment(s)"

            # Check if Spring Boot is deployed
            if kubectl get deployments --all-namespaces -o wide | grep -q "spring-kafka-streams"; then
                print_success "Spring Boot application is deployed"
            else
                print_info "Spring Boot application is not deployed"
            fi

            # Check if Phoenix LiveView is deployed
            if kubectl get deployments --all-namespaces -o wide | grep -q "elixir-liveview"; then
                print_success "Phoenix LiveView application is deployed"
            else
                print_info "Phoenix LiveView application is not deployed"
            fi

            # Check if MongoDB is deployed
            if kubectl get statefulsets --all-namespaces | grep -q "mongodb"; then
                print_success "MongoDB is deployed"
            else
                print_info "MongoDB is not deployed"
            fi
        else
            print_error "Cannot access Kubernetes API"
            print_info "Check if Kubernetes is correctly configured: kubectl cluster-info"
        fi
    else
        print_error "Kubernetes service (kubelet) is not running"
        print_info "Check Kubernetes status with: systemctl status kubelet"
    fi
else
    print_info "Kubernetes CLI (kubectl) is not installed, skipping Kubernetes checks"
fi

# Check monitoring
echo -e "\nChecking monitoring services..."

# Check Prometheus
if service_active prometheus; then
    print_success "Prometheus service is running"

    # Check Prometheus configuration
    if [ -f /etc/prometheus/prometheus.yml ]; then
        print_success "Prometheus configuration found"
        SCRAPE_TARGETS=$(grep -A10 "scrape_configs:" /etc/prometheus/prometheus.yml | grep "job_name:" | awk '{print $3}' | tr -d "'\"")
        print_info "Configured scrape targets:"
        echo "$SCRAPE_TARGETS" | while read target; do
            print_info "- $target"
        done
    else
        print_error "Prometheus configuration not found"
    fi
else
    print_info "Prometheus service is not running"
fi

# Check Grafana
if service_active grafana-server; then
    print_success "Grafana service is running"

    # Check Grafana configuration
    if [ -d /etc/grafana/provisioning/datasources ]; then
        print_success "Grafana provisioning directory found"
        if ls -la /etc/grafana/provisioning/datasources/*.yml >/dev/null 2>&1; then
            print_success "Grafana datasource configuration found"
            DATASOURCES=$(grep -r "name:" /etc/grafana/provisioning/datasources/ | awk '{print $2}')
            print_info "Configured datasources:"
            echo "$DATASOURCES" | while read ds; do
                print_info "- $ds"
            done
        else
            print_info "No Grafana datasource configurations found"
        fi
    else
        print_info "Grafana provisioning directory not found"
    fi
else
    print_info "Grafana service is not running"
fi

print_header "4. CONNECTION TESTS"

# Test HTTP redirection to HTTPS
echo "Testing HTTP to HTTPS redirection..."
if command_exists curl; then
    HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -m 5 http://$DOMAIN 2>/dev/null || echo "Connection failed")
    if [ "$HTTP_RESPONSE" = "301" ] || [ "$HTTP_RESPONSE" = "302" ]; then
        print_success "HTTP redirects to HTTPS (Status code: $HTTP_RESPONSE)"
    elif [ "$HTTP_RESPONSE" = "200" ]; then
        print_info "HTTP serves content without redirect (Status code: 200)"
        print_info "Consider enabling HTTPS redirection for security"
    elif [ "$HTTP_RESPONSE" = "Connection failed" ]; then
        print_error "Failed to connect to HTTP server"
    else
        print_info "HTTP returned status code: $HTTP_RESPONSE"
    fi
else
    print_info "curl not available, skipping HTTP test"
fi

# Test HTTPS connection
echo -e "\nTesting HTTPS connection..."
if command_exists curl; then
    HTTPS_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -m 5 -k https://$DOMAIN 2>/dev/null || echo "Connection failed")
    if [ "$HTTPS_RESPONSE" = "200" ]; then
        print_success "HTTPS connection successful (Status code: 200)"
    elif [ "$HTTPS_RESPONSE" = "Connection failed" ]; then
        print_error "Failed to connect to HTTPS server"
        print_info "Check if NGINX is properly configured for SSL"
    else
        print_info "HTTPS returned status code: $HTTPS_RESPONSE"
    fi
else
    print_info "curl not available, skipping HTTPS test"
fi

# Test WebSocket connection
echo -e "\nTesting WebSocket endpoint..."
if command_exists curl; then
    WS_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -m 5 -k https://$DOMAIN/ws 2>/dev/null || echo "Connection failed")
    if [ "$WS_RESPONSE" = "Connection failed" ] || [ "$WS_RESPONSE" = "000" ]; then
        print_info "WebSocket endpoint test inconclusive - requires WebSocket client"
        print_info "WebSocket endpoint should be available at wss://$DOMAIN/ws"
    else
        print_info "WebSocket endpoint returned HTTP status: $WS_RESPONSE"
    fi
else
    print_info "curl not available, skipping WebSocket test"
fi

# Self-test SSH on port 443
echo -e "\nTesting SSH on port 443..."
print_info "A proper test requires connecting from another machine."
print_info "Use the following command to test SSH on port 443:"
print_info "  ssh -p 443 user@$DOMAIN"
print_info "The SSH connection should be tunneled through SSLH on port 443"

print_header "5. SUMMARY"

# Count successes and errors
SUCCESS_COUNT=$(grep -c "✓" "$LOG_FILE")
ERROR_COUNT=$(grep -c "✗" "$LOG_FILE")

echo "Test completed with:"
echo "- $SUCCESS_COUNT checks passed"
echo "- $ERROR_COUNT checks failed"

if [ "$ERROR_COUNT" -eq 0 ]; then
    echo -e "\n${GREEN}All tests passed! Your system appears to be properly configured.${NC}"
elif [ "$ERROR_COUNT" -lt 3 ]; then
    echo -e "\n${YELLOW}Most tests passed with a few issues. Review the errors above.${NC}"
else
    echo -e "\n${RED}Several tests failed. Your system may need reconfiguration.${NC}"
fi

echo -e "\nDetailed test results have been saved to: $LOG_FILE"
echo "Completed at: $(date)"
