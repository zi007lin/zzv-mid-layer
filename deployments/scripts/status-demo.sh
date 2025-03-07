#!/bin/bash
echo "Checking Demo Environment Status..."
kubectl get pods -n demo
kubectl get svc -n demo
kubectl get ingress -n demo
