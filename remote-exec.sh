#!/bin/bash
# Script pour executer des commandes sur k8s-orchestrator depuis la machine locale
# Usage: ./remote-exec.sh <command>

PASSWORD="${SSH_PASSWORD:?SSH_PASSWORD environment variable required}"
USER="${SSH_USER:-your_user}"
HOST="k8s-orchestrator.example.com"

if [ -z "$1" ]; then
    echo "Usage: $0 <command>"
    echo ""
    echo "Exemples:"
    echo "  $0 'cd /tmp/k8s-infra/utils && ./check-cluster.sh'"
    echo "  $0 'cd /tmp/k8s-infra/utils && ./pod-logs.sh drupal mysql-0'"
    exit 1
fi

# Executer la commande sur k8s-orchestrator
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no ${USER}@${HOST} "$1"
