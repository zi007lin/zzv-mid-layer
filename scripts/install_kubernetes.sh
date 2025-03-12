#!/usr/bin/env bash

. "$(dirname "$0")/utils.sh"

# Default configuration
K3S_VERSION="latest"
K3S_CONFIG=""
INSTALL_MODE="server"  # server or agent
INSTALL_OPTIONS=""
BACKUP_EXISTING=true

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --version=*)
            K3S_VERSION="${1#*=}"
            shift
            ;;
        --mode=*)
            INSTALL_MODE="${1#*=}"
            shift
            ;;
        --disable-traefik)
            INSTALL_OPTIONS="$INSTALL_OPTIONS --disable=traefik"
            shift
            ;;
        --server-url=*)
            SERVER_URL="${1#*=}"
            shift
            ;;
        --token=*)
            K3S_TOKEN="${1#*=}"
            shift
            ;;
        --no-backup)
            BACKUP_EXISTING=false
            shift
            ;;
        *)
            log_warning "Unknown option: $1"
            shift
            ;;
    esac
done

# Check system requirements
check_system_requirements() {
    log_info "Checking system requirements..."
    
    # Check CPU cores
    CPU_CORES=$(grep -c ^processor /proc/cpuinfo)
    if [ "$CPU_CORES" -lt 2 ]; then
        log_warning "⚠️ Only $CPU_CORES CPU core detected. Minimum recommended is 2 cores."
    else
        log_info "✅ CPU: $CPU_CORES cores available"
    fi
    
    # Check memory
    TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$TOTAL_MEM" -lt 1024 ]; then
        log_warning "⚠️ Only $TOTAL_MEM MB RAM detected. Minimum recommended is 1024 MB."
    else
        log_info "✅ Memory: $TOTAL_MEM MB available"
    fi
    
    # Check disk space
    FREE_DISK=$(df -m / | awk 'NR==2 {print $4}')
    if [ "$FREE_DISK" -lt 5120 ]; then
        log_warning "⚠️ Only $FREE_DISK MB free disk space detected. Minimum recommended is 5120 MB."
    else
        log_info "✅ Disk: $FREE_DISK MB available"
    fi
    
    # Check distribution
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        log_info "✅ Distribution: $PRETTY_NAME"
    else
        log_warning "⚠️ Could not determine Linux distribution."
    fi
}

# Backup existing Kubernetes configuration
backup_kube_config() {
    if [ "$BACKUP_EXISTING" = true ] && [ -f ~/.kube/config ]; then
        BACKUP_FILE=~/.kube/config.bak.$(date +%Y%m%d%H%M%S)
        log_info "Backing up existing kubectl configuration to $BACKUP_FILE"
        cp ~/.kube/config "$BACKUP_FILE"
        check_status "Backing up kubectl configuration"
    fi
}

install_kubernetes() {
    log_info "Installing K3s (lightweight Kubernetes distribution)..."
    
    # Check system requirements
    check_system_requirements
    
    # Update system packages
    log_info "Updating system packages..."
    sudo apt update && sudo apt upgrade -y
    check_status "System update"
    
    # Install required dependencies
    log_info "Installing dependencies..."
    sudo apt install -y curl openssl
    check_status "Installing dependencies"
    
    # Backup existing configuration
    backup_kube_config
    
    # Prepare K3s installation
    INSTALL_CMD="curl -sfL https://get.k3s.io"
    
    # Add version if specified
    if [ "$K3S_VERSION" != "latest" ]; then
        INSTALL_CMD="$INSTALL_CMD | INSTALL_K3S_VERSION=$K3S_VERSION sh -"
    else
        INSTALL_CMD="$INSTALL_CMD | sh -"
    fi
    
    # Configure installation mode
    if [ "$INSTALL_MODE" = "server" ]; then
        log_info "Installing K3s in server mode..."
        if [ -n "$INSTALL_OPTIONS" ]; then
            INSTALL_CMD="curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC=\"$INSTALL_OPTIONS\" sh -"
        else
            INSTALL_CMD="curl -sfL https://get.k3s.io | sh -"
        fi
    elif [ "$INSTALL_MODE" = "agent" ]; then
        if [ -z "$SERVER_URL" ]; then
            log_error "Server URL is required for agent mode. Use --server-url=https://server-ip:6443"
            exit 1
        fi
        
        if [ -z "$K3S_TOKEN" ]; then
            log_warning "No token provided for agent. Attempting to fetch from server..."
            if command -v ssh &> /dev/null; then
                SERVER_IP=${SERVER_URL#*://}
                SERVER_IP=${SERVER_IP%:*}
                log_info "Trying to fetch token from $SERVER_IP..."
                K3S_TOKEN=$(ssh $SERVER_IP "sudo cat /var/lib/rancher/k3s/server/node-token" 2>/dev/null)
                if [ -z "$K3S_TOKEN" ]; then
                    log_error "Could not fetch token automatically. Please provide it with --token="
                    exit 1
                fi
            else
                log_error "Could not fetch token automatically. Please provide it with --token="
                exit 1
            fi
        fi
        
        log_info "Installing K3s in agent mode..."
        INSTALL_CMD="curl -sfL https://get.k3s.io | K3S_URL=$SERVER_URL K3S_TOKEN=$K3S_TOKEN sh -"
    else
        log_error "Invalid installation mode: $INSTALL_MODE. Use 'server' or 'agent'."
        exit 1
    fi
    
    # Install K3s
    log_info "Running K3s installation..."
    eval "$INSTALL_CMD"
    check_status "Installing K3s"
    
    # Enable and check K3s service
    log_info "Enabling K3s service..."
    if [ "$INSTALL_MODE" = "server" ]; then
        sudo systemctl enable k3s
        sudo systemctl status k3s --no-pager
        check_status "Enabling K3s service"
    else
        sudo systemctl enable k3s-agent
        sudo systemctl status k3s-agent --no-pager
        check_status "Enabling K3s-agent service"
    fi
    
    # Configure kubectl
    if [ "$INSTALL_MODE" = "server" ]; then
        log_info "Configuring kubectl..."
        mkdir -p ~/.kube
        sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
        sudo chown $(id -u):$(id -g) ~/.kube/config
        check_status "Configuring kubectl"
        
        # Wait for node to become ready
        log_info "Waiting for node to be ready..."
        TIMEOUT=120
        START_TIME=$(date +%s)
        
        while true; do
            if kubectl get nodes 2>/dev/null | grep -q "Ready"; then
                log_info "✅ Node is Ready"
                break
            fi
            
            CURRENT_TIME=$(date +%s)
            if [ $((CURRENT_TIME - START_TIME)) -gt $TIMEOUT ]; then
                log_warning "⚠️ Timeout waiting for node to be ready. Continuing anyway..."
                break
            fi
            
            log_info "Waiting for node to be ready... ($(($TIMEOUT - $CURRENT_TIME + $START_TIME))s remaining)"
            sleep 5
        done
        
        # Verify installation
        log_info "Verifying K3s installation..."
        kubectl get nodes
        check_status "K3s installation verification"
    fi
    
    log_info "✅ K3s installation completed successfully!"
    
    if [ "$INSTALL_MODE" = "server" ]; then
        NODE_TOKEN=$(sudo cat /var/lib/rancher/k3s/server/node-token)
        SERVER_IP=$(hostname -I | awk '{print $1}')
        log_info "To add worker nodes, run on each node:"
        log_info "curl -sfL https://get.k3s.io | K3S_URL=https://$SERVER_IP:6443 K3S_TOKEN=$NODE_TOKEN sh -"
    fi
}

install_kubernetes