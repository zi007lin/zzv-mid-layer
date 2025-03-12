#!/bin/bash
source scripts/utils.sh

# Configuration variables - edit these according to your needs
ENVIRONMENT=${ENVIRONMENT:-"production"}  # Options: development, production
BACKUP_DIR="/root/firewall-backups"
CLOUDFLARE_IPS_FILE="/opt/cloudflare/ips.txt"
ZZV_SERVERS_FILE="/opt/zzv/allowed-servers.txt"

# Use Cloudflare IPs or ZZV server IPs
USE_CLOUDFLARE=${USE_CLOUDFLARE:-"true"}
USE_ZZV_SERVERS=${USE_ZZV_SERVERS:-"false"}

# Default to allow only HTTPS (port 443) publicly
PUBLIC_PORTS=("443")

# Kubernetes required ports
K8S_API_PORT="6443"
K8S_KUBELET_PORT="10250"
K8S_NODEPORT_RANGE="30000:32767"
K8S_ETCD_PORTS=("2379" "2380")

# Kafka in KRaft mode ports
KAFKA_CLIENT_PORT="9092"
KAFKA_CONTROLLER_PORT="9093"
KAFKA_INTERNAL_PORT="9094"

backup_firewall_config() {
    log_info "Backing up current firewall configuration..."
    
    # Create backup directory if it doesn't exist
    mkdir -p $BACKUP_DIR
    
    # Backup current UFW rules
    BACKUP_FILE="$BACKUP_DIR/ufw-backup-$(date +%Y%m%d%H%M%S).rules"
    sudo ufw status verbose > "$BACKUP_FILE"
    sudo cp /etc/ufw/user.rules "$BACKUP_FILE.user"
    sudo cp /etc/ufw/before.rules "$BACKUP_FILE.before"
    sudo cp /etc/ufw/after.rules "$BACKUP_FILE.after"
    
    check_status "Backing up firewall configuration"
}

load_allowed_ips() {
    ALLOWED_IPS=()
    
    # Load Cloudflare IPs if specified
    if [[ "$USE_CLOUDFLARE" == "true" && -f "$CLOUDFLARE_IPS_FILE" ]]; then
        log_info "Loading Cloudflare IP ranges..."
        while read -r ip; do
            [[ -n "$ip" && ! "$ip" =~ ^# ]] && ALLOWED_IPS+=("$ip")
        done < "$CLOUDFLARE_IPS_FILE"
        log_info "Loaded ${#ALLOWED_IPS[@]} Cloudflare IP ranges"
    fi
    
    # Load ZZV server IPs if specified
    if [[ "$USE_ZZV_SERVERS" == "true" && -f "$ZZV_SERVERS_FILE" ]]; then
        log_info "Loading ZZV server IP addresses..."
        while read -r ip; do
            [[ -n "$ip" && ! "$ip" =~ ^# ]] && ALLOWED_IPS+=("$ip")
        done < "$ZZV_SERVERS_FILE"
        log_info "Loaded ${#ALLOWED_IPS[@]} ZZV server IPs"
    fi
    
    # If no IPs loaded and not in development, warn
    if [[ ${#ALLOWED_IPS[@]} -eq 0 && "$ENVIRONMENT" != "development" ]]; then
        log_warning "No allowed IPs loaded. This will restrict access to Kubernetes and Kafka only to local traffic!"
    fi
}

configure_base_rules() {
    log_info "Configuring base firewall rules..."
    
    # Reset UFW config
    sudo ufw --force reset
    
    # Set default policies
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    
    # Allow SSH on custom port if configured (safeguard against lockout)
    if [[ -n "$SSH_PORT" && "$SSH_PORT" != "22" ]]; then
        log_info "Adding rule for SSH on port $SSH_PORT..."
        sudo ufw allow $SSH_PORT/tcp comment 'SSH custom port'
    else
        log_info "Adding rule for SSH on default port 22..."
        sudo ufw allow 22/tcp comment 'SSH default port'
    fi
    
    check_status "Configuring base firewall rules"
}

configure_public_services() {
    log_info "Configuring public service ports..."
    
    # Allow HTTP/HTTPS ports for public access
    for port in "${PUBLIC_PORTS[@]}"; do
        log_info "Opening port $port to public..."
        sudo ufw allow $port/tcp comment "Public service port"
    done
    
    # Allow port 80 for HTTP->HTTPS redirects
    sudo ufw allow 80/tcp comment "HTTP for redirects"
    
    check_status "Configuring public service ports"
}

configure_kubernetes_ports() {
    log_info "Configuring Kubernetes ports..."
    
    # If in development mode, allow from anywhere
    if [[ "$ENVIRONMENT" == "development" ]]; then
        log_info "Development mode: allowing Kubernetes ports from anywhere..."
        sudo ufw allow $K8S_API_PORT/tcp comment "K8s API server"
        sudo ufw allow $K8S_KUBELET_PORT/tcp comment "K8s Kubelet"
        sudo ufw allow $K8S_NODEPORT_RANGE/tcp comment "K8s NodePort range"
        for port in "${K8S_ETCD_PORTS[@]}"; do
            sudo ufw allow $port/tcp comment "K8s etcd"
        done
    else
        # Allow from specific IPs only
        if [[ ${#ALLOWED_IPS[@]} -gt 0 ]]; then
            log_info "Restricting Kubernetes ports to ${#ALLOWED_IPS[@]} allowed IPs..."
            
            for ip in "${ALLOWED_IPS[@]}"; do
                sudo ufw allow from $ip to any port $K8S_API_PORT proto tcp comment "K8s API from allowed IP"
                sudo ufw allow from $ip to any port $K8S_KUBELET_PORT proto tcp comment "K8s Kubelet from allowed IP"
                sudo ufw allow from $ip to any port $K8S_NODEPORT_RANGE proto tcp comment "K8s NodePort from allowed IP"
                for port in "${K8S_ETCD_PORTS[@]}"; do
                    sudo ufw allow from $ip to any port $port proto tcp comment "K8s etcd from allowed IP"
                done
            done
        else
            # Only allow from internal/loopback if no allowed IPs specified
            log_info "No allowed IPs specified. Kubernetes ports will only be accessible locally."
            sudo ufw allow from 127.0.0.1 to any port $K8S_API_PORT proto tcp comment "K8s API from localhost"
            sudo ufw allow from 127.0.0.1 to any port $K8S_KUBELET_PORT proto tcp comment "K8s Kubelet from localhost"
            sudo ufw allow from 127.0.0.1 to any port $K8S_NODEPORT_RANGE proto tcp comment "K8s NodePort from localhost"
            for port in "${K8S_ETCD_PORTS[@]}"; do
                sudo ufw allow from 127.0.0.1 to any port $port proto tcp comment "K8s etcd from localhost"
            done
            
            # Also allow from internal cluster network
            sudo ufw allow from 10.0.0.0/8 to any port $K8S_API_PORT proto tcp comment "K8s API from cluster"
            sudo ufw allow from 10.0.0.0/8 to any port $K8S_KUBELET_PORT proto tcp comment "K8s Kubelet from cluster"
            sudo ufw allow from 10.0.0.0/8 to any port $K8S_NODEPORT_RANGE proto tcp comment "K8s NodePort from cluster"
            for port in "${K8S_ETCD_PORTS[@]}"; do
                sudo ufw allow from 10.0.0.0/8 to any port $port proto tcp comment "K8s etcd from cluster"
            done
        fi
    fi
    
    check_status "Configuring Kubernetes ports"
}

configure_kafka_ports() {
    log_info "Configuring Kafka ports (KRaft mode)..."
    
    # If in development mode, allow from anywhere
    if [[ "$ENVIRONMENT" == "development" ]]; then
        log_info "Development mode: allowing Kafka ports from anywhere..."
        sudo ufw allow $KAFKA_CLIENT_PORT/tcp comment "Kafka client connections"
        sudo ufw allow $KAFKA_CONTROLLER_PORT/tcp comment "Kafka controller port"
        sudo ufw allow $KAFKA_INTERNAL_PORT/tcp comment "Kafka internal communication"
    else
        # Allow from specific IPs only
        if [[ ${#ALLOWED_IPS[@]} -gt 0 ]]; then
            log_info "Restricting Kafka ports to ${#ALLOWED_IPS[@]} allowed IPs..."
            
            for ip in "${ALLOWED_IPS[@]}"; do
                sudo ufw allow from $ip to any port $KAFKA_CLIENT_PORT proto tcp comment "Kafka client from allowed IP"
                sudo ufw allow from $ip to any port $KAFKA_CONTROLLER_PORT proto tcp comment "Kafka controller from allowed IP"
                sudo ufw allow from $ip to any port $KAFKA_INTERNAL_PORT proto tcp comment "Kafka internal from allowed IP"
            done
        else
            # Only allow from internal/loopback if no allowed IPs specified
            log_info "No allowed IPs specified. Kafka ports will only be accessible locally."
            sudo ufw allow from 127.0.0.1 to any port $KAFKA_CLIENT_PORT proto tcp comment "Kafka client from localhost"
            sudo ufw allow from 127.0.0.1 to any port $KAFKA_CONTROLLER_PORT proto tcp comment "Kafka controller from localhost"
            sudo ufw allow from 127.0.0.1 to any port $KAFKA_INTERNAL_PORT proto tcp comment "Kafka internal from localhost"
            
            # Also allow from internal network
            sudo ufw allow from 10.0.0.0/8 to any port $KAFKA_CLIENT_PORT proto tcp comment "Kafka client from internal"
            sudo ufw allow from 10.0.0.0/8 to any port $KAFKA_CONTROLLER_PORT proto tcp comment "Kafka controller from internal"
            sudo ufw allow from 10.0.0.0/8 to any port $KAFKA_INTERNAL_PORT proto tcp comment "Kafka internal from internal"
        fi
    fi
    
    check_status "Configuring Kafka ports"
}

enable_firewall() {
    log_info "Enabling UFW firewall..."
    
    # Enable firewall with default settings
    sudo ufw --force enable
    
    # Check if firewall is active
    if sudo ufw status | grep -q "Status: active"; then
        log_info "✅ Firewall is active"
    else
        log_error "❌ Failed to enable firewall"
        exit 1
    fi
}

verify_configuration() {
    log_info "Verifying firewall configuration..."
    
    # Check UFW status
    sudo ufw status verbose
    
    # Display summary of rules
    log_info "Summary of configured rules:"
    PUBLIC_RULE_COUNT=$(sudo ufw status | grep -c "ALLOW")
    log_info "- Public ports open: ${#PUBLIC_PORTS[@]}"
    log_info "- Total firewall rules: $PUBLIC_RULE_COUNT"
    
    if [[ "$ENVIRONMENT" != "development" ]]; then
        log_info "- Restricted access IPs: ${#ALLOWED_IPS[@]}"
    else
        log_warning "Development mode: Some ports may be open to all IPs"
    fi
    
    # Note about restart
    log_info "NOTE: Some services may need to be restarted for changed rules to take effect."
}

configure_firewall() {
    log_info "Starting firewall configuration..."
    
    # Backup existing configuration
    backup_firewall_config
    
    # Load allowed IPs
    load_allowed_ips
    
    # Configure firewall in steps
    configure_base_rules
    configure_public_services
    configure_kubernetes_ports
    configure_kafka_ports
    
    # Enable the firewall
    enable_firewall
    
    # Verify the configuration
    verify_configuration
    
    log_info "Firewall configuration completed successfully!"
    
    # Additional security recommendation
    log_info "SECURITY RECOMMENDATION: Consider setting up fail2ban for additional protection against brute-force attacks."
}

# Execute the main function
configure_firewall