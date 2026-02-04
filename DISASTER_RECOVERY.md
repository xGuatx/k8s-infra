# DISASTER RECOVERY - Redeploiement Complet depuis Zero

## Scenario: k8s-master-1, k8s-master-2, k8s-master-3 completement detruits

Ce guide explique comment **tout reconstruire** avec seulement:
1. k8s-orchestrator (serveur de controle, toujours accessible)
2. Le fichier `.env.tmp` avec vos secrets
3. Les backups sur k8s-orchestrator dans `/opt/k8s-backups/`

---

## PREREQUIS CRITIQUES

### Avant le Desastre (A sauvegarder MAINTENANT)

Sur k8s-orchestrator, creez `/tmp/k8s-infra/.env.tmp` avec:

```bash
# === SECRETS ESSENTIELS ===
# Sauvegarder ce fichier dans KeePass/1Password/Bitwarden

# Mots de passe SSH/Sudo (pour acces aux machines)
SSH_PASSWORD=<YOUR_SSH_PASSWORD>
SUDO_PASSWORD=<YOUR_SSH_PASSWORD>

# Ansible Vault Password (pour dechiffrer les secrets)
# Recuperable depuis: /tmp/k8s-infra/CREDENTIALS.txt (premiere installation)
VAULT_PASSWORD=<mot_de_passe_vault>

# Optionnel: Cle GPG pour dechiffrer les backups securises
# Recuperable depuis: /tmp/k8s-infra/backup-gpg-private.key
# Si absent: les backups seront non dechiffres (legacy)
```

**IMPORTANT**: Sans ces secrets, la restauration est **IMPOSSIBLE**.

---

## PROCEDURE COMPLETE (40-50 minutes)

### ETAPE 1: Se connecter a k8s-orchestrator

```bash
# Depuis votre machine locale
ssh formation@k8s-orchestrator.example.com
# Mot de passe: <YOUR_SSH_PASSWORD>
```

### ETAPE 2: Recuperer l'infrastructure depuis l'archive

```bash
# Sur k8s-orchestrator
cd /tmp

# Si l'archive n'est plus la, la re-telecharger depuis votre machine locale:
# (depuis votre machine) scp k8s-infra.tar.gz formation@k8s-orchestrator.example.com:/tmp/

# Extraire
rm -rf k8s-infra
tar xzf k8s-infra.tar.gz
cd k8s-infra
```

### ETAPE 3: Creer le fichier `.env.tmp` avec les secrets

```bash
# Sur k8s-orchestrator, dans /tmp/k8s-infra/
cat > .env.tmp <<'EOF'
SSH_PASSWORD=<YOUR_SSH_PASSWORD>
SUDO_PASSWORD=<YOUR_SSH_PASSWORD>
EOF

chmod 600 .env.tmp
```

**Option A: Premier Deploiement (pas de backup)**

Si vous n'avez **jamais deploye** ou si vous voulez **tout reinitialiser**:

```bash
# Sur k8s-orchestrator, dans /tmp/k8s-infra/
export SSH_PASSWORD=<YOUR_SSH_PASSWORD>
export SUDO_PASSWORD=<YOUR_SSH_PASSWORD>

./deploy.sh
```

Le script va:
1. Installer les prerequis (Ansible, Helm, kubectl)
2. Generer tous les secrets automatiquement
3. Configurer SSH sans mot de passe
4. Installer K3s sur k8s-master-1-15
5. Deployer l'infrastructure complete
6. Creer le premier backup

**Duree**: ~45 minutes

**Option B: Restauration depuis Backup**

Si vous avez un backup existant et voulez restaurer les **donnees**:

```bash
# Sur k8s-orchestrator, dans /tmp/k8s-infra/

# 1. Verifier les backups disponibles
ls -lth /opt/k8s-backups/

# 2. Restaurer (choix automatique du dernier backup)
./restore.sh

# OU restaurer un backup specifique
./restore.sh 20251017-143000
```

Le script va:
1. Restaurer les secrets depuis le backup
2. Reconstruire le cluster K3s sur k8s-master-1-15
3. Restaurer l'infrastructure (Longhorn, Cert-Manager, Drupal)
4. Restaurer les donnees MySQL
5. Restaurer les fichiers Drupal
6. Restaurer Velero et Rancher (si presents)

**Duree**: ~30-35 minutes

---

## VERIFICATION POST-RESTAURATION

### 1. Verifier le Cluster

```bash
# Sur k8s-orchestrator
export KUBECONFIG=/tmp/k8s-infra/ansible/kubeconfig.yaml

# Nuds du cluster
kubectl get nodes
# Attendu: 3 nuds (k8s-master-1, k8s-master-2, k8s-master-3) en status "Ready"

# Tous les pods
kubectl get pods -A
# Attendu: Tous les pods "Running" ou "Completed"
```

### 2. Verifier MySQL

```bash
# Sur k8s-orchestrator
export KUBECONFIG=/tmp/k8s-infra/ansible/kubeconfig.yaml

# Statut des pods MySQL
kubectl get pods -n drupal -l app=mysql

# Se connecter a MySQL (recuperer mot de passe depuis CREDENTIALS.txt)
kubectl exec -it mysql-0 -n drupal -- mysql -u root -p

# Dans MySQL:
SHOW DATABASES;
USE drupal;
SHOW TABLES;
```

### 3. Tester Drupal

```bash
# Depuis votre navigateur:
# http://k8s-master-1.example.com:30080
# http://k8s-master-2.example.com:30080
# http://k8s-master-3.example.com:30080

# Si TLS active:
# https://k8s-master-1.example.com
```

### 4. Verifier Grafana/Prometheus

```bash
# Grafana: http://k8s-master-1.example.com:30300
# Prometheus: http://k8s-master-1.example.com:30090
# AlertManager: http://k8s-master-1.example.com:30903

# Credentials Grafana: Voir /tmp/k8s-infra/CREDENTIALS.txt
```

---

## GESTION DES BACKUPS

### Creer un Nouveau Backup Manuel

```bash
# Sur k8s-orchestrator
cd /tmp/k8s-infra
./backup/backup-to-k8s-orchestrator-secure.sh
```

### Backups Automatiques

Les backups sont configures automatiquement:
- **Frequence**: Quotidien a 2h00 AM
- **Retention**: 7 jours
- **Location**: `/opt/k8s-backups/`
- **Format**: `YYYYMMDD-HHMMSS/`

### Lister les Backups

```bash
# Sur k8s-orchestrator
ls -lth /opt/k8s-backups/

# Voir les details d'un backup
cat /opt/k8s-backups/20251017-143000/backup-info.txt
```

---

## SCRIPTS DISPONIBLES

### Sur votre Machine Locale

```bash
cd /home/guat/k8s-infra

# Se connecter a k8s-orchestrator
./connect-k8s-orchestrator.sh

# Executer une commande a distance sur k8s-orchestrator
./remote-exec.sh 'cd /tmp/k8s-infra && ./deploy.sh'
```

### Sur k8s-orchestrator (apres connexion)

```bash
cd /tmp/k8s-infra/utils

# Verifier l'etat du cluster
./check-cluster.sh

# Voir les logs d'un pod
./pod-logs.sh drupal mysql-0

# Debug complet d'un pod
./pod-debug.sh drupal mysql-0

# Check rapide
./quick-check.sh
```

---

## SITUATIONS SPECIALES

### Cas 1: Mot de passe SSH a Change

Si le mot de passe SSH de `formation` a change:

```bash
# Sur k8s-orchestrator, dans /tmp/k8s-infra/
# 1. Modifier .env.tmp avec le nouveau mot de passe
cat > .env.tmp <<'EOF'
SSH_PASSWORD=<nouveau_mot_de_passe>
SUDO_PASSWORD=<nouveau_mot_de_passe>
EOF

# 2. Relancer le deploiement (idempotent)
export SSH_PASSWORD=<nouveau_mot_de_passe>
export SUDO_PASSWORD=<nouveau_mot_de_passe>
./deploy.sh
```

### Cas 2: Vault Password Perdu

**Si vous avez un backup**:
1. Le `.vault_password` est sauvegarde dans `/opt/k8s-backups/<timestamp>/secrets/.vault_password`
2. Le copier vers `/tmp/k8s-infra/ansible/.vault_password`

**Si aucun backup**:
1. **IMPOSSIBLE de dechiffrer les secrets**
2. Solution: Redeploiement complet avec nouveaux secrets
3. **Perte de donnees**: Impossible de restaurer les anciens backups

C'est pourquoi il est **CRITIQUE** de sauvegarder `CREDENTIALS.txt` apres le premier deploiement.

### Cas 3: Cluster Partiellement Fonctionnel

Si k8s-master-1 fonctionne mais k8s-master-2/k8s-master-3 sont morts:

```bash
# Sur k8s-orchestrator
cd /tmp/k8s-infra/ansible

# Option 1: Ajouter seulement les nuds manquants
# (Necessite modifications manuelles du playbook - non documente)

# Option 2: Recommande - Tout nettoyer et redeployer
# 1. Desinstaller K3s partout
ansible k3s_cluster -m shell -a "/usr/local/bin/k3s-uninstall.sh"

# 2. Redeployer
cd /tmp/k8s-infra
./deploy.sh

# 3. Restaurer depuis backup si besoin
./restore.sh
```

---

## DEPANNAGE

### Erreur: "SSH connection failed"

```bash
# Tester la connectivite manuellement
ssh formation@k8s-master-1.example.com "hostname"
ssh formation@k8s-master-2.example.com "hostname"
ssh formation@k8s-master-3.example.com "hostname"

# Si echec: Verifier le mot de passe dans .env.tmp
```

### Erreur: "Vault password incorrect"

```bash
# Recuperer depuis backup
cp /opt/k8s-backups/<timestamp>/secrets/.vault_password /tmp/k8s-infra/ansible/

# Ou depuis CREDENTIALS.txt (si sauvegarde)
cat /tmp/k8s-infra/CREDENTIALS.txt | grep "VAULT PASSWORD"
```

### Erreur: "Pods in CrashLoopBackOff"

```bash
# Sur k8s-orchestrator
export KUBECONFIG=/tmp/k8s-infra/ansible/kubeconfig.yaml

# Identifier le pod en erreur
kubectl get pods -A | grep -v Running

# Debug
cd /tmp/k8s-infra/utils
./pod-debug.sh <namespace> <pod-name>

# Voir les logs
./pod-logs.sh <namespace> <pod-name>
```

---

## BEST PRACTICES

### 1. Sauvegardes a Faire Immediatement Apres Premier Deploiement

```bash
# Sur k8s-orchestrator, copier ces fichiers dans votre Password Manager:
1. /tmp/k8s-infra/CREDENTIALS.txt
    Contient TOUS les mots de passe

2. /tmp/k8s-infra/ansible/.vault_password
    Necessaire pour dechiffrer les secrets

3. /tmp/k8s-infra/backup-gpg-private.key (si existe)
    Necessaire pour dechiffrer les backups GPG

4. /tmp/k8s-infra/.env.tmp (creer si absent)
    SSH_PASSWORD et SUDO_PASSWORD
```

### 2. Tester la Restauration Regulierement

```bash
# Sur k8s-orchestrator, tous les mois:
cd /tmp/k8s-infra

# 1. Creer un backup
./backup/backup-to-k8s-orchestrator-secure.sh

# 2. Tester la restauration (mode dry-run)
# Verifier que les backups sont lisibles
ls -lth /opt/k8s-backups/ | head -5
```

### 3. Surveiller l'Espace Disque

```bash
# Sur k8s-orchestrator
df -h /opt/k8s-backups

# Nettoyer les anciens backups (>30 jours)
find /opt/k8s-backups -type d -mtime +30 -exec rm -rf {} \;
```

---

## REFERENCES

- **Guide complet**: `/home/guat/k8s-infra/GUIDE_DEBUG_MANUEL.md`
- **Index du projet**: `/home/guat/k8s-infra/INDEX.md`
- **Corrections appliquees**: `/home/guat/k8s-infra/RESUME_CORRECTIONS.md`
- **Scripts utilitaires**: `/home/guat/k8s-infra/utils/README.md`
- **Point d'entree rapide**: `/home/guat/REPRISE_MANUELLE.md`

---

## CHECKLIST DISASTER RECOVERY

Avant de commencer:
- [ ] k8s-orchestrator est accessible (SSH)
- [ ] Archive `k8s-infra.tar.gz` disponible sur k8s-orchestrator
- [ ] Fichier `.env.tmp` cree avec SSH_PASSWORD et SUDO_PASSWORD
- [ ] Sauvegarde CREDENTIALS.txt dans Password Manager (si disponible)

Pendant la restauration:
- [ ] deploy.sh ou restore.sh execute
- [ ] Aucune erreur critique dans les logs
- [ ] 3 nuds apparaissent dans `kubectl get nodes`

Apres la restauration:
- [ ] Tous les pods sont Running
- [ ] MySQL accessible et contient des donnees
- [ ] Drupal accessible via HTTP/HTTPS
- [ ] Grafana/Prometheus accessibles
- [ ] Nouveau backup cree manuellement
- [ ] CREDENTIALS.txt sauvegarde (si nouveau deploiement)

---

**Version**: 1.0
**Derniere mise a jour**: 2025-10-17
**Teste sur**: k8s-master-1-16 (Debian 12)
