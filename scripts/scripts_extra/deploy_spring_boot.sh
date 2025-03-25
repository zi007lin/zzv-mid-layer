#!/bin/bash
source scripts/utils.sh

deploy_spring_boot() {
    log_info "Deploying Java Spring Boot..."
    mkdir -p ~/git/zzv-mid-layer/spring-app
    cd ~/git/zzv-mid-layer/spring-app

    tee Dockerfile > /dev/null <<EOF
FROM openjdk:17
WORKDIR /app
COPY target/zzv-mid-layer-0.0.1-SNAPSHOT.jar .
CMD ["java", "-jar", "zzv-mid-layer-0.0.1-SNAPSHOT.jar"]
EOF

    docker build -t zzv-mid-layer/spring-boot-app .
    check_status "Deploying Spring Boot"
}

deploy_spring_boot
