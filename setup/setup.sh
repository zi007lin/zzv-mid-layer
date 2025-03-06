#!/bin/bash

#!/bin/bash

# Global variables - replace these with your actual IP addresses
NAM_IP="your_nam_ip"
EMEA_IP="your_emea_ip"
APAC_IP="your_apac_ip"
DOMAIN="yourdomain.com"

# Function to install core dependencies
install_core_dependencies() {
    echo "Installing core dependencies..."
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt update && sudo apt install -y docker-ce containerd nginx ufw sslh

    # Set up Docker Compose
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.18.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

    # Configure docker to start on boot
    sudo systemctl enable docker
    sudo systemctl start docker
}

# Function to set up SSLH for SSH + HTTPS on port 443 with WebSocket support
setup_sslh() {
    echo "Setting up SSLH to share port 443 between SSH and WebSocket traffic..."
    sudo tee /etc/default/sslh <<EOF
# Use sslh in standalone mode
RUN=yes

# Listen on port 443 for all interfaces
# This configuration routes SSH traffic to local port 22 and all HTTPS/WSS traffic to Nginx on port 4443
DAEMON_OPTS="--user sslh --listen 0.0.0.0:443 --ssh 127.0.0.1:22 --ssl 127.0.0.1:4443 --pidfile /var/run/sslh/sslh.pid"
EOF

    # Create the run directory if it doesn't exist
    sudo mkdir -p /var/run/sslh
    sudo chown sslh:sslh /var/run/sslh

    # Enable and restart sslh service
    sudo systemctl enable sslh
    sudo systemctl restart sslh

    echo "SSLH configured to handle both SSH and HTTPS/WebSocket traffic on port 443"
}

# Function to configure NGINX as a reverse proxy
configure_nginx() {
    echo "Configuring NGINX..."
    sudo tee /etc/nginx/sites-available/default <<EOF
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
    sudo systemctl restart nginx
}

# Function to install Kubernetes and Docker
install_kubernetes() {
    echo "Installing Kubernetes..."
    # Add Kubernetes repository
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
    sudo tee /etc/apt/sources.list.d/kubernetes.list <<EOF
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
    sudo apt update
    sudo apt install -y kubeadm kubectl kubelet
    sudo systemctl enable kubelet

    # Configure hostname
    HOSTNAME=$(hostname)

    if [ "$HOSTNAME" = "NAM" ]; then
        echo "Initializing Kubernetes control plane on NAM node..."
        # Initialize Kubernetes on the control plane (NAM VPS)
        sudo kubeadm init --pod-network-cidr=192.168.0.0/16

        # Set up kubectl for the current user
        mkdir -p $HOME/.kube
        sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
        sudo chown $(id -u):$(id -g) $HOME/.kube/config

        # Apply the Calico network plugin
        kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

        # Generate join command for worker nodes
        JOIN_COMMAND=$(kubeadm token create --print-join-command)
        echo "Use the following command to join other nodes to the cluster:"
        echo "$JOIN_COMMAND"
    else
        echo "This is not the NAM node. To join the Kubernetes cluster, run the join command provided by the NAM node."
    fi
}

# Function to deploy Kafka KRaft Cluster
deploy_kafka() {
    echo "Deploying Kafka KRaft Cluster..."

    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        echo "Docker is not installed. Please run install_core_dependencies first."
        exit 1
    fi

    # Create Kafka data directory
    sudo mkdir -p /var/lib/kafka/data
    sudo chmod 777 /var/lib/kafka/data

    # Create docker-compose.yml for Kafka
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
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://${NAM_IP}:9092
      KAFKA_LOG_DIRS: /var/lib/kafka/data
      KAFKA_PROCESS_ROLES: controller,broker
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@${NAM_IP}:9093,2@${EMEA_IP}:9093,3@${APAC_IP}:9093
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 3
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: "true"
    volumes:
      - /var/lib/kafka/data:/var/lib/kafka/data
volumes:
  kafka_data:
    driver: local
EOF
    docker-compose up -d
}

# Function to deploy Java Spring Boot with Kafka Streams
deploy_spring_boot() {
    echo "Deploying Java Spring Boot with Kafka Streams..."

    # Create app directory
    mkdir -p ~/spring-app
    cd ~/spring-app

    # Dockerfile for Spring Boot with GraalVM
    sudo tee Dockerfile <<EOF
FROM ghcr.io/graalvm/native-image:latest
WORKDIR /app
COPY target/myapp .
EXPOSE 8080
CMD ["./myapp"]
EOF

    # Kubernetes deployment configuration
    sudo tee spring-app.yaml <<EOF
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

    echo "Spring Boot configuration created. To deploy, build your app and run: kubectl apply -f spring-app.yaml"
}

# Function to deploy Elixir Phoenix LiveView
deploy_elixir_phoenix() {
    echo "Deploying Elixir Phoenix LiveView..."

    # Create app directory
    mkdir -p ~/phoenix-app
    cd ~/phoenix-app

    # Dockerfile for Phoenix
    sudo tee Dockerfile <<EOF
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

    # Kubernetes deployment configuration
    sudo tee elixir-liveview.yaml <<EOF
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

    echo "Phoenix LiveView configuration created. To deploy, build your app and run: kubectl apply -f elixir-liveview.yaml"
}

# Function to deploy MongoDB
deploy_mongodb() {
    echo "Deploying MongoDB..."

    # Create MongoDB configuration
    mkdir -p ~/mongodb
    cd ~/mongodb

    sudo tee mongodb.yaml <<EOF
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

    kubectl apply -f mongodb.yaml
}

# Function to install Prometheus
install_prometheus() {
    echo "Installing Prometheus..."

    # Create prometheus user
    sudo useradd --no-create-home --shell /bin/false prometheus

    # Get Prometheus
    cd ~
    wget https://github.com/prometheus/prometheus/releases/download/v2.37.0/prometheus-2.37.0.linux-amd64.tar.gz
    tar xvfz prometheus-2.37.0.linux-amd64.tar.gz
    cd prometheus-2.37.0.linux-amd64

    # Setup directories
    sudo mkdir -p /etc/prometheus /var/lib/prometheus
    sudo cp prometheus promtool /usr/local/bin/
    sudo cp -r consoles/ console_libraries/ /etc/prometheus/
    sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus
    sudo chown prometheus:prometheus /usr/local/bin/prometheus /usr/local/bin/promtool

    # Configure Prometheus
    sudo tee /etc/prometheus/prometheus.yml <<EOF
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

    # Setup systemd service
    sudo tee /etc/systemd/system/prometheus.service <<EOF
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

    sudo systemctl daemon-reload
    sudo systemctl start prometheus
    sudo systemctl enable prometheus

    echo "Prometheus installed and running at http://localhost:9090"
}

# Function to install Grafana
install_grafana() {
    echo "Installing Grafana..."

    # Add Grafana repository
    sudo apt install -y apt-transport-https software-properties-common
    wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
    sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"

    # Install Grafana
    sudo apt update && sudo apt install -y grafana

    # Configure Grafana
    sudo tee /etc/grafana/provisioning/datasources/prometheus.yml <<EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
EOF

    # Start and enable Grafana
    sudo systemctl start grafana-server
    sudo systemctl enable grafana-server

    echo "Grafana installed and running at http://localhost:3000"
    echo "Default login: admin/admin"
}

# Function to configure firewall
configure_firewall() {
    echo "Configuring firewall..."

    sudo ufw default deny incoming
    sudo ufw default allow outgoing

    # Allow SSH (through SSLH on port 443)
    sudo ufw allow 443/tcp

    # Allow HTTP/HTTPS for Let's Encrypt
    sudo ufw allow 80/tcp

    # Allow Kubernetes API server
    sudo ufw allow 6443/tcp

    # Enable firewall
    sudo ufw --force enable

    echo "Firewall configured and enabled"
}

# Function to set up Let's Encrypt
setup_letsencrypt() {
    echo "Setting up Let's Encrypt..."

    # Install certbot
    sudo apt install -y certbot python3-certbot-nginx

    # Get certificate (this will prompt for interaction)
    sudo certbot --nginx -d ${DOMAIN}

    # Setup auto-renewal
    sudo systemctl enable certbot.timer
    sudo systemctl start certbot.timer

    echo "Let's Encrypt configured. Certificates will auto-renew."
}

# Main script execution
echo "Starting the setup process..."

# Ask user for IP addresses if not provided
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

# Main installation
install_core_dependencies
setup_sslh
configure_firewall
setup_letsencrypt
configure_nginx
install_kubernetes
deploy_kafka
deploy_spring_boot
deploy_elixir_phoenix
deploy_mongodb
install_prometheus
install_grafana

echo "Setup complete! Your distributed system is now ready."
echo "Remember to check individual services for any additional configuration."

# Ensure yq is installed for parsing YAML
if ! command -v yq &> /dev/null; then
    echo "Installing yq for YAML parsing..."
    sudo apt update && sudo apt install -y yq
fi

# Function to execute a command safely
execute_cmd() {
    local cmd="$1"
    if [ -z "$cmd" ]; then
        echo "Error: No command provided"
        return 1
    fi
    echo "Executing: $cmd"
    if ! eval "$cmd"; then
        echo "Error executing command: $cmd"
        return 1
    fi
}

# Function to check if a package is installed before installing
install_package() {
    local package="$1"
    if ! dpkg -l | grep -q "^ii  $package "; then
        echo "Installing package: $package"
        sudo apt install -y "$package"
    else
        echo "Package $package is already installed."
    fi
}

# Function to check if a service is running before restarting
restart_service() {
    local service="$1"
    if systemctl is-active --quiet "$service"; then
        echo "Restarting service: $service"
        sudo systemctl restart "$service"
    else
        echo "Service $service is not running, skipping restart."
    fi
}

# Read YAML and execute relevant sections
echo "Reading setup.yml..."

# Gather system info
echo "Gathering system information..."
yq e '.setup.system_info[]' setup.yml | while read -r cmd; do
    execute_cmd "$cmd"
done

# Install required packages
echo "Checking and installing required packages..."
yq e '.setup.installed_packages[]' setup.yml | while read -r package; do
    install_package "$package"
done

# Apply firewall settings
echo "Configuring firewall..."
yq e '.setup.firewall[]' setup.yml | while read -r cmd; do
    execute_cmd "$cmd"
done

# Apply network settings
echo "Applying network configurations..."
yq e '.setup.network[]' setup.yml | while read -r cmd; do
    execute_cmd "$cmd"
done

# Restore user permissions
echo "Restoring user permissions..."
yq e '.setup.user_permissions[]' setup.yml | while read -r cmd; do
    execute_cmd "$cmd"
done

# Restore environment variables
echo "Restoring environment variables..."
yq e '.setup.env_variables[]' setup.yml | while read -r cmd; do
    execute_cmd "$cmd"
done

# Restart necessary services if they exist
echo "Restarting necessary services..."
yq e '.setup.running_services[]' setup.yml | while read -r service; do
    restart_service "$service"
done

# Finalize setup
echo "Finalizing setup..."
yq e '.setup.finalize[]' setup.yml | while read -r cmd; do
    execute_cmd "$cmd"
done

echo "Ubuntu instance setup is complete."
