#!/bin/bash

# Hardcoded IPs
NAM_IP="212.56.32.206"
EMEA_IP="144.91.76.244"
APAC_IP="109.123.234.173"
DOMAIN="zzv.io"

# Function to install core dependencies
install_core_dependencies() {
    echo "Installing core dependencies..."
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt update && sudo apt install -y docker-ce containerd nginx ufw sslh

    # Install Docker Compose
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

    # Enable Docker service
    sudo systemctl enable docker
    sudo systemctl start docker
}

# Function to set up SSLH for SSH + HTTPS/WebSockets on port 443
setup_sslh() {
    echo "Configuring SSLH..."
    sudo tee /etc/default/sslh <<EOF
RUN=yes
DAEMON_OPTS="--user sslh --listen 0.0.0.0:443 --ssh 127.0.0.1:22 --tls 127.0.0.1:4443 --pidfile /var/run/sslh/sslh.pid"
EOF
    sudo systemctl enable sslh
    sudo systemctl restart sslh
}

# Function to configure NGINX as a reverse proxy
configure_nginx() {
    echo "Configuring NGINX..."
    sudo tee /etc/nginx/sites-available/default <<EOF
server {
    listen 4443 ssl;
    server_name ${DOMAIN};

    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    
    location /ws {
        proxy_pass http://localhost:8080/ws;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location / {
        proxy_pass http://localhost:4000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
    }

    location /api {
        proxy_pass http://localhost:8080;
    }

    location /grafana {
        proxy_pass http://localhost:3000;
    }

    location /prometheus {
        proxy_pass http://localhost:9090;
    }
}
EOF
    sudo systemctl restart nginx
}

# Function to install Kubernetes and configure cluster
install_kubernetes() {
    echo "Installing Kubernetes..."
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
    sudo tee /etc/apt/sources.list.d/kubernetes.list <<EOF
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
    sudo apt update
    sudo apt install -y kubeadm kubectl kubelet
    sudo systemctl enable kubelet

    HOSTNAME=$(hostname)
    if [ "$HOSTNAME" = "p1-nam" ]; then
        sudo kubeadm init --pod-network-cidr=192.168.0.0/16
        mkdir -p $HOME/.kube
        sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
        sudo chown $(id -u):$(id -g) $HOME/.kube/config
        kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
        kubeadm token create --print-join-command > ~/join_kubernetes.sh
    else
        echo "To join Kubernetes, run: $(cat ~/join_kubernetes.sh)"
    fi
}

# Function to deploy Kafka KRaft
deploy_kafka() {
    echo "Deploying Kafka KRaft..."
    sudo mkdir -p /var/lib/kafka/data
    sudo chmod 777 /var/lib/kafka/data
    sudo tee docker-compose.yml <<EOF
version: '3.9'
services:
  kafka:
    image: confluentinc/cp-kafka:latest
    container_name: kafka_kraft
    ports:
      - "9092:9092"
      - "9093:9093"
    environment:
      KAFKA_NODE_ID: 1
      KAFKA_LISTENERS: PLAINTEXT://:9092,CONTROLLER://:9093
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://${NAM_IP}:9092,PLAINTEXT://${EMEA_IP}:9092,PLAINTEXT://${APAC_IP}:9092
      KAFKA_PROCESS_ROLES: controller,broker
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@${NAM_IP}:9093,2@${EMEA_IP}:9093,3@${APAC_IP}:9093
volumes:
  kafka_data:
    driver: local
EOF
    docker-compose up -d
}

# Function to configure firewall
configure_firewall() {
    echo "Configuring firewall..."
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow 443/tcp
    sudo ufw allow 80/tcp
    sudo ufw allow 6443/tcp
    sudo ufw allow 10250:10255/tcp
    sudo ufw allow 6783/tcp
    sudo ufw allow 9092/tcp
    sudo ufw allow 9093/tcp
    sudo ufw --force enable
}

# Function to install Prometheus
install_prometheus() {
    echo "Installing Prometheus..."
    sudo useradd --no-create-home --shell /bin/false prometheus
    wget https://github.com/prometheus/prometheus/releases/latest/download/prometheus-$(uname -s)-$(uname -m).tar.gz
    tar xvfz prometheus-*.tar.gz
    cd prometheus-*
    sudo chmod +x prometheus promtool
    sudo mv prometheus promtool /usr/local/bin/
    sudo tee /etc/systemd/system/prometheus.service <<EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
ExecStart=/usr/local/bin/prometheus --config.file /etc/prometheus/prometheus.yml --storage.tsdb.path /var/lib/prometheus/
[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl start prometheus
    sudo systemctl enable prometheus
}

# Function to install Grafana
install_grafana() {
    echo "Installing Grafana..."
    sudo apt install -y apt-transport-https software-properties-common
    wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
    sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
    sudo apt update && sudo apt install -y grafana
    sudo systemctl enable --now grafana-server
}

# Main script execution
echo "Starting the setup process..."
install_core_dependencies
setup_sslh
configure_firewall
configure_nginx
install_kubernetes
deploy_kafka
install_prometheus
install_grafana
echo "Setup complete! Your distributed system is ready."
