#!/bin/bash
source scripts/utils.sh

deploy_mongodb() {
    log_info "Deploying MongoDB..."
    kubectl apply -f mongodb.yaml
    check_status "Deploying MongoDB"
}

deploy_mongodb
