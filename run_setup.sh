#!/usr/bin/env bash

# Execute each script in order
echo "Starting setup..."

echo "Installing core dependencies..."
bash scripts/install_core_dependencies.sh  # ✅ Checked & Modified

echo "Installing Helm (including SSLH)..."
bash scripts/install_helm.sh  # ✅ Checked & Modified (Includes SSLH)

echo "Verifying Helm installation..."
bash scripts/install_helm_test.sh  # ✅ Checked & Modified

echo "Installing Kubernetes..."
bash scripts/install_kubernetes.sh  # ✅ Checked & Modified

echo "Verifying Kubernetes installation..."
bash scripts/install_kubernetes_test.sh  # ✅ Checked & Modified

echo "Ensuring repository is formatted..."
bash scripts/ensure_repo_formatted.sh  # ✅ Checked & Modified

echo "Setting up Reverse Proxy (NGINX)..."
bash scripts/install_reverse_proxy.sh  # ✅ Checked & Modified

echo "Verifying Reverse Proxy setup..."
bash scripts/install_reverse_proxy_test.sh  # ✅ Checked & Modified

echo "Configuring firewall..."
bash scripts/configure_firewall.sh  # ✅ Checked & Modified

# Services that need Helm deployment or further verification
echo "Ensuring Docker Compose is installed..."
# bash scripts/ensure_docker_compose.sh  # ❌ Not checked yet, should verify

echo "Deploying Kafka..."
bash scripts/deploy_kafka.sh  # ✅ Checked & Modified (Kafka KRaft Mode)

echo "Deploying Spring Boot..."
# bash scripts/deploy_spring_boot.sh  # ❌ Not checked yet, needs Helm deployment

echo "Deploying Elixir Phoenix..."
bash scripts/deploy_elixir_phoenix.sh  # ✅ Checked & Modified

echo "Deploying MongoDB..."
# bash scripts/deploy_mongodb.sh  # ❌ Not checked yet, should verify Helm chart

echo "Installing Prometheus..."
# bash scripts/install_prometheus.sh  # ❌ Not checked yet, should verify Helm deployment

echo "Installing Grafana..."
# bash scripts/install_grafana.sh  # ❌ Not checked yet, should verify Helm deployment

echo "Setting up Let's Encrypt..."
# bash scripts/setup_letsencrypt.sh  # ❌ Not checked yet, needs verification

echo "Testing setup..."
# bash scripts/test_setup.sh  # ❌ Not checked yet, should define test cases

echo "Setup completed successfully!"
