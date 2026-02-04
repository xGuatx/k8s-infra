#!/bin/bash

echo ""
echo "    Demarrage Presentation Infrastructure K3s HA"
echo ""
echo ""

# Verifier si Docker est installe
if ! command -v docker &> /dev/null; then
    echo " Docker n'est pas installe"
    echo ""
    echo "Installation Docker:"
    echo "  curl -fsSL https://get.docker.com | sh"
    echo "  sudo usermod -aG docker \$USER"
    echo "  newgrp docker"
    exit 1
fi

# Verifier si docker-compose est installe
if ! command -v docker compose &> /dev/null; then
    echo " docker-compose n'est pas installe"
    echo ""
    echo "Installation docker-compose:"
    echo "  sudo curl -L \"https://github.com/docker/compose/releases/latest/download/docker-compose-\$(uname -s)-\$(uname -m)\" -o /usr/local/bin/docker-compose"
    echo "  sudo chmod +x /usr/local/bin/docker-compose"
    exit 1
fi

echo " Docker et docker-compose sont installes"
echo ""

# Arreter les containers existants
echo " Arret des containers existants..."
docker compose down 2>/dev/null

# Build et demarrage
echo "  Build de l'image Docker..."
docker compose build

echo ""
echo " Demarrage du container..."
docker compose up -d

echo ""
echo ""
echo "    Application demarree avec succes!"
echo ""
echo ""
echo " Acces a la presentation:"
echo "   http://localhost:8080"
echo ""
echo " Commandes utiles:"
echo "   docker-compose logs -f       # Voir les logs"
echo "   docker-compose down          # Arreter"
echo "   docker-compose restart       # Redemarrer"
echo ""
echo " Attente demarrage (5 secondes)..."
sleep 5

# Verifier que le container tourne
if docker ps | grep -q k8s-infrastructure-presentation; then
    echo " Container actif"
    echo ""
    echo " Ouvrez votre navigateur sur: http://localhost:8080"
else
    echo " Erreur de demarrage"
    echo ""
    echo "Logs:"
    docker compose logs
fi
