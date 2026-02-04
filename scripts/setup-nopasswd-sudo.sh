#!/bin/bash
# Configure NOPASSWD sudo for formation user on k8s-master-1-15
# Required for Ansible become operations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Charger les variables depuis .env.tmp
ENV_FILE_SUDO_PASSWORD=""
ENV_FILE_SSH_PASSWORD=""
ENV_FILE="$REPO_ROOT/.env.tmp"
if [ -f "$ENV_FILE" ]; then
    while IFS='=' read -r key value; do
        case "$key" in
            SUDO_PASSWORD) ENV_FILE_SUDO_PASSWORD="$value" ;;
            SSH_PASSWORD|PWD) ENV_FILE_SSH_PASSWORD="$value" ;;
        esac
    done < "$ENV_FILE"
fi

SUDO_PASSWORD="${SUDO_PASSWORD:-${ENV_FILE_SUDO_PASSWORD:-}}"
SSH_PASSWORD="${SSH_PASSWORD:-${ENV_FILE_SSH_PASSWORD:-}}"

if [ -z "$SUDO_PASSWORD" ]; then
    echo " SUDO_PASSWORD non defini (export SUDO_PASSWORD=... ou renseigner .env.tmp)."
    exit 1
fi

echo ""
echo "   CONFIGURATION NOPASSWD SUDO (k8s-master-1-15)              "
echo ""
echo ""

for node in k8s-master-1 k8s-master-2 k8s-master-3; do
    echo -n "Configuring NOPASSWD sudo on $node.example.com: "

    if sshpass -p "$SSH_PASSWORD" ssh -o StrictHostKeyChecking=no formation@${node}.example.com \
        "echo '$SUDO_PASSWORD' | sudo -S bash -c 'echo \"formation ALL=(ALL) NOPASSWD:ALL\" > /etc/sudoers.d/formation && chmod 440 /etc/sudoers.d/formation'" &>/dev/null; then
        echo ""
    else
        echo " ECHEC"
        exit 1
    fi
done

echo ""
echo ""
echo "   NOPASSWD SUDO CONFIGURE AVEC SUCCES                  "
echo ""
echo ""
echo " formation user peut utiliser sudo sans mot de passe sur k8s-master-1-15"
echo " Ansible pourra executer les commandes privilegiees"
echo ""
