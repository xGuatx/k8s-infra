#!/bin/bash
# Script de verification rapide du cluster K3s

export KUBECONFIG=/tmp/k8s-infra/ansible/kubeconfig.yaml

echo ""
echo "          VERIFICATION RAPIDE CLUSTER K3S                       "
echo ""

echo ""
echo "=== 1. Nuds K3s ==="
kubectl get nodes -o wide 2>/dev/null || echo " Cluster non accessible"

echo ""
echo "=== 2. Namespaces ==="
kubectl get namespaces 2>/dev/null | grep -E "NAME|longhorn|cert-manager|drupal|monitoring|velero"

echo ""
echo "=== 3. Pods par Namespace ==="

echo ""
echo "   Longhorn:"
kubectl get pods -n longhorn-system 2>/dev/null | grep -E "NAME|Running|Error|CrashLoop|Pending" | head -5

echo ""
echo "   Cert-Manager:"
kubectl get pods -n cert-manager 2>/dev/null | grep -E "NAME|Running|Error|CrashLoop|Pending"

echo ""
echo "   Drupal + MySQL:"
kubectl get pods -n drupal 2>/dev/null | grep -E "NAME|Running|Error|CrashLoop|Pending|Init"

echo ""
echo "   Monitoring:"
kubectl get pods -n monitoring 2>/dev/null | grep -E "NAME|Running|Error|CrashLoop|Pending" | head -5

echo ""
echo "=== 4. PVC Status ==="
kubectl get pvc -n drupal 2>/dev/null

echo ""
echo "=== 5. Services ==="
kubectl get svc -n drupal 2>/dev/null

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
