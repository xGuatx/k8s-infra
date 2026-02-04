#  Demarrage Rapide - Presentation K8s Infrastructure

## Prerequis

- Docker installe et fonctionnel
- docker-compose installe
- Port 8080 disponible

## Installation Docker (si necessaire)

```bash
# Installation Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker

# Installation docker-compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verification
docker --version
docker-compose --version
```

## Demarrage de la Presentation

### Methode 1: Script Automatique (Recommande)

```bash
cd /home/guat/k8s-presentation
./start.sh
```

Le script va:
1.  Verifier Docker et docker-compose
2.  Arreter les containers existants
3.  Builder l'image Docker
4.  Demarrer le container
5.  Afficher l'URL d'acces

### Methode 2: Commandes Manuel

```bash
cd /home/guat/k8s-presentation

# Build et demarrage
docker-compose up --build -d

# Verifier le statut
docker-compose ps

# Voir les logs
docker-compose logs -f
```

## Acces

Une fois demarre, ouvrez votre navigateur sur:

```
http://localhost:8080
```

## Arret

```bash
cd /home/guat/k8s-presentation
./stop.sh
```

Ou manuellement:

```bash
docker-compose down
```

## Resolution de Problemes

### Port 8080 deja utilise

```bash
# Voir ce qui utilise le port
sudo lsof -i :8080

# Changer le port dans docker-compose.yml
# Remplacer "8080:8080" par "8081:8080" par exemple
```

### Container ne demarre pas

```bash
# Voir les logs d'erreur
docker-compose logs

# Rebuild complet
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

### Problemes de permissions Docker

```bash
# Ajouter votre utilisateur au groupe docker
sudo usermod -aG docker $USER

# Se reconnecter ou:
newgrp docker
```

## Developpement Local (sans Docker)

Si vous souhaitez modifier la presentation:

```bash
cd /home/guat/k8s-presentation

# Installer les dependances
npm install

# Demarrer en mode dev (hot reload)
npm run dev

# Acces sur http://localhost:8080
```

## Contenu de la Presentation

La presentation contient 7 sections:

1. ** Vue d'ensemble** - Metriques, objectifs, stack
2. ** Architecture** - Diagrammes Mermaid, flux deploiement
3. ** Composants** - 12 composants detailles avec alternatives
4. ** Haute Disponibilite** - Strategie HA, tests resilience
5. ** Disaster Recovery** - Backups, restauration, RTO/RPO
6. ** Choix Techniques** - 8 decisions justifiees
7. ** Defis & Solutions** - 6 problemes resolus

## Personnalisation

Pour mettre a jour les donnees:

1. Modifier `/home/guat/k8s-presentation/src/data/infrastructure.js`
2. Rebuild: `docker-compose up --build -d`

## Notes Importantes

-  **Toutes les donnees sont a jour** (verifiees depuis les charts Helm)
-  **PVC: 2Gi** (MySQL 32Gi + Drupal 32Gi = 12GB total)
-  **Resources: 512Mi RAM request, 1Gi limit par pod**
-  **Replicas: 3 pour MySQL et Drupal (HA reel)**
-  **Images officielles** utilisees partout

## Support

Pour questions sur l'infrastructure elle-meme:
- `/home/guat/DISASTER_RECOVERY.md`
- `/home/guat/k8s-infra/INDEX.md`
- `/home/guat/k8s-infra/GUIDE_DEBUG_MANUEL.md`
