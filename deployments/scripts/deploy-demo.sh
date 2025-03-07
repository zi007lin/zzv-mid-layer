#!/bin/bash
echo "Deploying Demo Environment..."
kubectl apply -f demo/kafka-demo-statefulset.yaml
kubectl apply -f demo/mongodb-demo-statefulset.yaml
kubectl apply -f demo/spring-boot-demo-deployment.yaml
kubectl apply -f demo/ingress-demo.yaml
echo "Demo Deployment Completed!"
