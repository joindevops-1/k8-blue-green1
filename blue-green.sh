#!/bin/bash

ACTION=$1
COLOR=$2

usage() {
  echo "Usage: $0 <action> [color]"
  echo ""
  echo "Actions:"
  echo "  deploy          Apply all manifests"
  echo "  switch <color>  Switch live traffic to blue or green"
  echo "  status          Show pods and services"
  echo "  preview         Port-forward preview service (green) on localhost:8080"
  echo "  rollback        Switch live traffic back to blue"
  echo "  cleanup <color> Delete blue or green deployment"
  echo ""
  echo "Examples:"
  echo "  $0 deploy"
  echo "  $0 switch green"
  echo "  $0 switch blue"
  echo "  $0 status"
  echo "  $0 preview"
  echo "  $0 rollback"
  echo "  $0 cleanup blue"
  exit 1
}

if [ -z "$ACTION" ]; then
  usage
fi

case $ACTION in
  deploy)
    echo "Deploying all manifests..."
    kubectl apply -f 01-blue-deployment.yaml
    kubectl apply -f 02-green-deployment.yaml
    kubectl apply -f 03-main-service.yaml
    kubectl apply -f 04-preview-service.yaml
    echo ""
    echo "Waiting for pods to be ready..."
    kubectl rollout status deployment/sample-blue
    kubectl rollout status deployment/sample-green
    ;;

  switch)
    if [ -z "$COLOR" ] || { [ "$COLOR" != "blue" ] && [ "$COLOR" != "green" ]; }; then
      echo "Error: specify blue or green"
      usage
    fi
    echo "Switching live traffic to $COLOR..."
    kubectl patch svc sample -p "{\"spec\":{\"selector\":{\"color\":\"$COLOR\"}}}"
    echo "Live traffic now pointing to: $COLOR"
    ;;

  status)
    echo "=== Pods ==="
    kubectl get pods -l purpose=blue-green --show-labels
    echo ""
    echo "=== Services ==="
    kubectl get svc sample sample-preview
    echo ""
    echo "=== Live traffic going to ==="
    kubectl get svc sample -o jsonpath='{.spec.selector.color}' && echo ""
    ;;

  preview)
    echo "Port-forwarding preview (green) service on http://localhost:8080 ..."
    kubectl port-forward svc/sample-preview 8080:80
    ;;

  rollback)
    echo "Rolling back live traffic to blue..."
    kubectl patch svc sample -p '{"spec":{"selector":{"color":"blue"}}}'
    echo "Live traffic now pointing to: blue"
    ;;

  cleanup)
    if [ -z "$COLOR" ] || { [ "$COLOR" != "blue" ] && [ "$COLOR" != "green" ]; }; then
      echo "Error: specify blue or green"
      usage
    fi
    echo "Deleting sample-$COLOR deployment..."
    kubectl delete deployment sample-$COLOR
    echo "Deleted sample-$COLOR"
    ;;

  *)
    echo "Unknown action: $ACTION"
    usage
    ;;
esac
