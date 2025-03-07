#!/bin/bash

# Execute each scripts in order
echo "Starting setup..."
bash scripts/ensure_repo_formatted.sh
echo "Ensuring repository is formatted..."
bash scripts/install_core_dependencies.sh
echo "Installing core dependencies..."
bash scripts/setup_sslh.sh
echo "Setting up SSLH..."
bash scripts/configure_nginx.sh
echo "Configuring NGINX..."
bash scripts/configure_nginx.sh
echo "Configuring firewall..."
bash scripts/configure_firewall.sh
echo "Ensuring Docker Compose is installed..."
bash scripts/ensure_docker_compose.sh
echo "Installing Kubernetes..."
bash scripts/install_kubernetes.sh
echo "Deploying Kafka..."
bash scripts/deploy_kafka.sh
echo "Deploying Spring Boot..."
bash scripts/deploy_spring_boot.sh
echo "Deploying Elixir Phoenix..."
bash scripts/deploy_elixir_phoenix.sh
echo "Deploying MongoDB..."
bash scripts/deploy_mongodb.sh
echo "Installing Prometheus..."
bash scripts/install_prometheus.sh
echo "Installing Grafana..."
bash scripts/install_grafana.sh
echo "Setting up Let's Encrypt..."
bash scripts/setup_letsencrypt.sh
echo "Testing setup..."
bash scripts/test_setup.sh
echo "Setup completed successfully!"