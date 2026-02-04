#!/bin/bash
# Script de deploiement du cluster K3s
# Usage: ./deploy-cluster.sh [log_file]

set -e

PASSWORD="${SSH_PASSWORD:?SSH_PASSWORD environment variable required}"
LOG_FILE="${1:-/tmp/deploy-$(date +%Y%m%d-%H%M%S).log}"

echo ""
echo "        DEPLOIEMENT CLUSTER K3S                                 "
echo ""
echo ""

# Verifier que l'archive existe sur k8s-orchestrator
echo "=== Verification prealable ==="
archive_check=$(sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no \
    formation@k8s-orchestrator.example.com \
    "test -f /tmp/k8s-infra.tar.gz && echo 'OK' || echo 'MISSING'")

if [ "$archive_check" != "OK" ]; then
    echo " Archive k8s-infra.tar.gz non trouvee sur k8s-orchestrator:/tmp/"
    echo "   Executez d'abord: ./utils/upload-archive.sh"
    exit 1
fi

echo "   Archive presente sur k8s-orchestrator"
echo ""

echo "=== Lancement du deploiement ==="
echo "   Log: $LOG_FILE (sur k8s-orchestrator)"
echo "    Duree estimee: 40-45 minutes"
echo ""

# Lancer le deploiement en arriere-plan sur k8s-orchestrator
deploy_cmd="cd /tmp && rm -rf k8s-infra && tar xzf k8s-infra.tar.gz && cd k8s-infra && nohup ./deploy.sh > $LOG_FILE 2>&1 & echo \$!"

pid=$(sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no \
    formation@k8s-orchestrator.example.com "$deploy_cmd")

if [ -n "$pid" ]; then
    echo "   Deploiement lance (PID: $pid)"
else
    echo "   Erreur lors du lancement"
    exit 1
fi

echo ""
echo ""
echo "        DEPLOIEMENT LANCE AVEC SUCCES                           "
echo ""
echo ""
echo "Commandes de suivi:"
echo "  1. Surveiller en temps reel:"
echo "     ./utils/watch-deploy.sh $LOG_FILE"
echo ""
echo "  2. Voir les dernieres lignes:"
echo "     ./utils/check-deploy.sh $LOG_FILE"
echo ""
echo "  3. Verifier l'etat du cluster (une fois termine):"
echo "     ./utils/check-cluster.sh"
echo ""
