#!/usr/bin/env bash

# Include logging functions
. "$(dirname "$0")/utils.sh"

deploy_kafka() {
    log_info "Deploying Kafka in KRaft mode on Kubernetes..."
    
    # Create namespace
    log_info "Creating kafka namespace..."
    kubectl create namespace kafka 2>/dev/null || true
    
    # Create directory for Kubernetes manifests
    mkdir -p ~/git/zzv-mid-layer/kafka-k8s
    cd ~/git/zzv-mid-layer/kafka-k8s
    
    # Create Kafka ConfigMap
    log_info "Creating Kafka configuration..."
    tee kafka-configmap.yaml > /dev/null <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: kafka-config
  namespace: kafka
data:
  server.properties: |
    node.id=1
    process.roles=broker,controller
    controller.quorum.voters=1@kafka-0.kafka-headless.kafka.svc.cluster.local:9093
    controller.listener.names=CONTROLLER
    inter.broker.listener.name=PLAINTEXT
    listeners=PLAINTEXT://:9092,CONTROLLER://:9093
    listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
    advertised.listeners=PLAINTEXT://kafka.kafka.svc.cluster.local:9092
    log.dirs=/var/lib/kafka/data
    num.partitions=1
    default.replication.factor=1
    offsets.topic.replication.factor=1
    transaction.state.log.replication.factor=1
    transaction.state.log.min.isr=1
    min.insync.replicas=1
    auto.create.topics.enable=true
EOF
    
    # Create Kafka Service
    log_info "Creating Kafka service..."
    tee kafka-service.yaml > /dev/null <<EOF
apiVersion: v1
kind: Service
metadata:
  name: kafka
  namespace: kafka
  labels:
    app: kafka
spec:
  ports:
  - port: 9092
    name: plaintext
  selector:
    app: kafka
---
apiVersion: v1
kind: Service
metadata:
  name: kafka-headless
  namespace: kafka
  labels:
    app: kafka
spec:
  ports:
  - port: 9092
    name: plaintext
  - port: 9093
    name: controller
  clusterIP: None
  selector:
    app: kafka
EOF
    
    # Create Kafka StatefulSet
    log_info "Creating Kafka StatefulSet..."
    tee kafka-statefulset.yaml > /dev/null <<EOF
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: kafka
  namespace: kafka
  labels:
    app: kafka
spec:
  serviceName: "kafka-headless"
  replicas: 1
  selector:
    matchLabels:
      app: kafka
  template:
    metadata:
      labels:
        app: kafka
    spec:
      containers:
      - name: kafka
        image: confluentinc/cp-kafka:7.3.2
        ports:
        - containerPort: 9092
          name: plaintext
        - containerPort: 9093
          name: controller
        env:
        - name: KAFKA_CLUSTER_ID
          value: "MkU3OEVBNTcwNTJENDM2Qk"
        - name: KAFKA_NODE_ID
          value: "1"
        - name: KAFKA_PROCESS_ROLES
          value: "broker,controller"
        - name: KAFKA_CONTROLLER_QUORUM_VOTERS
          value: "1@kafka-0.kafka-headless.kafka.svc.cluster.local:9093"
        - name: KAFKA_CONTROLLER_LISTENER_NAMES
          value: "CONTROLLER"
        - name: KAFKA_LISTENERS
          value: "PLAINTEXT://:9092,CONTROLLER://:9093"
        - name: KAFKA_LISTENER_SECURITY_PROTOCOL_MAP
          value: "CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT"
        - name: KAFKA_ADVERTISED_LISTENERS
          value: "PLAINTEXT://kafka-0.kafka-headless.kafka.svc.cluster.local:9092"
        - name: KAFKA_INTER_BROKER_LISTENER_NAME
          value: "PLAINTEXT"
        - name: KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR
          value: "1"
        - name: KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS
          value: "0"
        - name: KAFKA_TRANSACTION_STATE_LOG_MIN_ISR
          value: "1"
        - name: KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR
          value: "1"
        - name: KAFKA_LOG_DIRS
          value: "/var/lib/kafka/data"
        volumeMounts:
        - name: data
          mountPath: /var/lib/kafka/data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 10Gi
EOF
    
    # Apply Kubernetes manifests
    log_info "Applying Kafka manifests to Kubernetes..."
    kubectl apply -f kafka-configmap.yaml
    check_status "Creating Kafka ConfigMap"
    
    kubectl apply -f kafka-service.yaml
    check_status "Creating Kafka Services"
    
    kubectl apply -f kafka-statefulset.yaml
    check_status "Creating Kafka StatefulSet"
    
    # Wait for Kafka to be ready
    log_info "Waiting for Kafka to be ready..."
    kubectl -n kafka rollout status statefulset/kafka --timeout=300s
    check_status "Kafka StatefulSet deployment"
    
    log_info "✅ Kafka deployment completed successfully!"
    log_info "Kafka is accessible within the cluster at: kafka.kafka.svc.cluster.local:9092"
    
    # Check pod status
    kubectl -n kafka get pods
}

deploy_kafka