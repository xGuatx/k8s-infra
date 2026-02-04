# Infrastructure K3s HA - Presentation Technique

Application web React presentant l'infrastructure Kubernetes haute disponibilite deployee.

##  Demarrage Rapide

### Option 1: Docker (Recommande)

```bash
# Build et demarrage
docker-compose up --build -d

# Acces
http://localhost:8080

# Arret
docker-compose down
```

### Option 2: Developpement Local

```bash
# Installation dependances
npm install

# Demarrage serveur dev
npm run dev

# Build production
npm run build

# Preview build
npm run preview
```

##  Structure

```
k8s-presentation/
 src/
    components/        # Composants React
    data/             # Donnees infrastructure
       infrastructure.js
    assets/           # Images, icons
    App.jsx           # Composant principal
    main.jsx          # Entry point
    index.css         # Styles globaux
 public/               # Assets statiques
 Dockerfile            # Image production
 docker-compose.yml    # Orchestration
 nginx.conf            # Config nginx
 vite.config.js        # Config Vite
 package.json          # Dependances

```

##  Sections

1. **Vue d'ensemble** - Metriques cluster, objectifs, stack technique
2. **Architecture** - Diagrammes, flux deploiement, acces services
3. **Composants** - Detail de chaque outil avec justifications
4. **Haute Disponibilite** - Strategie HA, tests resilience
5. **Disaster Recovery** - Backups, scenarios restauration, RTO/RPO
6. **Choix Techniques** - Justification vs alternatives, trade-offs
7. **Defis & Solutions** - Retour d'experience, problemes resolus

##  Technologies

- **Frontend**: React 18 + Vite
- **Diagrammes**: Mermaid.js
- **Icons**: Lucide React
- **Containerisation**: Docker + Nginx Alpine
- **Port**: 8080

##  Contenu

-  12 composants detailles avec alternatives
-  6 defis techniques documentes avec solutions
-  8 choix architecturaux justifies
-  6 strategies HA + tests resilience
-  5 types backups + 4 scenarios DR
-  Diagrammes architecture interactifs

##  Utilisation

Application destinee a presenter l'infrastructure K3s HA lors de demonstrations,
formations ou audits techniques. Toutes les decisions architecturales sont documentees
avec justifications, alternatives evaluees et trade-offs.

##  Notes

- Tous les secrets ont ete retires des donnees
- Aucune connexion reseau requise (donnees statiques)
- Responsive design (desktop + mobile)
- Performance optimisee (build < 500KB)

##  Mise a Jour

Pour mettre a jour les donnees :

1. Modifier `src/data/infrastructure.js`
2. Rebuild: `docker-compose up --build -d`

##  Support

Pour toute question sur l'infrastructure presentee, consulter :
- `/home/guat/DISASTER_RECOVERY.md`
- `/home/guat/k8s-infra/INDEX.md`
- `/home/guat/k8s-infra/GUIDE_DEBUG_MANUEL.md`
