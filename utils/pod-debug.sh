#!/bin/bash
# Script pour deboguer un pod
# A executer SUR k8s-orchestrator
# Usage: ./pod-debug.sh <namespace> <pod-name>

export KUBECONFIG=/tmp/k8s-infra/ansible/kubeconfig.yaml

NAMESPACE="$1"
POD_NAME="$2"

if [ -z "$NAMESPACE" ] || [ -z "$POD_NAME" ]; then
    echo "Usage: $0 <namespace> <pod-name>"
    echo ""
    echo "Exemple:"
    echo "  $0 drupal mysql-0"
    exit 1
fi

echo ""
echo "          DEBUG POD                                             "
echo ""
echo ""
echo " Namespace: $NAMESPACE"
echo " Pod: $POD_NAME"
echo ""

echo "=== 1. Informations generales ==="
kubectl get pod $POD_NAME -n $NAMESPACE -o wide

echo ""
echo "=== 2. Status des containers ==="
kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{range .status.containerStatuses[*]}{.name}{": "}{.state}{"\n"}{end}'

echo ""
echo "=== 3. Evenements recents ==="
kubectl describe pod $POD_NAME -n $NAMESPACE | grep -A 15 "Events:"

echo ""
echo "=== 4. Images utilisees ==="
kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{range .spec.containers[*]}{.name}{": "}{.image}{"\n"}{end}'

echo ""
echo "=== 5. Init containers ==="
kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{range .spec.initContainers[*]}{.name}{": "}{.image}{"\n"}{end}' 2>/dev/null || echo "Aucun init container"

echo ""
echo "=== 6. Volumes montes ==="
kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{range .spec.volumes[*]}{.name}{"\n"}{end}'

echo ""
echo "=== 7. Derniers logs (tous containers) ==="
for container in $(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.spec.containers[*].name}'); do
  echo ""
  echo "--- Logs du container: $container ---"
  kubectl logs $POD_NAME -n $NAMESPACE -c $container --tail=20 2>&1 | head -20
done

echo ""
echo ""
echo ""
echo "Commandes utiles:"
echo "  - Voir tous les logs: ./pod-logs.sh $NAMESPACE $POD_NAME"
echo "  - Shell dans le pod: kubectl exec -it $POD_NAME -n $NAMESPACE -- bash"
echo ""
