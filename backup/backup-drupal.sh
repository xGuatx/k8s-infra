#!/bin/bash
# Backup Drupal MySQL + Files using Velero
# Run on k8s-orchestrator with KUBECONFIG set

set -euo pipefail

KUBECONFIG="${KUBECONFIG:-$HOME/k8s-infra/ansible/kubeconfig.yaml}"
export KUBECONFIG

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="drupal-backup-$TIMESTAMP"

echo "=== Drupal Backup Started: $TIMESTAMP ==="

# Create Velero backup
velero backup create "$BACKUP_NAME" \
  --include-namespaces drupal \
  --ttl 168h \
  --wait

# Verify backup
velero backup describe "$BACKUP_NAME"

echo ""
echo "=== Backup Complete ==="
echo "Backup name: $BACKUP_NAME"
echo "Retention: 168h (7 days)"
echo ""
echo "To restore: velero restore create --from-backup $BACKUP_NAME"
