#!/bin/bash
# Script pour configurer les cles SSH depuis k8s-orchestrator vers k8s-master-1-15
# Evite d'avoir des mots de passe en clair dans l'inventory

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ENV_FILE_SSH_PASSWORD=""
ENV_FILE_SSH_USER=""
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
SSH_PASSWORD="${SSH_PASSWORD:-${ENV_FILE_SSH_PASSWORD:-}}"
if [ -z "$SSH_PASSWORD" ]; then
    echo " SSH_PASSWORD non defini (export SSH_PASSWORD=... ou renseigner .env.tmp)."
    exit 1
fi

echo ""
echo "   CONFIGURATION CLES SSH (SECURITE)                    "
echo ""
echo ""

# Password from environment or prompt
SSH_PASSWORD="${SSH_PASSWORD:-}"
if [ -z "$SSH_PASSWORD" ]; then
    echo "  Mot de passe SSH requis pour configuration initiale"
    read -s -p "Mot de passe SSH (formation): " SSH_PASSWORD
    echo ""
fi

# Generer cle SSH si elle n'existe pas
if [ ! -f ~/.ssh/id_rsa ]; then
    echo "[1/3] Generation cle SSH RSA 4096..."
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N '' -C 'k8s-orchestration'
    echo "   Cle SSH generee: ~/.ssh/id_rsa"
else
    echo "[1/3] Cle SSH existe deja: ~/.ssh/id_rsa"
fi

# Copier cle publique vers tous les nuds
echo ""
echo "[2/3] Copie cle publique vers k8s-master-1-15..."
for node in k8s-master-1 k8s-master-2 k8s-master-3; do
    echo -n "  - $node.example.com: "
    if sshpass -p "$SSH_PASSWORD" ssh-copy-id -o StrictHostKeyChecking=no \
        -i ~/.ssh/id_rsa.pub "${SSH_USER}@${node}.example.com" &>/dev/null; then
        echo ""
    else
        echo " ECHEC"
        exit 1
    fi
done

# Test connexion sans mot de passe
echo ""
echo "[3/3] Test connexion SSH sans mot de passe..."
for node in k8s-master-1 k8s-master-2 k8s-master-3; do
    echo -n "  - $node.example.com: "
    if ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no \
        "${SSH_USER}@${node}.example.com" "hostname" &>/dev/null; then
        echo ""
    else
        echo " ECHEC (connexion par cle impossible)"
        exit 1
    fi
done

echo ""
echo ""
echo "   CLES SSH CONFIGUREES AVEC SUCCES                     "
echo ""
echo ""
echo " Authentification par cle SSH active sur k8s-master-1-15"
echo " Plus besoin de mots de passe en clair dans l'inventory"
echo ""
