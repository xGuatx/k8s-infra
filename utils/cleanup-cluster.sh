#!/bin/bash
# Script de nettoyage complet du cluster K3s
# Usage: ./cleanup-cluster.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASSWORD="${SSH_PASSWORD:?SSH_PASSWORD environment variable required}"

echo ""
echo "        NETTOYAGE COMPLET CLUSTER K3S                           "
echo ""
echo ""
echo "  ATTENTION: Cette operation va:"
echo "  - Desinstaller K3s sur k8s-master-1, k8s-master-2, k8s-master-3"
echo "  - Supprimer toutes les donnees du cluster"
echo "  - Nettoyer les fichiers temporaires sur k8s-orchestrator"
echo ""
read -p "Voulez-vous continuer? (oui/non): " confirm

if [ "$confirm" != "oui" ]; then
    echo " Operation annulee"
    exit 0
fi

echo ""
echo "=== Etape 1/4: Desinstallation K3s sur k8s-master-1-15 ==="
for i in 13 14 15; do
    echo -n "  Nettoyage k8s$i... "
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no \
        formation@k8s$i.example.com \
        "echo '$PASSWORD' | sudo -S /usr/local/bin/k3s-uninstall.sh 2>&1" > /tmp/cleanup-k8s$i.log

    if [ $? -eq 0 ]; then
        echo " OK"
    else
        echo "  Erreur (voir /tmp/cleanup-k8s$i.log)"
    fi
done

echo ""
echo "=== Etape 2/4: Verification de la desinstallation ==="
for i in 13 14 15; do
    echo -n "  Verification k8s$i... "
    status=$(sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no \
        formation@k8s$i.example.com \
        "systemctl is-active k3s 2>/dev/null || echo 'not-installed'")

    if [ "$status" == "not-installed" ] || [ "$status" == "inactive" ]; then
        echo " K3s desinstalle"
    else
        echo "  K3s toujours actif ($status)"
    fi
done

echo ""
echo "=== Etape 3/4: Nettoyage des fichiers sur k8s-orchestrator ==="
sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no \
    formation@k8s-orchestrator.example.com \
    "rm -rf /tmp/k8s-infra /tmp/deploy*.log /tmp/kubeconfig-k3s.yaml /tmp/quick-check.sh /tmp/cleanup-*.log" 2>&1

echo "   Fichiers temporaires supprimes sur k8s-orchestrator"

echo ""
echo "=== Etape 4/4: Suppression NOPASSWD sudo (optionnel) ==="
read -p "Supprimer la configuration NOPASSWD sudo? (oui/non): " remove_sudo

if [ "$remove_sudo" == "oui" ]; then
    for i in 13 14 15; do
        echo -n "  Nettoyage sudo k8s$i... "
        sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no \
            formation@k8s$i.example.com \
            "echo '$PASSWORD' | sudo -S rm -f /etc/sudoers.d/formation" 2>&1
        echo " OK"
    done
else
    echo "    Configuration sudo conservee"
fi

echo ""
echo ""
echo "        NETTOYAGE TERMINE AVEC SUCCES                           "
echo ""
echo ""
echo "Prochaines etapes:"
echo "  1. Uploader l'archive: ./utils/upload-archive.sh"
echo "  2. Deployer: ./utils/deploy-cluster.sh"
echo ""
