#!/bin/bash
# Script de verification rapide du deploiement
# Usage: ./check-deploy.sh [log_file] [lines]

PASSWORD="${SSH_PASSWORD:?SSH_PASSWORD environment variable required}"
LOG_FILE="${1:-/tmp/deploy-final-fixed.log}"
LINES="${2:-50}"

echo ""
echo "        VERIFICATION DEPLOIEMENT                                "
echo ""
echo ""
echo " Log: $LOG_FILE"
echo " Lignes: $LINES dernieres"
echo ""

# Verifier si le fichier existe
file_check=$(sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no \
    formation@k8s-orchestrator.example.com \
    "test -f $LOG_FILE && echo 'OK' || echo 'MISSING'")

if [ "$file_check" != "OK" ]; then
    echo " Fichier log non trouve: $LOG_FILE"
    echo ""
    echo "Fichiers disponibles:"
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no \
        formation@k8s-orchestrator.example.com \
        "ls -lh /tmp/deploy*.log 2>/dev/null || echo 'Aucun fichier deploy*.log trouve'"
    exit 1
fi

echo ""
echo ""

# Afficher les dernieres lignes
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no \
    formation@k8s-orchestrator.example.com \
    "tail -$LINES $LOG_FILE"

echo ""
echo ""
echo ""

# Rechercher les erreurs
error_count=$(sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no \
    formation@k8s-orchestrator.example.com \
    "grep -c 'fatal\\|FAILED' $LOG_FILE 2>/dev/null || echo '0'")

if [ "$error_count" -gt 0 ]; then
    echo "  $error_count erreur(s) detectee(s)"
    echo ""
    echo "Dernieres erreurs:"
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no \
        formation@k8s-orchestrator.example.com \
        "grep -A 3 'fatal\\|FAILED' $LOG_FILE | tail -20"
else
    echo " Aucune erreur detectee dans le log"
fi

echo ""
echo "Commandes utiles:"
echo "  - Voir tout le log: ./utils/watch-deploy.sh $LOG_FILE"
echo "  - Verifier le cluster: ./utils/check-cluster.sh"
echo ""
