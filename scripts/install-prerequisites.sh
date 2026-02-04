#!/bin/bash
# Installation automatique de tous les prerequis sur k8s-orchestrator
# Aucune interaction humaine requise

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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
if [ -z "$SUDO_PASSWORD" ]; then
    echo " SUDO_PASSWORD non defini (export SUDO_PASSWORD=... ou renseigner .env.tmp)."
    exit 1
fi

echo ""
echo "   INSTALLATION AUTOMATIQUE PREREQUIS                   "
echo ""
echo ""

# Verifier si root/sudo
if [ "$EUID" -eq 0 ]; then
    SUDO_MODE="NOPASS"
else
    if sudo -n true 2>/dev/null; then
        SUDO_MODE="NOPASS"
    else
        SUDO_MODE="PASSWORD"
    fi
fi

run_sudo() {
    if [ "$EUID" -eq 0 ]; then
        "$@"
    elif [ "$SUDO_MODE" = "NOPASS" ]; then
        sudo "$@"
    else
        printf '%s\n' "$SUDO_PASSWORD" | sudo -S "$@"
    fi
}

# Fonction pour verifier si commande existe
command_exists() {
    command -v "$1" &> /dev/null
}

# 1. Mettre a jour les packages
echo "[1/7] Mise a jour du systeme..."
run_sudo apt-get update -qq

# 2. Installer Ansible
if command_exists ansible; then
    echo "[2/7] Ansible deja installe: $(ansible --version | head -1)"
else
    echo "[2/7] Installation Ansible..."
    run_sudo apt-get install -y -qq ansible sshpass < /dev/null
    echo "   Ansible $(ansible --version | head -1 | cut -d' ' -f2)"
fi

# 3. Installer modules Python Kubernetes (via apt, pas pip)
echo "[3/7] Installation modules Python Kubernetes..."
if python3 -c "import kubernetes" 2>/dev/null; then
    echo "   Modules deja installes"
else
    # Utiliser les packages systeme au lieu de pip
    run_sudo apt-get install -y -qq python3-kubernetes python3-openshift python3-yaml < /dev/null
    echo "   Modules Python installes (via apt)"
fi

# 4. Installer Helm
if command_exists helm; then
    echo "[4/7] Helm deja installe: $(helm version --short)"
else
    echo "[4/7] Installation Helm..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash > /dev/null 2>&1
    echo "   Helm $(helm version --short)"
fi

# 5. Installer kubectl
if command_exists kubectl; then
    echo "[5/7] kubectl deja installe: $(kubectl version --client -o yaml 2>/dev/null | grep gitVersion | head -1 | cut -d':' -f2 | tr -d ' ')"
else
    echo "[5/7] Installation kubectl..."
    KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" > /dev/null 2>&1
    run_sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
    echo "   kubectl $KUBECTL_VERSION"
fi

# 6. Installer jq (pour parsing JSON dans scripts)
if command_exists jq; then
    echo "[6/7] jq deja installe"
else
    echo "[6/7] Installation jq..."
    run_sudo apt-get install -y -qq jq < /dev/null
    echo "   jq installe"
fi

# 7. Installer outils systeme
echo "[7/7] Installation outils systeme..."
run_sudo apt-get install -y -qq git curl wget rsync tar gzip openssl < /dev/null
echo "   Outils systeme installes"

echo ""
echo ""
echo "   PREREQUIS INSTALLES AVEC SUCCES                      "
echo ""
echo ""
echo "Resume:"
echo "   Ansible:    $(ansible --version | head -1 | cut -d' ' -f2)"
echo "   Helm:       $(helm version --short 2>/dev/null | cut -d'+' -f1)"
echo "   kubectl:    $(kubectl version --client -o yaml 2>/dev/null | grep gitVersion | head -1 | cut -d':' -f2 | tr -d ' ')"
echo "   Python:     $(python3 --version)"
echo "   Modules K8s: python3-kubernetes, python3-openshift, python3-yaml"
echo ""
