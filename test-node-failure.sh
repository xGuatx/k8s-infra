#!/bin/bash
# Test pratique de perte de nud
# Usage: ./test-node-failure.sh [k8s-master-1|k8s-master-2|k8s-master-3]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"

ENV_FILE_SSH_USER=""
ENV_FILE_SSH_PASSWORD=""
ENV_FILE="$REPO_ROOT/.env.tmp"
if [ -f "$ENV_FILE" ]; then
    while IFS='=' read -r key value; do
        case "$key" in
            SSH_PASSWORD|PWD) ENV_FILE_SSH_PASSWORD="$value" ;;
            SSH_USER|USER) ENV_FILE_SSH_USER="$value" ;;
        esac
    done < "$ENV_FILE"
fi

SSH_USER="${SSH_USER:-${ENV_FILE_SSH_USER:-${USER:-formation}}}"
SSH_PASSWORD_VALUE="${SSH_PASSWORD:-${ENV_FILE_SSH_PASSWORD:-}}"

if [ -z "$SSH_PASSWORD_VALUE" ]; then
    echo " SSH_PASSWORD non defini (export SSH_PASSWORD=... ou renseigner .env.tmp)."
    exit 1
fi

NODE=${1:-k8s-master-1}
KUBECONFIG="${KUBECONFIG:-$HOME/k8s-infra/ansible/kubeconfig.yaml}"
export KUBECONFIG

echo ""
echo "   TEST PERTE NUD: $NODE"
echo ""
echo ""

# Etat initial
echo "=== ETAT INITIAL ==="
echo "Nodes:"
kubectl get nodes -o wide
echo ""
echo "Pods Drupal:"
kubectl get pods -n drupal -l app=drupal -o wide
echo ""
echo "Pods MySQL:"
kubectl get pods -n drupal -l app=mysql -o wide
echo ""
echo "Service accessible:"
curl -s -o /dev/null -w "%{http_code}" http://k8s-master-1.example.com:30080 || echo "HTTP FAILED"
echo ""

read -p "Simuler panne de $NODE ? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Annule."
    exit 0
fi

# Simuler panne
echo ""
echo "=== SIMULATION PANNE $NODE ==="
ssh "${SSH_USER}@${NODE}.example.com" "echo \"${SSH_PASSWORD_VALUE}\" | sudo -S systemctl stop k3s" || echo "K3s arrete"

echo "Attente 10 secondes..."
sleep 10

# Etat pendant panne
echo ""
echo "=== ETAT PENDANT PANNE (t+10s) ==="
echo "Nodes:"
kubectl get nodes -o wide 2>/dev/null || echo "API Server inaccessible"
echo ""

echo "Pods Drupal (quel nud?):"
kubectl get pods -n drupal -l app=drupal -o wide 2>/dev/null || echo "API inaccessible"
echo ""

echo "Pods MySQL:"
kubectl get pods -n drupal -l app=mysql -o wide 2>/dev/null || echo "API inaccessible"
echo ""

# Tester service
echo "Test service Drupal:"
for i in 13 14 15; do
    if [ "k8s$i" != "$NODE" ]; then
        echo -n "  k8s$i: "
        curl -s -o /dev/null -w "%{http_code}" http://k8s$i.example.com:30080 || echo "FAILED"
    fi
done
echo ""

echo "Attente 50 secondes (reschedule)..."
sleep 50

# Etat apres reschedule
echo ""
echo "=== ETAT APRES RESCHEDULE (t+60s) ==="
echo "Nodes:"
kubectl get nodes -o wide 2>/dev/null || echo "API inaccessible"
echo ""

echo "Pods Drupal:"
kubectl get pods -n drupal -l app=drupal -o wide 2>/dev/null || echo "API inaccessible"
echo ""

echo "Pods MySQL:"
kubectl get pods -n drupal -l app=mysql -o wide 2>/dev/null || echo "API inaccessible"
echo ""

echo "Service accessible:"
for i in 13 14 15; do
    if [ "k8s$i" != "$NODE" ]; then
        echo -n "  k8s$i: "
        curl -s -o /dev/null -w "%{http_code}" http://k8s$i.example.com:30080 || echo "FAILED"
    fi
done
echo ""

# Restauration
read -p "Restaurer $NODE ? (yes/no): " restore
if [ "$restore" = "yes" ]; then
    echo ""
    echo "=== RESTAURATION $NODE ==="
    ssh "${SSH_USER}@${NODE}.example.com" "echo \"${SSH_PASSWORD_VALUE}\" | sudo -S systemctl start k3s"

    echo "Attente 30 secondes..."
    sleep 30

    echo "Nodes:"
    kubectl get nodes -o wide
    echo ""
    echo " $NODE restaure"
fi

echo ""
echo ""
echo "   TEST TERMINE"
echo ""
