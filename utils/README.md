# Scripts Utilitaires K3s

##  Deux Modes d'Utilisation

### Mode 1: Directement sur k8s-orchestrator (RECOMMANDE)

**Se connecter a k8s-orchestrator**:
```bash
# Depuis la machine locale
cd /home/guat/k8s-infra
./connect-k8s-orchestrator.sh

# Une fois connecte, vous etes dans /tmp/k8s-infra/utils
# Executez les scripts directement:
./check-cluster.sh
./pod-logs.sh drupal mysql-0
```

### Mode 2: Depuis la Machine Locale

**Execution a distance**:
```bash
# Depuis la machine locale
cd /home/guat/k8s-infra
./remote-exec.sh 'cd /tmp/k8s-infra/utils && ./check-cluster.sh'
```

---

##  Liste des Scripts

###  Gestion du Cluster (A executer depuis la machine locale)

| Script | Description | Ou l'executer |
|--------|-------------|---------------|
| `cleanup-cluster.sh` | Supprime K3s sur k8s-master-1-15 | Machine locale |
| `upload-archive.sh` | Upload archive sur k8s-orchestrator | Machine locale |
| `deploy-cluster.sh` | Lance le deploiement | Machine locale |

###  Surveillance (A executer depuis la machine locale)

| Script | Description | Ou l'executer |
|--------|-------------|---------------|
| `watch-deploy.sh` | Surveillance temps reel | Machine locale |
| `check-deploy.sh` | Verification deploiement | Machine locale |

###  Verification Cluster (A executer SUR k8s-orchestrator)

| Script | Description | Ou l'executer |
|--------|-------------|---------------|
| `check-cluster.sh` | Verification complete | **k8s-orchestrator** |
| `quick-check.sh` | Check ultra-rapide | **k8s-orchestrator** |

###  Debogage (A executer SUR k8s-orchestrator)

| Script | Description | Ou l'executer |
|--------|-------------|---------------|
| `pod-logs.sh` | Logs d'un pod | **k8s-orchestrator** |
| `pod-debug.sh` | Debug complet pod | **k8s-orchestrator** |

###  Connexion (A executer depuis la machine locale)

| Script | Description | Usage |
|--------|-------------|-------|
| `../connect-k8s-orchestrator.sh` | Se connecter a k8s-orchestrator | `./connect-k8s-orchestrator.sh` |
| `../remote-exec.sh` | Executer commande a distance | `./remote-exec.sh '<cmd>'` |

---

##  Workflows Complets

### Workflow 1: Deploiement Initial

**Depuis la machine locale** (`/home/guat/k8s-infra`):

```bash
# 1. Upload
./utils/upload-archive.sh

# 2. Deployer
./utils/deploy-cluster.sh

# 3. Surveiller
./utils/watch-deploy.sh
```

**Une fois termine, verifier sur k8s-orchestrator**:

```bash
# Se connecter
./connect-k8s-orchestrator.sh

# Verifier (vous etes maintenant sur k8s-orchestrator)
./check-cluster.sh
```

### Workflow 2: Verification Rapide

**Option A: Depuis la machine locale**:
```bash
cd /home/guat/k8s-infra
./remote-exec.sh 'cd /tmp/k8s-infra/utils && ./check-cluster.sh'
```

**Option B: Sur k8s-orchestrator (RECOMMANDE)**:
```bash
# Se connecter
./connect-k8s-orchestrator.sh

# Verifier
./check-cluster.sh
```

### Workflow 3: Debogage MySQL

**Sur k8s-orchestrator** (apres connexion avec `./connect-k8s-orchestrator.sh`):

```bash
# 1. Check general
./check-cluster.sh

# 2. Debug du pod
./pod-debug.sh drupal mysql-0

# 3. Logs detailles
./pod-logs.sh drupal mysql-0 init-mysql 200

# 4. Logs en temps reel
export KUBECONFIG=/tmp/k8s-infra/ansible/kubeconfig.yaml
kubectl logs -f mysql-0 -n drupal -c mysql
```

---

##  Exemples Detailles

### Exemple 1: Premier Deploiement Complet

```bash
# === ETAPE 1: Depuis la machine locale (/home/guat/k8s-infra) ===
cd /home/guat/k8s-infra

# Upload
./utils/upload-archive.sh
#  Archive uploadee (2.3M)

# Deployer
./utils/deploy-cluster.sh
#  Deploiement lance (PID: 12345)
#  Log: /tmp/deploy-20251017-100000.log

# Surveiller (interrompre avec Ctrl+C quand vous voulez)
./utils/watch-deploy.sh /tmp/deploy-20251017-100000.log
# ... affiche les logs en temps reel ...

# === ETAPE 2: Verification sur k8s-orchestrator (une fois termine) ===

# Se connecter
./connect-k8s-orchestrator.sh
# Vous etes maintenant connecte sur k8s-orchestrator dans /tmp/k8s-infra/utils

# Verifier
formation@k8s00:/tmp/k8s-infra/utils$ ./check-cluster.sh
#  3 nuds Ready
#  Tous pods Running

# Quitter
formation@k8s00:/tmp/k8s-infra/utils$ exit
```

### Exemple 2: MySQL en CrashLoopBackOff

```bash
# === Sur k8s-orchestrator (apres ./connect-k8s-orchestrator.sh) ===

formation@k8s00:/tmp/k8s-infra/utils$ ./check-cluster.sh
#  mysql-0: 0/2 CrashLoopBackOff

formation@k8s00:/tmp/k8s-infra/utils$ ./pod-debug.sh drupal mysql-0
# === Evenements recents ===
# Warning: Back-off restarting failed container

formation@k8s00:/tmp/k8s-infra/utils$ ./pod-logs.sh drupal mysql-0 init-mysql
# bash: line 3: hostname: command not found
# => Le fix n'est pas applique !
```

### Exemple 3: Execution A Distance (sans se connecter)

```bash
# Depuis la machine locale
cd /home/guat/k8s-infra

# Check rapide
./remote-exec.sh 'cd /tmp/k8s-infra/utils && ./check-cluster.sh'

# Logs d'un pod
./remote-exec.sh 'cd /tmp/k8s-infra/utils && ./pod-logs.sh drupal mysql-0 mysql 50'

# Commande kubectl directe
./remote-exec.sh 'export KUBECONFIG=/tmp/k8s-infra/ansible/kubeconfig.yaml && kubectl get nodes'
```

---

##  Configuration kubectl sur k8s-orchestrator

Une fois connecte sur k8s-orchestrator, kubectl est configure automatiquement si vous utilisez:

```bash
export KUBECONFIG=/tmp/k8s-infra/ansible/kubeconfig.yaml
```

**Pour rendre permanent** (ajoutez a `~/.bashrc` sur k8s-orchestrator):

```bash
# Sur k8s-orchestrator
echo 'export KUBECONFIG=/tmp/k8s-infra/ansible/kubeconfig.yaml' >> ~/.bashrc
echo 'alias k=kubectl' >> ~/.bashrc
source ~/.bashrc

# Maintenant vous pouvez utiliser:
kubectl get nodes
k get pods -A
```

---

##  Structure des Fichiers

```
/home/guat/k8s-infra/
 connect-k8s-orchestrator.sh          # Connexion interactive a k8s-orchestrator
 remote-exec.sh             # Execution commande a distance
 utils/                     # Scripts a executer
    README.md             # Ce fichier
   
   # Scripts LOCAUX (machine locale)
    cleanup-cluster.sh    # Supprime K3s
    upload-archive.sh     # Upload archive
    deploy-cluster.sh     # Lance deploiement
    watch-deploy.sh       # Surveillance temps reel
    check-deploy.sh       # Check deploiement
   
   # Scripts K8S16 (sur k8s-orchestrator)
    check-cluster.sh      # Verification cluster
    quick-check.sh        # Check rapide
    pod-logs.sh           # Logs pod
    pod-debug.sh          # Debug pod
```

**Sur k8s-orchestrator** (apres deploiement):
```
/tmp/k8s-infra/
 deploy.sh
 utils/                    # Copie des scripts
    check-cluster.sh
    quick-check.sh
    pod-logs.sh
    pod-debug.sh
 ansible/
     kubeconfig.yaml       # Config kubectl
```

---

##  Variables d'Environnement

### Sur la Machine Locale

Les scripts locaux utilisent:
```bash
PASSWORD="<YOUR_SSH_PASSWORD>"
USER="${SSH_USER:-your_user}"
HOST="k8s-orchestrator.example.com"
```

### Sur k8s-orchestrator

Les scripts sur k8s-orchestrator utilisent:
```bash
KUBECONFIG=/tmp/k8s-infra/ansible/kubeconfig.yaml
```

---

##  Depannage

### Probleme 1: Script ne s'execute pas

**Sur la machine locale**:
```bash
chmod +x /home/guat/k8s-infra/*.sh
chmod +x /home/guat/k8s-infra/utils/*.sh
```

**Sur k8s-orchestrator**:
```bash
# Reconnecter et verifier
./connect-k8s-orchestrator.sh
chmod +x /tmp/k8s-infra/utils/*.sh
```

### Probleme 2: Kubeconfig non trouve sur k8s-orchestrator

```bash
# Se connecter
./connect-k8s-orchestrator.sh

# Verifier
ls -la /tmp/k8s-infra/ansible/kubeconfig.yaml

# Si absent, le deploiement n'est pas encore termine
tail -50 /tmp/deploy*.log
```

### Probleme 3: Connexion SSH echoue

```bash
# Tester la connexion
sshpass -p '<YOUR_SSH_PASSWORD>' ssh formation@k8s-orchestrator.example.com "hostname"
# Devrait afficher: k8s00

# Si echec, verifier le mot de passe dans les scripts
```

---

##  Commandes kubectl Utiles (Sur k8s-orchestrator)

Une fois connecte sur k8s-orchestrator avec `./connect-k8s-orchestrator.sh`:

```bash
# Exporter kubeconfig (si pas deja fait)
export KUBECONFIG=/tmp/k8s-infra/ansible/kubeconfig.yaml

# Nuds
kubectl get nodes -o wide

# Tous les pods
kubectl get pods -A

# Pods en erreur
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded

# Logs d'un pod
kubectl logs mysql-0 -n drupal -c mysql

# Logs en temps reel
kubectl logs -f mysql-0 -n drupal -c mysql

# Shell dans un pod
kubectl exec -it mysql-0 -n drupal -c mysql -- bash

# Describe un pod
kubectl describe pod mysql-0 -n drupal

# Evenements
kubectl get events -n drupal --sort-by='.lastTimestamp'

# PVC
kubectl get pvc -A

# Services
kubectl get svc -A
```

---

##  Astuces

### 1. Alias Pratiques (Sur k8s-orchestrator)

Ajoutez a `~/.bashrc` sur k8s-orchestrator:

```bash
export KUBECONFIG=/tmp/k8s-infra/ansible/kubeconfig.yaml
alias k=kubectl
alias kgp='kubectl get pods'
alias kgpa='kubectl get pods -A'
alias kgn='kubectl get nodes'
alias kd='kubectl describe'
alias kl='kubectl logs'
alias ke='kubectl exec -it'
```

### 2. Watch Continu

```bash
# Sur k8s-orchestrator
watch -n 2 'kubectl get pods -A'
```

### 3. Scripts Rapides

```bash
# Check rapide depuis local
./remote-exec.sh 'cd /tmp/k8s-infra/utils && ./check-cluster.sh' | head -30
```

---

##  Support

**Documentation complete**:
- `/home/guat/REPRISE_MANUELLE.md` - Point d'entree
- `/home/guat/k8s-infra/INDEX.md` - Index complet
- `/home/guat/k8s-infra/GUIDE_DEBUG_MANUEL.md` - Guide technique
- `/home/guat/k8s-infra/RESUME_CORRECTIONS.md` - Details corrections

**En cas de probleme**:
1. Verifier le deploiement: `./utils/check-deploy.sh`
2. Se connecter a k8s-orchestrator: `./connect-k8s-orchestrator.sh`
3. Verifier le cluster: `./check-cluster.sh`
4. Debug un pod: `./pod-debug.sh <ns> <pod>`

---

**Version**: 3.0 (Scripts pour execution sur k8s-orchestrator)
**Derniere mise a jour**: 2025-10-17
