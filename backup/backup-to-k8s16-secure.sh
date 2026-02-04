#!/bin/bash
# Backup complet SECURISE vers k8s-orchestrator
# Chiffrement GPG de tous les fichiers sensibles
# A executer depuis k8s-orchestrator via cron quotidien

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ENV_FILE_SSH_USER=""
ENV_FILE_SSH_PASSWORD=""
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

KUBECONFIG="${KUBECONFIG:-$HOME/k8s-infra/ansible/kubeconfig.yaml}"
export KUBECONFIG

BACKUP_ROOT="/opt/k8s-backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"
GPG_RECIPIENT="${GPG_BACKUP_KEY:-backup@example.com}"

# Verifier que GPG est configure
if ! gpg --list-keys "$GPG_RECIPIENT" &>/dev/null; then
    echo " Cle GPG $GPG_RECIPIENT introuvable!"
    echo "   Generer avec: gpg --full-generate-key"
    exit 1
fi

mkdir -p "$BACKUP_DIR"/{etcd,mysql,drupal-files,velero,manifests,secrets,config,rancher,checksums}

# Permissions strictes sur le backup
chmod 750 "$BACKUP_DIR"

echo ""
echo "     BACKUP SECURISE VERS K8S16 (GPG Encrypted)        "
echo ""
echo "Timestamp: $TIMESTAMP"
echo "Location: $BACKUP_DIR"
echo "GPG Key: $GPG_RECIPIENT"
echo ""

# Fonction de chiffrement
encrypt_file() {
    local file="$1"
    if [ -f "$file" ]; then
        gpg --encrypt --recipient "$GPG_RECIPIENT" --batch --yes --quiet "$file"
        rm -f "$file"  # Supprimer version non chiffree
        echo "$(basename "$file").gpg"
    fi
}

# Fonction checksum
checksum_file() {
    local file="$1"
    if [ -f "$file" ]; then
        sha256sum "$file" >> "$BACKUP_DIR/checksums/SHA256SUMS"
    fi
}

# 1. BACKUP ETCD (chiffre)
echo "[1/8] Backup etcd snapshot from k8s-master-1..."
ssh "${SSH_USER}@k8s-master-1.example.com" \
  "sudo k3s etcd-snapshot save --name backup-$TIMESTAMP"

scp "${SSH_USER}@k8s-master-1.example.com:/var/lib/rancher/k3s/server/db/snapshots/backup-$TIMESTAMP" \
  "$BACKUP_DIR/etcd/etcd-snapshot-$TIMESTAMP"

# Chiffrer etcd snapshot
cd "$BACKUP_DIR/etcd"
encrypt_file "etcd-snapshot-$TIMESTAMP"
checksum_file "etcd-snapshot-$TIMESTAMP.gpg"

echo "   Etcd snapshot (chiffre GPG): $(du -h "$BACKUP_DIR/etcd/etcd-snapshot-$TIMESTAMP.gpg" | cut -f1)"

# 2. BACKUP MYSQL (chiffre)
echo "[2/8] Backup MySQL databases..."
MYSQL_ROOT_PASSWORD="$(kubectl get secret mysql-secret -n drupal -o jsonpath='{.data.mysql-root-password}' 2>/dev/null | base64 --decode || true)"
if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
  echo "   Impossible de recuperer le mot de passe MySQL, dump ignore."
else
  for i in 0 1 2; do
    POD="mysql-$i"
    if kubectl get pod "$POD" -n drupal &>/dev/null; then
      echo "  - Dumping from $POD..."

      kubectl exec "$POD" -n drupal -- env MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysqldump \
        -u root \
        --all-databases \
        --single-transaction \
        --quick \
        --lock-tables=false \
        --routines \
        --triggers > "$BACKUP_DIR/mysql/all-databases-$POD.sql"

      gzip "$BACKUP_DIR/mysql/all-databases-$POD.sql"

      cd "$BACKUP_DIR/mysql"
      encrypt_file "all-databases-$POD.sql.gz"
      checksum_file "all-databases-$POD.sql.gz.gpg"

      echo "     $(du -h "$BACKUP_DIR/mysql/all-databases-$POD.sql.gz.gpg" | cut -f1)"
      break
    fi
  done
fi

# 3. BACKUP DRUPAL FILES (chiffre)
echo "[3/8] Backup Drupal files (PVC)..."
DRUPAL_POD=$(kubectl get pod -n drupal -l app=drupal -o jsonpath='{.items[0].metadata.name}')

if [ -n "$DRUPAL_POD" ]; then
  kubectl exec -n drupal $DRUPAL_POD -- \
    tar czf /tmp/drupal-files-$TIMESTAMP.tar.gz \
    -C /var/www/html/sites/default/files . 2>/dev/null || true

  kubectl cp drupal/$DRUPAL_POD:/tmp/drupal-files-$TIMESTAMP.tar.gz \
    "$BACKUP_DIR/drupal-files/files-$TIMESTAMP.tar.gz"

  # Chiffrer Drupal files
  cd "$BACKUP_DIR/drupal-files"
  encrypt_file "files-$TIMESTAMP.tar.gz"
  checksum_file "files-$TIMESTAMP.tar.gz.gpg"

  echo "   $(du -h "$BACKUP_DIR/drupal-files/files-$TIMESTAMP.tar.gz.gpg" | cut -f1)"
fi

# 4. BACKUP VELERO
echo "[4/8] Trigger Velero backup..."
velero backup create "backup-$TIMESTAMP" \
  --include-namespaces drupal,monitoring,longhorn-system \
  --ttl 168h \
  --wait 2>/dev/null || echo "   Velero not available, skipping"

# 5. BACKUP MANIFESTS (SANS SECRETS!)
echo "[5/8] Backup Kubernetes manifests (excluding secrets)..."
kubectl get all,pvc,configmaps -n drupal -o yaml > "$BACKUP_DIR/manifests/drupal.yaml"
kubectl get all,pvc,configmaps -n monitoring -o yaml > "$BACKUP_DIR/manifests/monitoring.yaml" 2>/dev/null || true
kubectl get all -n longhorn-system -o yaml > "$BACKUP_DIR/manifests/longhorn.yaml" 2>/dev/null || true
kubectl get nodes -o yaml > "$BACKUP_DIR/manifests/nodes.yaml"

# Copier manifests locaux (code public, pas de secrets)
cp -r $HOME/k8s-infra/helm/charts/* "$BACKUP_DIR/manifests/" 2>/dev/null || true

# Checksum manifests (non chiffres car publics)
cd "$BACKUP_DIR/manifests"
for f in *.yaml; do
    checksum_file "$f"
done

echo "   Manifests sauvegardes (secrets exclus)"

# 6. BACKUP SECRETS & CONFIGURATION
echo "[6/8] Backup secrets et configuration..."

# Copier vault.yml (deja chiffre avec Ansible Vault)
cp $HOME/k8s-infra/ansible/inventory/group_vars/vault.yml \
  "$BACKUP_DIR/secrets/vault.yml" 2>/dev/null || echo "   vault.yml not found"
checksum_file "$BACKUP_DIR/secrets/vault.yml"

# NE PAS backuper .vault_password (Password Manager uniquement)
cat > "$BACKUP_DIR/secrets/vault-password-location.txt" <<EOF
  VAULT PASSWORD NOT BACKED UP

La cle de dechiffrement Ansible Vault (.vault_password) n'est PAS
sauvegardee dans ce backup pour des raisons de securite.

Pour restaurer ce backup, recuperer .vault_password depuis:
  1. Password Manager (1Password, Bitwarden, etc.)
  2. CREDENTIALS.txt original (si conserve)
  3. Autre backup securise hors k8s-orchestrator

Si perdu, impossible de dechiffrer vault.yml
 Necessite regeneration complete des secrets
EOF

# Sauvegarder kubeconfig (chiffre)
if [ -f "$HOME/k8s-infra/ansible/kubeconfig.yaml" ]; then
    cp "$HOME/k8s-infra/ansible/kubeconfig.yaml" "$BACKUP_DIR/secrets/kubeconfig.yaml"
    cd "$BACKUP_DIR/secrets"
    encrypt_file "kubeconfig.yaml"
    checksum_file "kubeconfig.yaml.gpg"
fi

echo "   Secrets sauvegardes (vault.yml chiffre, .vault_password NOT backed up)"

# 7. BACKUP CONFIGURATION ANSIBLE & SSH
echo "[7/8] Backup configuration Ansible et SSH..."

# Inventory et playbooks (code public)
cp -r $HOME/k8s-infra/ansible/inventory "$BACKUP_DIR/config/" 2>/dev/null || true
cp $HOME/k8s-infra/ansible/ansible.cfg "$BACKUP_DIR/config/" 2>/dev/null || true
cp -r $HOME/k8s-infra/ansible/playbooks "$BACKUP_DIR/config/" 2>/dev/null || true

# Cles SSH (chiffrees)
if [ -f ~/.ssh/id_rsa ]; then
  cp ~/.ssh/id_rsa "$BACKUP_DIR/config/id_rsa"
  cp ~/.ssh/id_rsa.pub "$BACKUP_DIR/config/id_rsa.pub"

  # Chiffrer cle privee SSH
  cd "$BACKUP_DIR/config"
  encrypt_file "id_rsa"
  checksum_file "id_rsa.gpg"
  checksum_file "id_rsa.pub"  # Publique OK
fi

# known_hosts (public, pas besoin chiffrement)
cp ~/.ssh/known_hosts "$BACKUP_DIR/config/known_hosts" 2>/dev/null || true
checksum_file "$BACKUP_DIR/config/known_hosts" 2>/dev/null || true

echo "   Configuration Ansible/SSH sauvegardee (cle SSH chiffree)"

# 8. BACKUP RANCHER (chiffre)
echo "[8/8] Backup Rancher (sur k8s-orchestrator)..."

if sudo docker ps 2>/dev/null | grep -q rancher-server; then
    echo "  - Rancher detecte, backup en cours..."

    # Backup /opt/rancher
    if [ -d "/opt/rancher" ]; then
        sudo tar czf "$BACKUP_DIR/rancher/rancher-data-$TIMESTAMP.tar.gz" \
            -C /opt rancher 2>/dev/null || echo "   Erreur backup /opt/rancher"

        if [ -f "$BACKUP_DIR/rancher/rancher-data-$TIMESTAMP.tar.gz" ]; then
            # Chiffrer Rancher data
            cd "$BACKUP_DIR/rancher"
            sudo chown $USER:$USER "rancher-data-$TIMESTAMP.tar.gz"
            encrypt_file "rancher-data-$TIMESTAMP.tar.gz"
            checksum_file "rancher-data-$TIMESTAMP.tar.gz.gpg"
            echo "     Data Rancher (chiffre): $(du -h rancher-data-$TIMESTAMP.tar.gz.gpg | cut -f1)"
        fi
    fi

    # Config Docker (public, pas sensible)
    sudo docker inspect rancher-server > "$BACKUP_DIR/rancher/rancher-container-config.json" 2>/dev/null || true
    sudo chown $USER:$USER "$BACKUP_DIR/rancher/rancher-container-config.json" 2>/dev/null || true
    checksum_file "$BACKUP_DIR/rancher/rancher-container-config.json" 2>/dev/null || true

    echo "   Rancher sauvegarde (data chiffree GPG)"
else
    echo "   Rancher non installe (skip)"
    echo "none" > "$BACKUP_DIR/rancher/rancher-not-installed.txt"
fi

# METADATA
cat > "$BACKUP_DIR/backup-info.txt" <<EOF

BACKUP INFORMATION (SECURISE - GPG ENCRYPTED)


Date: $(date)
Timestamp: $TIMESTAMP
Backup Location: $BACKUP_DIR
GPG Key: $GPG_RECIPIENT
Security: AES256 + GPG

CLUSTER STATE:
$(kubectl get nodes 2>/dev/null || echo "Cluster not accessible")

DRUPAL PODS:
$(kubectl get pods -n drupal 2>/dev/null || echo "Drupal namespace not accessible")

BACKUP CONTENTS ( FICHIERS .gpg SONT CHIFFRES):
- etcd snapshot: $(ls -lh $BACKUP_DIR/etcd/*.gpg 2>/dev/null || echo "None")
- MySQL dump: $(ls -lh $BACKUP_DIR/mysql/*.gpg 2>/dev/null || echo "None")
- Drupal files: $(ls -lh $BACKUP_DIR/drupal-files/*.gpg 2>/dev/null || echo "None")
- Manifests: $(ls $BACKUP_DIR/manifests/*.yaml 2>/dev/null | wc -l) files (secrets exclus)
- Secrets: vault.yml (Ansible Vault AES256), kubeconfig.yaml.gpg
- Config: Ansible inventory, playbooks, id_rsa.gpg
- Rancher: $(ls -lh $BACKUP_DIR/rancher/*.gpg 2>/dev/null || echo "Not installed")

TOTAL SIZE: $(du -sh $BACKUP_DIR | cut -f1)

SECURITE:
 Fichiers sensibles chiffres avec GPG
 .vault_password NOT backed up (Password Manager)
 Secrets Kubernetes exclus des manifests
 Checksums SHA256 generes
 Permissions 750 sur backup directory

RECOVERY:
1. Recuperer cle GPG privee depuis Password Manager
   gpg --import backup-private.key

2. Recuperer .vault_password depuis Password Manager
   echo "password" > ansible/.vault_password

3. Restaurer backup
   ./restore.sh $TIMESTAMP
   (dechiffre automatiquement les fichiers .gpg)


EOF

# Permissions finales strictes
chmod 640 "$BACKUP_DIR"/* 2>/dev/null || true
chmod 640 "$BACKUP_DIR"/*/* 2>/dev/null || true

# CLEANUP: Garder seulement les 7 derniers backups
echo ""
echo "Nettoyage des anciens backups (retention: 7 jours)..."
cd "$BACKUP_ROOT"
ls -t | tail -n +8 | xargs -r rm -rf
REMAINING=$(ls -1 | wc -l)
echo "   Backups restants: $REMAINING"

# RESUME
BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
ENCRYPTED_COUNT=$(find "$BACKUP_DIR" -name "*.gpg" | wc -l)

echo ""
echo ""
echo "          BACKUP SECURISE TERMINE                       "
echo ""
echo ""
echo "Location: $BACKUP_DIR"
echo "Size: $BACKUP_SIZE"
echo "Encrypted files (GPG): $ENCRYPTED_COUNT"
echo "Checksums: $(wc -l < "$BACKUP_DIR/checksums/SHA256SUMS") files"
echo ""
echo "Securite:"
echo "   Etcd, MySQL, Drupal files, kubeconfig  Chiffres GPG"
echo "   Cles SSH privees  Chiffrees GPG"
echo "   Rancher data  Chiffre GPG"
echo "   vault.yml  Ansible Vault AES256"
echo "   .vault_password  Password Manager uniquement"
echo "   Secrets K8s  Exclus des manifests"
echo "   Permissions  640 (accessible uniquement proprietaire)"
echo ""
echo "  IMPORTANT:"
echo "  - Cle GPG privee: Sauvegardee dans Password Manager"
echo "  - .vault_password: Sauvegardee dans Password Manager"
echo "  - Sans ces 2 elements: Backup inutilisable"
echo ""
echo "Pour restaurer:"
echo "  1. gpg --import backup-private.key"
echo "  2. echo 'vault_password' > ansible/.vault_password"
echo "  3. $HOME/k8s-infra/restore.sh $TIMESTAMP"
echo ""
