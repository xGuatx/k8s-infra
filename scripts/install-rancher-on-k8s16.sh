#!/bin/bash
# Installation de Rancher sur k8s-orchestrator (machine cliente)
# 100% IDEMPOTENT - Peut etre execute plusieurs fois sans probleme
# N'installe que si Rancher n'est pas deja present

set -euo pipefail

echo ""
echo "   INSTALLATION RANCHER SUR K8S16 (Idempotent)         "
echo ""
echo ""

RANCHER_VERSION="${RANCHER_VERSION:-v2.8.0}"
RANCHER_HOSTNAME="${RANCHER_HOSTNAME:-k8s-orchestrator.example.com}"
RANCHER_PASSWORD="${RANCHER_PASSWORD:-}"  # Must be provided via environment or vault
USE_LETSENCRYPT="${USE_LETSENCRYPT:-true}"
USE_STAGING="${USE_STAGING:-true}"

if [ -z "$RANCHER_PASSWORD" ]; then
    echo "  RANCHER_PASSWORD not set!"
    echo "   Please export RANCHER_PASSWORD before running this script"
    echo "   Or get it from vault: ansible-vault view inventory/group_vars/vault.yml"
    exit 1
fi

# Verifier si Docker est deja installe
if command -v docker &> /dev/null; then
    echo "[1/5] Docker deja installe: $(docker --version)"
else
    echo "[1/5] Installation Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
    echo "   Docker installe"
fi

# Verifier si Rancher container existe deja
if sudo docker ps -a | grep -q rancher-server; then
    echo "[2/5] Rancher container existe deja"

    # Verifier si le container est running
    if sudo docker ps | grep -q rancher-server; then
        echo "   Rancher est en cours d'execution"
    else
        echo "   Rancher container existe mais n'est pas running, demarrage..."
        sudo docker start rancher-server
        echo "   Rancher redemarre"
    fi
else
    echo "[2/5] Installation Rancher container..."

    # Creer repertoire pour persistance
    sudo mkdir -p /opt/rancher

    # Construire les options Let's Encrypt
    LETSENCRYPT_OPTS=""
    if [ "$USE_LETSENCRYPT" = "true" ]; then
        LETSENCRYPT_OPTS="-e CATTLE_BOOTSTRAP_PASSWORD=${RANCHER_PASSWORD}"
        if [ "$USE_STAGING" = "true" ]; then
            LETSENCRYPT_OPTS="${LETSENCRYPT_OPTS} -e LETSENCRYPT_ENVIRONMENT=staging"
        else
            LETSENCRYPT_OPTS="${LETSENCRYPT_OPTS} -e LETSENCRYPT_ENVIRONMENT=production"
        fi
        LETSENCRYPT_OPTS="${LETSENCRYPT_OPTS} -e LETSENCRYPT_EMAIL=admin@example.com"
    fi

    # Lancer Rancher
    sudo docker run -d \
      --name rancher-server \
      --restart=unless-stopped \
      -p 80:80 -p 443:443 \
      -v /opt/rancher:/var/lib/rancher \
      ${LETSENCRYPT_OPTS} \
      --privileged \
      rancher/rancher:${RANCHER_VERSION}

    echo "   Rancher container cree et demarre"
fi

echo "[3/5] Attente demarrage Rancher (peut prendre 2-3 minutes)..."
RETRIES=60
COUNT=0
while [ $COUNT -lt $RETRIES ]; do
    if curl -k -s https://localhost/ping > /dev/null 2>&1; then
        echo "   Rancher est pret!"
        break
    fi
    COUNT=$((COUNT + 1))
    sleep 5
    echo -n "."
done

if [ $COUNT -eq $RETRIES ]; then
    echo ""
    echo "   Timeout en attendant Rancher"
    echo "  Verifier manuellement: sudo docker logs rancher-server"
    exit 1
fi

echo ""
echo "[4/5] Configuration Rancher..."

# Verifier si le mot de passe admin a deja ete configure
ADMIN_CONFIGURED=$(curl -k -s https://localhost/v3/users?me=true 2>/dev/null | grep -c "adminPassword" || echo "0")

if [ "$ADMIN_CONFIGURED" -gt 0 ]; then
    echo "   Rancher deja configure (admin password deja set)"
else
    echo "  Configuration du mot de passe admin..."

    # Attendre que l'API soit completement prete
    sleep 30

    # Recuperer le bootstrap password
    BOOTSTRAP_PASSWORD=$(sudo docker logs rancher-server 2>&1 | grep "Bootstrap Password:" | awk '{print $NF}' | tail -1)

    if [ -z "$BOOTSTRAP_PASSWORD" ]; then
        echo "   Impossible de recuperer le bootstrap password"
        echo "  Verifier manuellement: sudo docker logs rancher-server | grep Bootstrap"
    else
        echo "   Bootstrap password recupere"

        # Configuration du mot de passe admin (a faire manuellement via l'UI)
        echo "   Configuration manuelle requise:"
        echo "    1. Acceder a https://${RANCHER_HOSTNAME}"
        echo "    2. Bootstrap Password: $BOOTSTRAP_PASSWORD"
        echo "    3. Configurer nouveau mot de passe: $RANCHER_PASSWORD"
    fi
fi

echo "[5/5] Verification firewall..."
# Verifier si les ports sont ouverts (si ufw est utilise)
if command -v ufw &> /dev/null && sudo ufw status | grep -q "Status: active"; then
    if sudo ufw status | grep -q "80/tcp.*ALLOW"; then
        echo "   Port 80 deja ouvert"
    else
        echo "  Ouverture port 80..."
        sudo ufw allow 80/tcp
    fi

    if sudo ufw status | grep -q "443/tcp.*ALLOW"; then
        echo "   Port 443 deja ouvert"
    else
        echo "  Ouverture port 443..."
        sudo ufw allow 443/tcp
    fi
else
    echo "   Firewall non actif ou ports deja accessibles"
fi

# Sauvegarder les credentials
cat > /tmp/rancher-credentials.txt <<EOF

              RANCHER CREDENTIALS                       


URL: https://${RANCHER_HOSTNAME}

Bootstrap Password: ${BOOTSTRAP_PASSWORD:-"Voir: sudo docker logs rancher-server | grep Bootstrap"}

Mot de passe recommande: ${RANCHER_PASSWORD}

Container Docker: rancher-server
Data Directory: /opt/rancher

Commandes utiles:
  sudo docker ps | grep rancher
  sudo docker logs rancher-server
  sudo docker restart rancher-server
  sudo docker stop rancher-server


EOF

echo ""
echo ""
echo "          RANCHER INSTALLATION TERMINEE                 "
echo ""
echo ""
echo "URL: https://${RANCHER_HOSTNAME}"
echo "Credentials: /tmp/rancher-credentials.txt"
echo ""
echo "Verification:"
echo "  sudo docker ps | grep rancher-server"
echo "  curl -k https://localhost/ping"
echo ""
echo "  IMPORTANT:"
echo "  - Ce script est IDEMPOTENT - peut etre execute plusieurs fois"
echo "  - Rancher persiste dans /opt/rancher"
echo "  - Le container se redemarre automatiquement (restart=unless-stopped)"
echo "  - En cas de redeploiement, Rancher conserve sa configuration"
echo ""
echo "Prochaine etape:"
echo "  1. Acceder a https://${RANCHER_HOSTNAME}"
echo "  2. Configurer le mot de passe admin"
echo "  3. Importer le cluster K3s (voir RANCHER.md)"
echo ""

cat /tmp/rancher-credentials.txt
