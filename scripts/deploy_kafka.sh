#!/bin/bash
source scripts/utils.sh

deploy_kafka() {
    log_info "Deploying Kafka in KRaft mode..."
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
      KAFKA_LOG_DIRS: /var/lib/kafka/data
      KAFKA_PROCESS_ROLES: controller,broker
    restart: unless-stopped
EOF

    docker-compose up -d
    check_status "Starting Kafka"
}

deploy_kafka
