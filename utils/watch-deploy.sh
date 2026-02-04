#!/bin/bash
# Script de surveillance en temps reel du deploiement
# Usage: ./watch-deploy.sh [log_file]

PASSWORD="${SSH_PASSWORD:?SSH_PASSWORD environment variable required}"
LOG_FILE="${1:-/tmp/deploy-final-fixed.log}"

echo ""
echo "        SURVEILLANCE TEMPS REEL DU DEPLOIEMENT                  "
echo ""
echo ""
echo " Log: $LOG_FILE"
echo " Mode: Temps reel (tail -f)"
echo "  Appuyez sur Ctrl+C pour quitter"
echo ""
echo ""
echo ""

# Surveiller le log en temps reel
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no \
    formation@k8s-orchestrator.example.com \
    "tail -f $LOG_FILE 2>/dev/null || echo ' Fichier log non trouve: $LOG_FILE'"

echo ""
echo " Surveillance interrompue"
