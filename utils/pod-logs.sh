#!/bin/bash
# Script pour voir les logs d'un pod
# A executer SUR k8s-orchestrator
# Usage: ./pod-logs.sh <namespace> <pod-name> [container] [lines]

export KUBECONFIG=/tmp/k8s-infra/ansible/kubeconfig.yaml

NAMESPACE="$1"
POD_NAME="$2"
CONTAINER="${3:-}"
LINES="${4:-100}"

if [ -z "$NAMESPACE" ] || [ -z "$POD_NAME" ]; then
    echo "Usage: $0 <namespace> <pod-name> [container] [lines]"
    echo ""
    echo "Exemples:"
    echo "  $0 drupal mysql-0"
    echo "  $0 drupal mysql-0 mysql"
    echo "  $0 drupal mysql-0 mysql 200"
    exit 1
fi

echo ""
echo "          LOGS POD                                              "
echo ""
echo ""
echo " Namespace: $NAMESPACE"
echo " Pod: $POD_NAME"
if [ -n "$CONTAINER" ]; then
    echo " Container: $CONTAINER"
fi
echo " Lignes: $LINES"
echo ""
echo ""
echo ""

if [ -n "$CONTAINER" ]; then
    kubectl logs $POD_NAME -n $NAMESPACE -c $CONTAINER --tail=$LINES
else
    kubectl logs $POD_NAME -n $NAMESPACE --tail=$LINES
fi

echo ""
echo ""
echo ""
echo "Commandes utiles:"
echo "  - Logs en temps reel: kubectl logs -f $POD_NAME -n $NAMESPACE"
echo "  - Debug le pod: ./pod-debug.sh $NAMESPACE $POD_NAME"
echo ""
