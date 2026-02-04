#!/bin/bash
# Script de verification complete du cluster K3s
# A executer SUR k8s-orchestrator directement
# Usage: ./check-cluster.sh

export KUBECONFIG=/tmp/k8s-infra/ansible/kubeconfig.yaml

echo ""
echo "          VERIFICATION COMPLETE CLUSTER K3S                     "
echo ""
echo ""

# Verifier que le kubeconfig existe
if [ ! -f "$KUBECONFIG" ]; then
    echo " Kubeconfig non trouve: $KUBECONFIG"
    echo "   Le deploiement n'est peut-etre pas encore termine"
    exit 1
fi

echo "=== 1. Nuds K3s ==="
kubectl get nodes -o wide 2>/dev/null || echo " Cluster non accessible"

echo ""
echo "=== 2. Namespaces ==="
kubectl get namespaces 2>/dev/null | grep -E "NAME|longhorn|cert-manager|drupal|monitoring|velero" || echo " Erreur kubectl"

echo ""
echo "=== 3. Pods par Namespace ==="

echo ""
echo "   Longhorn:"
kubectl get pods -n longhorn-system 2>/dev/null | head -6 || echo "    Namespace non trouve"

echo ""
echo "   Cert-Manager:"
kubectl get pods -n cert-manager 2>/dev/null || echo "    Namespace non trouve"

echo ""
echo "   Drupal + MySQL:"
kubectl get pods -n drupal -o wide 2>/dev/null || echo "    Namespace non trouve"

echo ""
echo "   Monitoring:"
kubectl get pods -n monitoring 2>/dev/null | head -6 || echo "    Namespace non trouve"

echo ""
echo "=== 4. PVC Status ==="
kubectl get pvc -n drupal 2>/dev/null || echo "  Aucun PVC ou namespace non trouve"

echo ""
echo "=== 5. Services ==="
kubectl get svc -n drupal 2>/dev/null || echo "  Namespace drupal non trouve"

echo ""
echo "=== 6. Resume des Erreurs ==="
ERROR_PODS=$(kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded 2>/dev/null | grep -v "NAME" | wc -l)
if [ "$ERROR_PODS" -eq 0 ]; then
  echo " Aucun pod en erreur"
else
  echo " $ERROR_PODS pods en erreur:"
  kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded 2>/dev/null
fi

echo ""
echo ""
echo ""
echo "Commandes supplementaires:"
echo "  - Voir logs d'un pod: ./pod-logs.sh <namespace> <pod-name>"
echo "  - Debug un pod: ./pod-debug.sh <namespace> <pod-name>"
echo ""
