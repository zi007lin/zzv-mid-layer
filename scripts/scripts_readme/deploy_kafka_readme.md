I need to create a comprehensive README file for the `deploy_kafka.sh` script that deploys Kafka in KRaft mode on Kubernetes. This should explain each part of the script in detail to help users understand how Kafka is being deployed and configured.

First, I'll structure my document with clear sections:
1. Introduction to Kafka KRaft mode
2. Overview of the deployment script
3. Detailed explanations of each component:
   - Namespace creation
   - ConfigMap details
   - Service configurations
   - StatefulSet specifications
4. Post-deployment validation
5. Troubleshooting common issues

For each Kubernetes resource, I'll explain its purpose and key configuration parameters.

I'll make sure to explain KRaft-specific configurations, like controller quorum voters, process roles, and listener configurations.

#### 

```yaml
title: "deploy_kafka_readme.md"
content: |
  # Deploying Kafka in KRaft Mode on Kubernetes

  ## Overview

  This document explains the `deploy_kafka.sh` script which deploys Apache Kafka in KRaft (Kafka Raft) mode on a Kubernetes cluster. KRaft mode eliminates the need for ZooKeeper, making Kafka deployments simpler and more efficient.

  ## What is KRaft Mode?

  KRaft mode replaces ZooKeeper with a built-in Raft implementation for managing metadata. This provides several benefits:
  - Simplified architecture (no separate ZooKeeper ensemble)
  - Better scalability
  - Reduced operational complexity
  - Improved performance for metadata operations

  ## Script Components

  The script performs the following actions:

  ### 1. Initial Setup

  ```bash
  #!/usr/bin/env bash

  # Include logging functions
  . "$(dirname "$0")/utils.sh"
  ```

  - Uses a portable shebang line to ensure compatibility across different environments
  - Sources the `utils.sh` file from the same directory, which contains logging functions

  ### 2. Creating a Kafka Namespace

  ```bash
  kubectl create namespace kafka 2>/dev/null || true
  ```

  - Creates a dedicated `kafka` namespace for better resource isolation
  - The `2>/dev/null || true` ensures the script continues even if the namespace already exists

  ### 3. Kafka Configuration (ConfigMap)

  ```yaml
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
  ```

  This ConfigMap contains the core Kafka configuration:

  - **node.id=1**: Unique identifier for the Kafka node
  - **process.roles=broker,controller**: In KRaft mode, a node can be a broker (handles client requests), a controller (handles metadata), or both. Here we're configuring a combined role.
  - **controller.quorum.voters**: Lists all the controllers participating in voting (format: id@host:port). For a single-node setup, we only have one voter.
  - **controller.listener.names**: Specifies which listener is used for controller connections
  - **listeners**: Defines all listeners:
    - PLAINTEXT://:9092: For client connections
    - CONTROLLER://:9093: For internal controller communication
  - **listener.security.protocol.map**: Maps listener names to security protocols
  - **advertised.listeners**: The address clients will use to connect
  - **log.dirs**: Directory where Kafka stores its log files
  - **replication factors**: Set to 1 for a single-node deployment

  ### 4. Kafka Services

  Two service types are created:

  #### Standard Service
  ```yaml
  apiVersion: v1
  kind: Service
  metadata:
    name: kafka
    namespace: kafka
  spec:
    ports:
    - port: 9092
      name: plaintext
    selector:
      app: kafka
  ```

  - Creates a standard service named `kafka` exposing port 9092
  - This service provides a stable DNS name for client applications

  #### Headless Service
  ```yaml
  apiVersion: v1
  kind: Service
  metadata:
    name: kafka-headless
    namespace: kafka
  spec:
    ports:
    - port: 9092
      name: plaintext
    - port: 9093
      name: controller
    clusterIP: None
    selector:
      app: kafka
  ```

  - Creates a headless service (clusterIP: None) named `kafka-headless`
  - Exposes both the client port (9092) and controller port (9093)
  - A headless service is essential for StatefulSets to provide stable DNS names for each pod

  ### 5. Kafka StatefulSet

  ```yaml
  apiVersion: apps/v1
  kind: StatefulSet
  metadata:
    name: kafka
    namespace: kafka
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
          # Other environment variables...
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
  ```

  - Uses a StatefulSet for stable network identities and persistent storage
  - Key StatefulSet settings:
    - **serviceName**: Links to the headless service
    - **replicas: 1**: Creates a single Kafka broker (for production, increase this)
  
  - Container configuration:
    - **image**: Uses Confluent's Kafka image version 7.3.2
    - **ports**: Exposes both client and controller ports
  
  - Environment variables:
    - **KAFKA_CLUSTER_ID**: A unique ID for the Kafka cluster (this should be generated once and reused)
    - **KAFKA_NODE_ID**: Must match the node.id in the ConfigMap
    - **KAFKA_PROCESS_ROLES**: Defines this node as both broker and controller
    - **KAFKA_CONTROLLER_QUORUM_VOTERS**: Same as in the ConfigMap
    - **KAFKA_LISTENERS** and related settings: Configure how clients and controllers connect
  
  - Storage configuration:
    - **volumeClaimTemplates**: Provisions a 10Gi persistent volume for Kafka data
    - Ensures data persistence across pod restarts

  ### 6. Deployment and Verification

  ```bash
  # Apply Kubernetes manifests
  kubectl apply -f kafka-configmap.yaml
  check_status "Creating Kafka ConfigMap"
  
  kubectl apply -f kafka-service.yaml
  check_status "Creating Kafka Services"
  
  kubectl apply -f kafka-statefulset.yaml
  check_status "Creating Kafka StatefulSet"
  
  # Wait for Kafka to be ready
  kubectl -n kafka rollout status statefulset/kafka --timeout=300s
  check_status "Kafka StatefulSet deployment"
  ```

  - Applies each Kubernetes manifest in sequence
  - Checks the status after each step using the `check_status` function
  - Waits for the StatefulSet rollout to complete with a 5-minute timeout
  - Displays the final deployment status with pod information

  ## Accessing Kafka

  After deployment, Kafka is accessible within the cluster at:
  - `kafka.kafka.svc.cluster.local:9092` for client connections

  ## Scaling and Production Considerations

  This deployment creates a single-node Kafka cluster for simplicity. For production use:
  
  1. Increase replicas (3 or more recommended)
  2. Update controller.quorum.voters to include all controller nodes
  3. Configure appropriate resource limits
  4. Consider network policies for security
  5. Set up monitoring and alerting

  ## Troubleshooting

  ### Pod Won't Start
  Check logs with: `kubectl logs -n kafka kafka-0`

  ### Connection Issues
  Verify service endpoints: `kubectl -n kafka get endpoints`

  ### Storage Issues
  Check persistent volume status: `kubectl -n kafka get pvc`

  ## Additional Resources

  - [Kafka KRaft Mode Documentation](https://kafka.apache.org/documentation/#kraft)
  - [Confluent Kafka Container Documentation](https://docs.confluent.io/platform/current/installation/docker/config-reference.html)
  - [Kubernetes StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
```