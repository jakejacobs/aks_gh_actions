#!/bin/bash

echo "Deploying the node backend to local cluster"
kubectl apply -f deployment.yaml

echo "Waiting for the deployment to be ready"
# kubectl wait --for=condition=available --timeout=60s deployment/node-backend

while true
do
  RUNNING_PODS=$(kubectl get pods -l app=node --field-selector=status.phase=Running --no-headers | wc -l)

  if [ "$RUNNING_PODS" -ge 2 ]; then
    echo "Deployment is ready with $RUNNING_PODS running pods."
    break
  else
    echo "Waiting for deployment to be ready..."
    sleep 5
  fi
done

echo "App is live! Run 'kubectl port-forward' to access it."
echo "kubectl port-forward service/node-app 8080:3000"