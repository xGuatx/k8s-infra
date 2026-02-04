#!/bin/bash
# Script d'upload de l'archive sur k8s-orchestrator
# Usage: ./upload-archive.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PASSWORD="${SSH_PASSWORD:?SSH_PASSWORD environment variable required}"

echo ""
echo "        UPLOAD ARCHIVE VERS K8S16                               "
echo ""
echo ""

# Verifier que nous sommes dans le bon repertoire
if [ ! -f "$PROJECT_DIR/deploy.sh" ]; then
    echo " Erreur: deploy.sh non trouve dans $PROJECT_DIR"
    echo "   Executez ce script depuis k8s-infra/utils/"
    exit 1
fi

echo "=== Etape 1/3: Creation de l'archive ==="
cd "$(dirname "$PROJECT_DIR")"
echo "   Creation de k8s-infra.tar.gz..."

tar czf k8s-infra.tar.gz k8s-infra/ \
    --exclude='k8s-infra/.env.tmp' \
    --exclude='k8s-infra/ansible/.vault_password' \
    --exclude='k8s-infra/ansible/inventory/group_vars/vault.yml' \
    --exclude='k8s-infra/ansible/inventory/group_vars/orchestration/vault.yml' \
    --exclude='k8s-infra/ansible/kubeconfig.yaml'

archive_size=$(du -h k8s-infra.tar.gz | cut -f1)
echo "   Archive creee ($archive_size)"

echo ""
echo "=== Etape 2/3: Upload vers k8s-orchestrator ==="
echo "   Transfert en cours..."

sshpass -p "$PASSWORD" scp -o StrictHostKeyChecking=no \
    k8s-infra.tar.gz formation@k8s-orchestrator.example.com:/tmp/

if [ $? -eq 0 ]; then
    echo "   Archive uploadee sur k8s-orchestrator:/tmp/"
else
    echo "   Erreur lors de l'upload"
    exit 1
fi

echo ""
echo "=== Etape 3/3: Verification sur k8s-orchestrator ==="
remote_size=$(sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no \
    formation@k8s-orchestrator.example.com \
    "du -h /tmp/k8s-infra.tar.gz 2>/dev/null | cut -f1")

if [ -n "$remote_size" ]; then
    echo "   Archive presente sur k8s-orchestrator ($remote_size)"
else
    echo "   Archive non trouvee sur k8s-orchestrator"
    exit 1
fi

echo ""
echo ""
echo "        UPLOAD TERMINE AVEC SUCCES                              "
echo ""
echo ""
echo "Prochaine etape:"
echo "  ./utils/deploy-cluster.sh"
echo ""
