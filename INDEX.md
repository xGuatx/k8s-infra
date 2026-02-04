# Index Complet - Infrastructure K3s

##  Point de Depart Rapide

**Vous cherchez quoi?**

| Besoin | Fichier a consulter |
|--------|---------------------|
|  **Demarrer rapidement** | [`/home/guat/REPRISE_MANUELLE.md`](../REPRISE_MANUELLE.md) |
|  **Guide complet** | [`GUIDE_DEBUG_MANUEL.md`](GUIDE_DEBUG_MANUEL.md) |
|  **Utiliser les scripts** | [`utils/README.md`](utils/README.md) |
|  **Voir les corrections** | [`RESUME_CORRECTIONS.md`](RESUME_CORRECTIONS.md) |

---

##  Structure du Projet

```
/home/guat/
 REPRISE_MANUELLE.md            POINT D'ENTREE RAPIDE

 k8s-infra/
     INDEX.md                   CE FICHIER
     GUIDE_DEBUG_MANUEL.md      Guide complet (10 sections)
     RESUME_CORRECTIONS.md      Toutes les corrections
    
     deploy.sh                  Script de deploiement principal
    
     utils/                     SCRIPTS UTILITAIRES
        README.md              Documentation des scripts
        cleanup-cluster.sh      Supprime le cluster
        upload-archive.sh      Upload sur k8s-orchestrator
        deploy-cluster.sh      Lance le deploiement
        watch-deploy.sh        Surveillance temps reel
        check-deploy.sh        Verification rapide
        check-cluster.sh       Verification complete
        quick-check.sh         Check ultra-rapide
        pod-logs.sh            Logs d'un pod
        pod-debug.sh           Debug d'un pod
    
     ansible/
        playbooks/
           00-bootstrap-k3s.yml          MODIFIE (fix systemd)
           01-deploy-infrastructure.yml
           02-configure-velero-backups.yml
           03-configure-security.yml
           04-configure-ingress.yml
           05-configure-monitoring-dashboards.yml
        inventory/
            hosts.yml
            group_vars/
    
     helm/
         charts/
             drupal-stack/
                 values.yaml
                 templates/
                     mysql-statefulset.yaml    MODIFIE (fix hostname + xtrabackup)
```

---

##  Workflows Principaux

### Workflow 1: Premier Deploiement

```bash
cd /home/guat/k8s-infra

# 1. Upload
./utils/upload-archive.sh

# 2. Deployer
./utils/deploy-cluster.sh

# 3. Surveiller
./utils/watch-deploy.sh

# 4. Verifier (une fois termine)
./utils/check-cluster.sh
```

**Duree totale**: ~40-45 minutes

### Workflow 2: Redeploiement Complet

```bash
cd /home/guat/k8s-infra

# 1. Nettoyer
./utils/cleanup-cluster.sh

# 2-4. Comme Workflow 1
./utils/upload-archive.sh
./utils/deploy-cluster.sh
./utils/watch-deploy.sh
```

### Workflow 3: Debogage MySQL

```bash
cd /home/guat/k8s-infra

# 1. Etat general
./utils/check-cluster.sh

# 2. Debug du pod
./utils/pod-debug.sh drupal mysql-0

# 3. Logs detailles
./utils/pod-logs.sh drupal mysql-0 init-mysql
```

---

##  Documentation Detaillee

### 1. REPRISE_MANUELLE.md (Point d'entree)
**Chemin**: `/home/guat/REPRISE_MANUELLE.md`

**Contenu**:
- Etat actuel du deploiement
- Commandes rapides pour reprendre
- Actions selon succes/echec
- Temps estimes

**Quand utiliser**: Vous revenez apres une pause

### 2. GUIDE_DEBUG_MANUEL.md (Guide complet)
**Chemin**: `/home/guat/k8s-infra/GUIDE_DEBUG_MANUEL.md`

**Contenu** (10 sections):
1. Vue d'ensemble
2. Prerequis et environnement
3. Corrections appliquees
4. Procedures de base
5. Deploiement complet
6. Debogage des problemes courants
7. Tests et verifications
8. Backup et restore
9. Nettoyage
10. Commandes utiles

**Quand utiliser**: Vous avez un probleme technique

### 3. RESUME_CORRECTIONS.md (Reference technique)
**Chemin**: `/home/guat/k8s-infra/RESUME_CORRECTIONS.md`

**Contenu**:
- Tous les fichiers modifies
- Lignes exactes des modifications
- Tests de validation
- Workflow de mise a jour

**Quand utiliser**: Vous devez comprendre les modifications

### 4. utils/README.md (Guide des scripts)
**Chemin**: `/home/guat/k8s-infra/utils/README.md`

**Contenu**:
- Liste de tous les scripts
- Workflows avec scripts
- Exemples detailles
- Depannage

**Quand utiliser**: Vous voulez utiliser les scripts automatises

---

##  Scripts Utilitaires - Resume

### Gestion (3 scripts)

```bash
./utils/cleanup-cluster.sh    # Supprime K3s sur k8s-master-1-15
./utils/upload-archive.sh     # Upload archive  k8s-orchestrator
./utils/deploy-cluster.sh     # Lance deploiement complet
```

### Surveillance (3 scripts)

```bash
./utils/watch-deploy.sh       # Temps reel (tail -f)
./utils/check-deploy.sh       # Verification rapide
./utils/check-cluster.sh      # Verification complete
```

### Debogage (3 scripts)

```bash
./utils/quick-check.sh        # Check ultra-rapide
./utils/pod-logs.sh <ns> <pod>  # Logs d'un pod
./utils/pod-debug.sh <ns> <pod> # Debug complet
```

---

##  Corrections Appliquees

### Fix 1: Systemd K3s
**Fichier**: `ansible/playbooks/00-bootstrap-k3s.yml`
**Lignes**: 51-55, 124-128
**Probleme**: K3s pas demarre apres installation
**Solution**: Ajout task systemd pour demarrer K3s

### Fix 2: Hostname MySQL
**Fichier**: `helm/charts/drupal-stack/templates/mysql-statefulset.yaml`
**Lignes**: 40, 63
**Probleme**: Commande `hostname` indisponible
**Solution**: Utiliser `$HOSTNAME` au lieu de `$(hostname)`

### Fix 3: Image Xtrabackup
**Fichier**: `helm/charts/drupal-stack/templates/mysql-statefulset.yaml`
**Lignes**: 56, 122
**Probleme**: Image GCR indisponible
**Solution**: Changer pour `perconalab/percona-xtrabackup:8.0`

**Details complets**: Voir [`RESUME_CORRECTIONS.md`](RESUME_CORRECTIONS.md)

---

##  Etat Actuel (2025-10-17)

### Deploiement en Cours

**Status**:  Phase 4/10 - Infrastructure

**Progression**:
-  Phase 0-3: Terminees
-  Phase 4: En cours (Longhorn, Cert-Manager, Drupal)
-  Phase 5-10: En attente

**Log actif**: `/tmp/deploy-final-fixed.log` sur k8s-orchestrator

**Monitoring**: Shell d6c9b2 (verifications /30s)

**Commande de suivi**:
```bash
./utils/check-deploy.sh /tmp/deploy-final-fixed.log
```

---

##  Problemes Courants

### Probleme 1: Script ne s'execute pas

**Symptome**: `Permission denied`

**Solution**:
```bash
chmod +x /home/guat/k8s-infra/utils/*.sh
```

### Probleme 2: MySQL CrashLoopBackOff

**Diagnostic**:
```bash
./utils/pod-debug.sh drupal mysql-0
./utils/pod-logs.sh drupal mysql-0 init-mysql
```

**Solutions possibles**:
- Verifier fix hostname (`$HOSTNAME`)
- Verifier fix xtrabackup (`perconalab/percona-xtrabackup:8.0`)
- Verifier secret MySQL (cles correctes)

**Guide complet**: Section 6 de `GUIDE_DEBUG_MANUEL.md`

### Probleme 3: Le deploiement ne progresse plus

**Verifier**:
```bash
# Dernieres lignes du log
./utils/check-deploy.sh /tmp/deploy-final-fixed.log 100

# Rechercher "fatal" ou "FAILED"
sshpass -p '<YOUR_SSH_PASSWORD>' ssh formation@k8s-orchestrator.example.com \
  "grep -i 'fatal\\|failed' /tmp/deploy-final-fixed.log | tail -10"
```

---

##  Ressources Externes

- **K3s Documentation**: https://docs.k3s.io/
- **Longhorn**: https://longhorn.io/docs/
- **Helm**: https://helm.sh/docs/
- **Velero**: https://velero.io/docs/
- **Cert-Manager**: https://cert-manager.io/docs/

---

##  Commandes Essentielles

### Se connecter a k8s-orchestrator

```bash
sshpass -p '<YOUR_SSH_PASSWORD>' ssh -o StrictHostKeyChecking=no \
  formation@k8s-orchestrator.example.com
```

### Kubectl depuis local

```bash
# Exporter kubeconfig
export KUBECONFIG=/tmp/kubeconfig-k3s.yaml

# Utiliser
kubectl get nodes
kubectl get pods -A
```

### Verification Rapide K3s

```bash
for i in 13 14 15; do
  echo "k8s$i:"
  sshpass -p '<YOUR_SSH_PASSWORD>' ssh -o StrictHostKeyChecking=no \
    formation@k8s$i.example.com "systemctl is-active k3s"
done
```

---

##  Checklist de Validation

### Apres Deploiement

- [ ] Tous les nuds K3s sont "Ready"
- [ ] Aucun pod en erreur (CrashLoop, Error, etc.)
- [ ] Tous les PVC sont "Bound"
- [ ] MySQL-0, MySQL-1, MySQL-2 sont "Running 2/2"
- [ ] Drupal pods sont "Running 1/1"
- [ ] Grafana accessible
- [ ] Test connexion MySQL reussi
- [ ] Premier backup Velero cree

### Commande Globale

```bash
./utils/check-cluster.sh
```

---

##  Sauvegarde

### Creer une Archive Complete

```bash
cd /home/guat
tar czf k8s-infra-v2-$(date +%Y%m%d).tar.gz \
  k8s-infra/ \
  REPRISE_MANUELLE.md
```

### Fichiers Critiques a Sauvegarder

```
/home/guat/k8s-infra/
 ansible/playbooks/00-bootstrap-k3s.yml
 helm/charts/drupal-stack/templates/mysql-statefulset.yaml
 GUIDE_DEBUG_MANUEL.md
 RESUME_CORRECTIONS.md
 utils/*.sh
```

---

**Version**: 2.0
**Derniere mise a jour**: 2025-10-17 09:20
**Statut**:  Documentation complete + Scripts operationnels
