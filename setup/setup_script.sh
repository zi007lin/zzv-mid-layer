#!/bin/bash

# Exit on error
set -e
set -x  # Print each command before executing
# Enable error tracing
trap 'echo "Error on line $LINENO. Exit code: $?"' ERR

# Global variables - replace these with your actual IP addresses
NAM_IP=${NAM_IP:-"212.56.32.206"}
EMEA_IP=${EMEA_IP:-"144.91.76.244"}
APAC_IP=${APAC_IP:-"109.123.234.173"}
DOMAIN=${DOMAIN:-"yourdomain.com"}

# Log file setup
LOGFILE="setup_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOGFILE") 2>&1

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print status messages
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check command status
check_status() {
    if [ $? -ne 0 ]; then
        log_error "$1 failed"
        return 1
    else
        log_info "$1 completed successfully"
        return 0
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if a port is in use
check_port() {
    sudo apt install -y net-tools
    
    local port=$1
    if netstat -tuln | grep -q ":$port "; then
        log_warning "Port $port is already in use"
        netstat -tuln | grep ":$port "
        return 0 # port is in use
    else
        log_info "Port $port is available"
        return 1 # port is not in use
    fi
}

# Function to install core dependencies
install_core_dependencies() {
    log_info "Installing core dependencies..."

    # Update package list
    sudo apt update || { log_error "Failed to update package list"; exit 1; }

    # Install essential packages
    sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
    check_status "Installing essential packages"

    # Add Docker repository
    if ! command_exists docker; then
        log_info "Setting up Docker repository..."
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt update
    else
        log_info "Docker is already installed, skipping repository setup"
    fi

    # Install Docker and other required packages
    log_info "Installing Docker and other required packages..."
    DEBIAN_FRONTEND=noninteractive sudo apt-get install -y -o Dpkg::Options::="--force-confnew" docker-ce containerd.io nginx ufw sslh
    # Pre-configure SSLH to run in standalone mode (bypass interactive prompt)
    echo "sslh sslh/inetd_or_standalone select standalone" | sudo debconf-set-selections
    check_status "Installing Docker and other packages"

    # Set up Docker Compose
    if ! command_exists docker-compose; then
        log_info "Installing Docker Compose..."
        local DOCKER_COMPOSE_VERSION="v2.18.1"
        sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        check_status "Installing Docker Compose"
    else
        log_info "Docker Compose is already installed"
    fi

    # Configure docker to start on boot
    sudo systemctl enable docker
    sudo systemctl start docker
    check_status "Starting Docker service"

    # Add current user to docker group
    if ! groups | grep -q docker; then
        log_info "Adding current user to docker group..."
        sudo usermod -aG docker $USER
        log_warning "You may need to log out and log back in for docker group changes to take effect"
    fi
}

# Function to set up SSLH for SSH + HTTPS on port 443 with WebSocket support
setup_sslh() {
    log_info "Setting up SSLH to share port 443 between SSH and WebSocket traffic..."

    # Pre-configure SSLH to run in standalone mode (bypass interactive prompt)
    echo "sslh sslh/inetd_or_standalone select standalone" | sudo debconf-set-selections

    # Install SSLH without prompting
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get install -y sslh

    # Force reconfigure to standalone mode
    sudo dpkg-reconfigure -f noninteractive sslh

    # Ensure standalone mode is active
    sudo tee /etc/default/sslh > /dev/null <<EOF
RUN=yes
DAEMON_OPTS="--user sslh --listen 0.0.0.0:443 --ssh 127.0.0.1:22 --ssl 127.0.0.1:4443 --pidfile /var/run/sslh/sslh.pid"
EOF

    check_status "Configuring SSLH"

    sudo mkdir -p /var/run/sslh
    sudo chown sslh:sslh /var/run/sslh

    # Enable and restart service
    sudo systemctl enable sslh
    sudo systemctl restart sslh
    check_status "Starting SSLH service"

    # Verify service status
    if ! systemctl is-active --quiet sslh; then
        log_error "SSLH failed to start. Check logs: journalctl -u sslh"
        return 1
    else
        log_info "SSLH is running successfully"
    fi
}

# Function to configure NGINX as a reverse proxy
configure_nginx() {
    log_info "Configuring NGINX..."

    # Check if port 4443 is available
    if check_port 4443; then
        log_warning "Port 4443 is already in use. Checking if it's used by NGINX..."
        if ps aux | grep -v grep | grep -q nginx; then
            log_info "NGINX is already running, will reconfigure it"
        else
            log_error "Port 4443 is in use by another service. Please free up port 4443 before continuing."
            return 1
        fi
    fi

    # Backup existing configuration if it exists
    if [ -f /etc/nginx/sites-available/default ]; then
        sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.bak.$(date +%Y%m%d%H%M%S)
        log_info "Backed up existing NGINX configuration"
    fi

    # Create SSL directory structure (for Let's Encrypt later)
    log_info "Creating SSL directory structure..."
    sudo mkdir -p /etc/letsencrypt/live/${DOMAIN}

    # Create self-signed certificate for initial setup
    if [ ! -f /etc/letsencrypt/live/${DOMAIN}/fullchain.pem ]; then
        log_info "Creating self-signed certificate for initial setup..."
        sudo mkdir -p /etc/ssl/private
        sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout /etc/ssl/private/nginx-selfsigned.key \
            -out /etc/ssl/certs/nginx-selfsigned.crt \
            -subj "/CN=${DOMAIN}"

        # Create symbolic links for Let's Encrypt path structure
        sudo mkdir -p /etc/letsencrypt/live/${DOMAIN}
        sudo ln -sf /etc/ssl/certs/nginx-selfsigned.crt /etc/letsencrypt/live/${DOMAIN}/fullchain.pem
        sudo ln -sf /etc/ssl/private/nginx-selfsigned.key /etc/letsencrypt/live/${DOMAIN}/privkey.pem

        check_status "Creating self-signed certificate"
    else
        log_info "SSL certificate already exists at /etc/letsencrypt/live/${DOMAIN}/"
    fi

    # Create NGINX configuration
    sudo tee /etc/nginx/sites-available/default > /dev/null <<EOF
server {
    # NGINX will listen on port 4443 for SSL traffic that SSLH forwards
    listen 4443 ssl;
    # Optional: You can also listen directly on 443 for testing without SSLH
    # listen 443 ssl;
    server_name ${DOMAIN};

    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;

    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_stapling on;
    ssl_stapling_verify on;

    # WebSocket endpoint
    location /ws {
        proxy_pass http://localhost:8080/ws;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 300s;  # Longer timeout for WebSocket connections
    }

    # Phoenix LiveView frontend
    location / {
        proxy_pass http://localhost:4000;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";
    }

    # Spring Boot API
    location /api {
        proxy_pass http://localhost:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    # MongoDB admin interface
    location /mongo {
        proxy_pass http://localhost:27017;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    # Kafka management UI
    location /kafka {
        proxy_pass http://localhost:9092;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    # Grafana dashboard
    location /grafana {
        proxy_pass http://localhost:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    # Prometheus metrics
    location /prometheus {
        proxy_pass http://localhost:9090;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF
    check_status "Creating NGINX configuration"

    # Test NGINX configuration
    sudo nginx -t
    check_status "Testing NGINX configuration"

    # Restart NGINX
    sudo systemctl restart nginx
    check_status "Restarting NGINX"

    # Verify NGINX is running
    if ! systemctl is-active --quiet nginx; then
        log_error "NGINX service failed to start. Check logs with: journalctl -u nginx"
        return 1
    else
        log_info "NGINX service is running successfully"
    fi
}

# Function to install Kubernetes and Docker
install_kubernetes() {
    log_info "Installing Kubernetes..."

    # Check if Kubernetes is already installed
    if command_exists kubeadm && command_exists kubectl && command_exists kubelet; then
        log_info "Kubernetes is already installed"
        return 0
    fi

    # Add Kubernetes repository
    log_info "Adding Kubernetes repository..."
    sudo mkdir -p /etc/apt/keyrings
    if [ ! -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg ]; then
        curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
        log_info "Kubernetes repository key added."
    else
        log_info "Kubernetes keyring already exists, skipping."
    fi
    #curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null <<EOF
    deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /
    EOF

    sudo apt update
    check_status "Adding Kubernetes repository"

    # Install Kubernetes components
    log_info "Installing Kubernetes components..."
    sudo apt install -y kubeadm kubectl kubelet
    sudo systemctl enable kubelet
    check_status "Installing Kubernetes components"

    # Verify installation
    if ! command_exists kubeadm || ! command_exists kubectl || ! command_exists kubelet; then
        log_error "Kubernetes installation failed"
        return 1
    fi

    log_info "Kubernetes installation completed successfully"
}

# Function to ensure docker-compose is installed
ensure_docker_compose() {
    log_info "Ensuring Docker Compose is installed..."

    # Check if docker-compose is installed
    if ! command -v docker-compose &>/dev/null; then
        log_info "Installing Docker Compose..."
        sudo apt update
        sudo apt install -y docker-compose
        check_status "Installing Docker Compose"
    else
        log_info "Docker Compose is already installed"
    fi
}

# Function to deploy Kafka KRaft Cluster
deploy_kafka() {
    log_info "Deploying Kafka KRaft Cluster..."

    # Check if Docker is installed
    if ! command_exists docker; then
        log_error "Docker is not installed. Please run install_core_dependencies first."
        return 1
    fi

    # Create Kafka data directory
    sudo mkdir -p /var/lib/kafka/data
    sudo chmod 777 /var/lib/kafka/data

    # Create docker-compose.yml for Kafka
    log_info "Creating docker-compose.yml for Kafka..."
    mkdir -p ~/git/zzv-mid-layer/kafka-deployment
    cd ~/git/zzv-mid-layer/kafka-deployment

    tee docker-compose.yml > /dev/null <<EOF
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
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://${NAM_IP}:9092
      KAFKA_LOG_DIRS: /var/lib/kafka/data
      KAFKA_PROCESS_ROLES: controller,broker
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@${NAM_IP}:9093,2@${EMEA_IP}:9093,3@${APAC_IP}:9093
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 3
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: "true"
    volumes:
      - /var/lib/kafka/data:/var/lib/kafka/data
    restart: unless-stopped
volumes:
  kafka_data:
    driver: local
EOF
    check_status "Creating docker-compose.yml"

    mkdir -p ~/git/zzv-mid-layer/kafka-deployment
    if [ ! -f ~/git/zzv-mid-layer/kafka-deployment/docker-compose.yml ]; then
    cat <<EOF > /home/zilin/git/zzv-mid-layer/kafka-deployment/docker-compose.yml
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
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
      KAFKA_LOG_DIRS: /var/lib/kafka/data
      KAFKA_PROCESS_ROLES: controller,broker
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@localhost:9093
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: "true"
    volumes:
      - /var/lib/kafka/data:/var/lib/kafka/data
    restart: unless-stopped
EOF
    check_status "Creating docker-compose.yml"
else
    log_info "docker-compose.yml already exists."
fi
    # Start Kafka
    log_info "Starting Kafka with Docker Compose..."
    docker-compose -f ~/git/zzv-mid-layer/kafka-deployment/docker-compose.yml up -d
    check_status "Starting Kafka"

    # Check if Kafka container is running
    if [ "$(docker ps -q -f name=kafka_kraft)" ]; then
        log_info "Kafka container is running"
    else
        log_error "Kafka container failed to start. Check logs with: docker logs kafka_kraft"
        return 1
    fi
}

# Function to start Kafka
start_kafka() {
    log_info "Starting Kafka with Docker Compose..."
    cd ~/git/zzv-mid-layer/kafka-deployment
    if [ ! -f docker-compose.yml ]; then
        log_error "docker-compose.yml is missing! Ensure setup_kafka() runs properly."
        exit 1
    fi
    docker-compose -f ~/git/zzv-mid-layer/kafka-deployment/docker-compose.yml up -d
    log_info "Kafka has been started successfully."
}

# Function to deploy Java Spring Boot with Kafka Streams
deploy_spring_boot() {
    log_info "Deploying Java Spring Boot with Kafka Streams..."

    # Create app directory
    mkdir -p ~/git/zzv-mid-layer/spring-app
    cd ~/git/zzv-mid-layer/ spring-app

    # Dockerfile for Spring Boot with GraalVM
    log_info "Creating Dockerfile for Spring Boot with GraalVM..."
    tee Dockerfile > /dev/null <<EOF
FROM ghcr.io/graalvm/native-image:latest
WORKDIR /app
COPY target/myapp .
EXPOSE 8080
CMD ["./myapp"]
EOF
    check_status "Creating Spring Boot Dockerfile"

    # Kubernetes deployment configuration
    log_info "Creating Kubernetes deployment for Spring Boot..."
    tee spring-app.yaml > /dev/null <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spring-kafka-streams
spec:
  replicas: 2
  selector:
    matchLabels:
      app: spring-kafka-streams
  template:
    metadata:
      labels:
        app: spring-kafka-streams
    spec:
      containers:
      - name: spring-kafka-streams
        image: myrepo/spring-kafka-streams:latest
        ports:
        - containerPort: 8080
        env:
        - name: KAFKA_BOOTSTRAP_SERVERS
          value: "${NAM_IP}:9092,${EMEA_IP}:9092,${APAC_IP}:9092"
---
apiVersion: v1
kind: Service
metadata:
  name: spring-kafka-streams
spec:
  selector:
    app: spring-kafka-streams
  ports:
  - port: 8080
    targetPort: 8080
  type: ClusterIP
EOF
    check_status "Creating Spring Boot Kubernetes deployment config"

    log_info "Spring Boot configuration created. To deploy:"
    log_info "1. Build your app and create a native image"
    log_info "2. Build the Docker image: docker build -t myrepo/spring-kafka-streams:latest ."
    log_info "3. Deploy to Kubernetes: kubectl apply -f spring-app.yaml"
}

# Function to deploy Elixir Phoenix LiveView
deploy_elixir_phoenix() {
    log_info "Deploying Elixir Phoenix LiveView..."

    # Create app directory
    mkdir -p ~/git/zzv-mid-layer/phoenix-app
    cd ~/git/zzv-mid-layer/phoenix-app

    # Dockerfile for Phoenix
    log_info "Creating Dockerfile for Phoenix LiveView..."
    tee Dockerfile > /dev/null <<EOF
FROM elixir:latest
WORKDIR /app
COPY . .
RUN mix local.hex --force && mix local.rebar --force
RUN mix deps.get
RUN mix compile
RUN mix phx.digest
EXPOSE 4000
CMD ["mix", "phx.server"]
EOF
    check_status "Creating Phoenix Dockerfile"

    # Kubernetes deployment configuration
    log_info "Creating Kubernetes deployment for Phoenix LiveView..."
    tee elixir-liveview.yaml > /dev/null <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: elixir-liveview
spec:
  replicas: 1
  selector:
    matchLabels:
      app: elixir-liveview
  template:
    metadata:
      labels:
        app: elixir-liveview
    spec:
      containers:
      - name: elixir-liveview
        image: myrepo/elixir-liveview:latest
        ports:
        - containerPort: 4000
        env:
        - name: SECRET_KEY_BASE
          value: "your_secret_key_base"
        - name: DATABASE_URL
          value: "ecto://postgres:postgres@postgres-service:5432/app_dev"
---
apiVersion: v1
kind: Service
metadata:
  name: elixir-liveview
spec:
  selector:
    app: elixir-liveview
  ports:
  - port: 4000
    targetPort: 4000
  type: ClusterIP
EOF
    check_status "Creating Phoenix LiveView Kubernetes deployment config"

    log_info "Phoenix LiveView configuration created. To deploy:"
    log_info "1. Build your Phoenix application"
    log_info "2. Build the Docker image: docker build -t myrepo/elixir-liveview:latest ."
    log_info "3. Deploy to Kubernetes: kubectl apply -f elixir-liveview.yaml"
}

# Function to deploy MongoDB
deploy_mongodb() {
    log_info "Deploying MongoDB..."

    # Check if Kubernetes is running
    if ! command_exists kubectl; then
        log_error "kubectl not found. Make sure Kubernetes is installed and configured."
        return 1
    fi

    # Create MongoDB configuration
    mkdir -p ~/mongodb
    cd ~/mongodb

    log_info "Creating MongoDB Kubernetes configuration..."
    tee mongodb.yaml > /dev/null <<EOF
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongodb
spec:
  serviceName: "mongodb"
  replicas: 1
  selector:
    matchLabels:
      app: mongodb
  template:
    metadata:
      labels:
        app: mongodb
    spec:
      containers:
      - name: mongodb
        image: mongo:latest
        ports:
        - containerPort: 27017
        volumeMounts:
        - name: mongodb-data
          mountPath: /data/db
  volumeClaimTemplates:
  - metadata:
      name: mongodb-data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 10Gi
---
apiVersion: v1
kind: Service
metadata:
  name: mongodb
spec:
  selector:
    app: mongodb
  ports:
  - port: 27017
    targetPort: 27017
  type: ClusterIP
EOF
    check_status "Creating MongoDB Kubernetes config"

    # Deploy MongoDB
    log_info "Deploying MongoDB to Kubernetes..."
    if kubectl get namespace | grep -q "^default "; then
        kubectl apply -f mongodb.yaml
        check_status "Deploying MongoDB"
    else
        log_warning "Kubernetes cluster may not be ready, skipping MongoDB deployment"
        log_info "To deploy MongoDB later, run: kubectl apply -f ~/mongodb/mongodb.yaml"
    fi
}

# Function to install Prometheus
install_prometheus() {
    log_info "Installing Prometheus..."

    # Create prometheus user
    if ! id prometheus &>/dev/null; then
        sudo useradd --no-create-home --shell /bin/false prometheus
    fi

    # Download Prometheus
    cd ~
    PROMETHEUS_VERSION="2.37.0"
    if [ ! -f "prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz" ]; then
        log_info "Downloading Prometheus..."
        wget https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
    fi

    log_info "Extracting Prometheus..."
    tar xvfz prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
    cd prometheus-${PROMETHEUS_VERSION}.linux-amd64
    check_status "Extracting Prometheus"

    # Setup directories
    log_info "Setting up Prometheus directories..."
    sudo mkdir -p /etc/prometheus /var/lib/prometheus
    sudo cp prometheus promtool /usr/local/bin/
    sudo cp -r consoles/ console_libraries/ /etc/prometheus/
    sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus
    sudo chown prometheus:prometheus /usr/local/bin/prometheus /usr/local/bin/promtool
    check_status "Setting up Prometheus directories"

    # Configure Prometheus
    log_info "Configuring Prometheus..."
    sudo tee /etc/prometheus/prometheus.yml > /dev/null <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'spring-boot'
    metrics_path: '/actuator/prometheus'
    static_configs:
      - targets: ['localhost:8080']

  - job_name: 'kafka'
    static_configs:
      - targets: ['localhost:9092']
EOF
    check_status "Configuring Prometheus"

    # Setup systemd service
    log_info "Setting up Prometheus systemd service..."
    sudo tee /etc/systemd/system/prometheus.service > /dev/null <<EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF
    check_status "Setting up Prometheus systemd service"

    sudo systemctl daemon-reload
    sudo systemctl start prometheus
    sudo systemctl enable prometheus
    check_status "Starting Prometheus service"

    # Verify Prometheus is running
    if ! systemctl is-active --quiet prometheus; then
        log_error "Prometheus service failed to start. Check logs with: journalctl -u prometheus"
        return 1
    else
        log_info "Prometheus installed and running at http://localhost:9090"
    fi
}

# Function to install Grafana
install_grafana() {
    log_info "Installing Grafana..."

    # Add Grafana repository
    if ! grep -q "packages.grafana.com" /etc/apt/sources.list.d/*.list 2>/dev/null; then
        log_info "Adding Grafana repository..."
        sudo apt install -y apt-transport-https software-properties-common
        wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
        sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
        sudo apt update
        check_status "Adding Grafana repository"
    else
        log_info "Grafana repository already added"
    fi

    # Install Grafana
    log_info "Installing Grafana package..."
    sudo apt install -y grafana
    check_status "Installing Grafana"

    # Create provisioning directories if they don't exist
    sudo mkdir -p /etc/grafana/provisioning/datasources

    # Configure Grafana
    log_info "Configuring Grafana datasource..."
    sudo tee /etc/grafana/provisioning/datasources/prometheus.yml > /dev/null <<EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
EOF
    check_status "Configuring Grafana datasource"

    # Start and enable Grafana
    sudo systemctl start grafana-server
    sudo systemctl enable grafana-server
    check_status "Starting Grafana service"

    # Verify Grafana is running
    if ! systemctl is-active --quiet grafana-server; then
        log_error "Grafana service failed to start. Check logs with: journalctl -u grafana-server"
        return 1
    else
        log_info "Grafana installed and running at http://localhost:3000"
        log_info "Default login: admin/admin"
    fi
}

# Function to configure firewall
configure_firewall() {
    log_info "Configuring firewall..."

    # Check if UFW is installed
    if ! command_exists ufw; then
        log_info "Installing UFW..."
        sudo apt install -y ufw
        check_status "Installing UFW"
    fi

    # Configure UFW
    sudo ufw default deny incoming
    sudo ufw default allow outgoing

    # Allow SSH (through SSLH on port 443)
    sudo ufw allow 443/tcp

    # Allow HTTP/HTTPS for Let's Encrypt
    sudo ufw allow 80/tcp

    # Allow Kubernetes API server
    sudo ufw allow 6443/tcp

    # Allow Kafka ports
    sudo ufw allow 9092/tcp
    sudo ufw allow 9093/tcp

    # Allow monitoring ports
    sudo ufw allow 3000/tcp  # Grafana
    sudo ufw allow 9090/tcp  # Prometheus

    # Allow application ports (for direct access if needed)
    sudo ufw allow 4000/tcp  # Phoenix LiveView
    sudo ufw allow 8080/tcp  # Spring Boot
    sudo ufw allow 27017/tcp # MongoDB

    # Enable firewall if not already enabled
    if sudo ufw status | grep -q "Status: inactive"; then
        log_info "Enabling UFW firewall..."
        sudo ufw --force enable
        check_status "Enabling UFW firewall"
    else
        log_info "UFW firewall is already enabled"
    fi

    log_info "Firewall configured with the following rules:"
    sudo ufw status verbose
}

# Function to set up Let's Encrypt
setup_letsencrypt() {
    log_info "Setting up Let's Encrypt..."

    # Check if ports 80 and 443 are available for Let's Encrypt verification
    if check_port 80; then
        log_warning "Port 80 is in use. Let's Encrypt may have issues with domain verification."
    fi

    # Install certbot
    log_info "Installing certbot..."
    sudo apt install -y certbot python3-certbot-nginx
    check_status "Installing certbot"

    # Check if domain resolves to the correct IP
    log_info "Checking if domain ${DOMAIN} resolves correctly..."
    PUBLIC_IP=$(curl -s ifconfig.me)
    DOMAIN_IP=$(dig +short ${DOMAIN} 2>/dev/null || echo "not_resolved")

    if [ "$DOMAIN_IP" = "not_resolved" ]; then
        log_warning "Domain ${DOMAIN} does not resolve to any IP address. Let's Encrypt will fail."
    else
        log_info "Domain ${DOMAIN} resolves to IP ${DOMAIN_IP}"
    fi

    # Run certbot
    log_info "Running certbot..."
    sudo certbot --nginx -d ${DOMAIN}
    check_status "Running certbot"

    # Verify certificate installation
    log_info "Verifying certificate installation..."
    sudo certbot --nginx -d ${DOMAIN} --dry-run
    check_status "Verifying certificate installation"

    # Restart NGINX to apply new configuration
    log_info "Restarting NGINX..."
    sudo systemctl restart nginx
    check_status "Restarting NGINX"

    log_info "Let's Encrypt setup complete"
}

# Main execution
log_info "Starting setup process..."

# Ask for IP addresses and domain if not provided
if [ "$NAM_IP" = "your_nam_ip" ]; then
    read -p "Enter NAM server IP address: " NAM_IP
fi

if [ "$EMEA_IP" = "your_emea_ip" ]; then
    read -p "Enter EMEA server IP address: " EMEA_IP
fi

if [ "$APAC_IP" = "your_apac_ip" ]; then
    read -p "Enter APAC server IP address: " APAC_IP
fi

if [ "$DOMAIN" = "yourdomain.com" ]; then
    read -p "Enter your domain name: " DOMAIN
fi

# Execute functions in sequence
install_core_dependencies
setup_sslh
configure_nginx
configure_firewall
ensure_docker_compose
install_kubernetes
deploy_kafka
deploy_spring_boot
deploy_elixir_phoenix
deploy_mongodb
install_prometheus
install_grafana
setup_letsencrypt

log_info "Setup complete! Your distributed system is now ready."
log_info "Remember to check individual services for any additional configuration."

# Function to start all services
start_all_services() {
    log_info "Starting all services..."

    # Start Kafka
    start_kafka

    # Start Spring Boot
    start_spring_boot

    # Start Elixir Phoenix
    start_elixir_phoenix

