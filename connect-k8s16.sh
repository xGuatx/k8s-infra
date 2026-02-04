#!/bin/bash
# Script pour se connecter a k8s-orchestrator et se placer dans le bon repertoire
# Usage: ./connect-k8s-orchestrator.sh

PASSWORD="${SSH_PASSWORD:-your_password_here}"
USER="${SSH_USER:-your_user}"
HOST="${K8S_HOST:-k8s-orchestrator.example.com}"

echo ""
echo "        CONNEXION A K8S16                                       "
echo ""
echo ""
echo " Host: $HOST"
echo " User: $USER"
echo " Repertoire: /tmp/k8s-infra/utils"
echo ""
echo " Une fois connecte, vous pouvez executer:"
echo "   - ./check-cluster.sh          # Verifier le cluster"
echo "   - ./pod-logs.sh drupal mysql-0  # Voir logs d'un pod"
echo "   - ./pod-debug.sh drupal mysql-0 # Debug un pod"
echo ""
echo ""
echo ""

# Se connecter et se placer dans le bon repertoire
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no ${USER}@${HOST} \
  "cd /tmp/k8s-infra/utils && bash -l"
