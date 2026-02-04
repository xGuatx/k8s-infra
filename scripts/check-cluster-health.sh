#!/bin/bash
# Check complete cluster health
# Run from k8s-orchestrator

set -euo pipefail

KUBECONFIG="${KUBECONFIG:-$HOME/k8s-infra/ansible/kubeconfig.yaml}"
export KUBECONFIG

echo ""
echo "          CLUSTER HEALTH CHECK                          "
echo ""
echo ""

# 1. Check nodes
echo "=== NODES STATUS ==="
kubectl get nodes -o wide
echo ""

# 2. Check Drupal namespace
echo "=== DRUPAL NAMESPACE ==="
kubectl get pods -n drupal -o wide
echo ""
echo "MySQL Replication Status:"
for i in 0 1 2; do
  echo "  mysql-$i:"
  kubectl exec -it mysql-$i -n drupal -- mysql -u root -pDrupalR00t@2025 -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep -E "Slave_IO_Running|Slave_SQL_Running" || echo "    Primary node (no replication)"
done
echo ""

# 3. Check Drupal connectivity
echo "=== DRUPAL WEB TEST ==="
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- \
  curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://drupal.drupal.svc.cluster.local || true
echo ""

# 4. Check monitoring
echo "=== MONITORING NAMESPACE ==="
kubectl get pods -n monitoring -o wide | grep -E "prometheus|grafana|alertmanager"
echo ""

# 5. Check storage
echo "=== STORAGE (Longhorn) ==="
kubectl get pvc -A
echo ""
kubectl get pods -n longhorn-system -o wide | head -5
echo ""

# 6. Check backups
echo "=== BACKUP STATUS (Velero) ==="
velero backup get 2>/dev/null || echo "Velero not yet configured"
echo ""

# 7. Resource usage
echo "=== RESOURCE USAGE ==="
kubectl top nodes 2>/dev/null || echo "Metrics server not available"
echo ""

# 8. Events
echo "=== RECENT EVENTS (Last 5 warnings) ==="
kubectl get events -A --sort-by='.lastTimestamp' | grep -i warning | tail -5 || echo "No warnings"
echo ""

echo ""
echo "          HEALTH CHECK COMPLETE                         "
echo ""
