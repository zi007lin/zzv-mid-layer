#!/bin/bash
echo "Deleting Demo Environment..."
kubectl delete -f demo/kafka-demo-statefulset.yaml
kubectl delete -f demo/mongodb-demo-statefulset.yaml
kubectl delete -f demo/spring-boot-demo-deployment.yaml
kubectl delete -f demo/ingress-demo.yaml
echo "Demo Environment Deleted!"
