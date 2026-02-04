#!/bin/bash
# Backup complet vers k8s-orchestrator (externe au cluster)
# A executer depuis k8s-orchestrator via cron quotidien
# Permet de recuperer meme si les 3 nuds k8s-master-1-15 sont perdus

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

mkdir -p "$BACKUP_DIR"/{etcd,mysql,drupal-files,velero,manifests,secrets,config,rancher}

echo ""
echo "     BACKUP COMPLET VERS K8S16                          "
echo ""
echo "Timestamp: $TIMESTAMP"
echo "Location: $BACKUP_DIR"
echo ""

# 1. BACKUP ETCD (etat complet du cluster K3s)
echo "[1/8] Backup etcd snapshot from k8s-master-1..."
ssh "${SSH_USER}@k8s-master-1.example.com" \
  "sudo k3s etcd-snapshot save --name backup-$TIMESTAMP"

scp "${SSH_USER}@k8s-master-1.example.com:/var/lib/rancher/k3s/server/db/snapshots/backup-$TIMESTAMP" \
  "$BACKUP_DIR/etcd/etcd-snapshot-$TIMESTAMP"

echo "   Etcd snapshot: $(du -h $BACKUP_DIR/etcd/etcd-snapshot-$TIMESTAMP | cut -f1)"

# 2. BACKUP MYSQL (dumps SQL de toutes les bases)
echo "[2/8] Backup MySQL databases..."
MYSQL_ROOT_PASSWORD="$(kubectl get secret mysql-secret -n drupal -o jsonpath='{.data.mysql-root-password}' 2>/dev/null | base64 --decode || true)"
if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
  echo "   Impossible de recuperer le mot de passe MySQL, dump ignore."
else
for i in 0 1 2; do
  POD="mysql-$i"
  if kubectl get pod $POD -n drupal &>/dev/null; then
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
    echo "     $(du -h $BACKUP_DIR/mysql/all-databases-$POD.sql.gz | cut -f1)"
    break  # Un seul dump suffit
  fi
done
fi

# 3. BACKUP DRUPAL FILES (volumes persistants)
echo "[3/8] Backup Drupal files (PVC)..."
DRUPAL_POD=$(kubectl get pod -n drupal -l app=drupal -o jsonpath='{.items[0].metadata.name}')

if [ -n "$DRUPAL_POD" ]; then
  kubectl exec -n drupal $DRUPAL_POD -- \
    tar czf /tmp/drupal-files-$TIMESTAMP.tar.gz \
    -C /var/www/html/sites/default/files . 2>/dev/null || true

  kubectl cp drupal/$DRUPAL_POD:/tmp/drupal-files-$TIMESTAMP.tar.gz \
    "$BACKUP_DIR/drupal-files/files-$TIMESTAMP.tar.gz"

  echo "   $(du -h $BACKUP_DIR/drupal-files/files-$TIMESTAMP.tar.gz | cut -f1)"
fi

# 4. BACKUP VELERO (snapshots Kubernetes natifs)
echo "[4/8] Trigger Velero backup..."
velero backup create "backup-$TIMESTAMP" \
  --include-namespaces drupal,monitoring,longhorn-system \
  --ttl 168h \
  --wait 2>/dev/null || echo "   Velero not available, skipping"

# 5. BACKUP MANIFESTS (tous les manifests Kubernetes)
echo "[5/8] Backup Kubernetes manifests..."
kubectl get all,pvc,secrets,configmaps -n drupal -o yaml > "$BACKUP_DIR/manifests/drupal.yaml"
kubectl get all,pvc,secrets,configmaps -n monitoring -o yaml > "$BACKUP_DIR/manifests/monitoring.yaml" 2>/dev/null || true
kubectl get all -n longhorn-system -o yaml > "$BACKUP_DIR/manifests/longhorn.yaml" 2>/dev/null || true
kubectl get nodes -o yaml > "$BACKUP_DIR/manifests/nodes.yaml"

# Copier aussi les manifests locaux
cp -r $HOME/k8s-infra/ansible/playbooks/manifests/* "$BACKUP_DIR/manifests/" 2>/dev/null || true

echo "   Manifests sauvegardes"

# 6. BACKUP SECRETS & CONFIGURATION
echo "[6/8] Backup secrets et configuration..."

# Copier le vault (chiffre, donc safe)
cp $HOME/k8s-infra/ansible/inventory/group_vars/vault.yml \
  "$BACKUP_DIR/secrets/vault.yml" 2>/dev/null || echo "   vault.yml not found"

# Sauvegarder le vault password (ATTENTION: fichier sensible!)
cp $HOME/k8s-infra/ansible/.vault_password \
  "$BACKUP_DIR/secrets/.vault_password" 2>/dev/null || echo "   .vault_password not found"

# Sauvegarder le kubeconfig
cp $HOME/k8s-infra/ansible/kubeconfig.yaml \
  "$BACKUP_DIR/secrets/kubeconfig.yaml" 2>/dev/null || echo "   kubeconfig not found"

echo "   Secrets sauvegardes"

# 7. BACKUP CONFIGURATION ANSIBLE & SSH
echo "[7/8] Backup configuration Ansible et SSH..."

# Sauvegarder l'inventory Ansible complet
cp -r $HOME/k8s-infra/ansible/inventory "$BACKUP_DIR/config/" 2>/dev/null || true

# Sauvegarder ansible.cfg
cp $HOME/k8s-infra/ansible/ansible.cfg "$BACKUP_DIR/config/" 2>/dev/null || true

# Sauvegarder les playbooks (pour reference)
cp -r $HOME/k8s-infra/ansible/playbooks "$BACKUP_DIR/config/" 2>/dev/null || true

# Sauvegarder cles SSH si presentes
if [ -f ~/.ssh/id_rsa ]; then
  cp ~/.ssh/id_rsa "$BACKUP_DIR/config/id_rsa" 2>/dev/null || true
  cp ~/.ssh/id_rsa.pub "$BACKUP_DIR/config/id_rsa.pub" 2>/dev/null || true
fi

# Sauvegarder known_hosts
cp ~/.ssh/known_hosts "$BACKUP_DIR/config/known_hosts" 2>/dev/null || true

echo "   Configuration Ansible/SSH sauvegardee"

# 8. BACKUP RANCHER (si installe sur k8s-orchestrator)
echo "[8/8] Backup Rancher (sur k8s-orchestrator)..."

# Verifier si Rancher est installe
if sudo docker ps 2>/dev/null | grep -q rancher-server; then
    echo "  - Rancher detecte, backup en cours..."

    # Backup des donnees Rancher (/opt/rancher)
    if [ -d "/opt/rancher" ]; then
        sudo tar czf "$BACKUP_DIR/rancher/rancher-data-$TIMESTAMP.tar.gz" \
            -C /opt rancher 2>/dev/null || echo "   Erreur backup /opt/rancher"

        if [ -f "$BACKUP_DIR/rancher/rancher-data-$TIMESTAMP.tar.gz" ]; then
            echo "     Data Rancher: $(du -h $BACKUP_DIR/rancher/rancher-data-$TIMESTAMP.tar.gz | cut -f1)"
        fi
    fi

    # Export de la configuration Docker du container
    sudo docker inspect rancher-server > "$BACKUP_DIR/rancher/rancher-container-config.json" 2>/dev/null || true

    # Sauvegarder les logs Rancher (derniers 10000 lignes)
    sudo docker logs --tail 10000 rancher-server > "$BACKUP_DIR/rancher/rancher-logs.txt" 2>/dev/null || true

    # Informations sur la version Rancher
    sudo docker exec rancher-server rancher --version > "$BACKUP_DIR/rancher/rancher-version.txt" 2>/dev/null || echo "Rancher version not available" > "$BACKUP_DIR/rancher/rancher-version.txt"

    echo "   Rancher sauvegarde (/opt/rancher + container config)"
else
    echo "   Rancher non installe (skip)"
    echo "none" > "$BACKUP_DIR/rancher/rancher-not-installed.txt"
fi

# CREER UN FICHIER DE METADATA
cat > "$BACKUP_DIR/backup-info.txt" <<EOF

BACKUP INFORMATION


Date: $(date)
Timestamp: $TIMESTAMP
Backup Location: $BACKUP_DIR

CLUSTER STATE:
$(kubectl get nodes 2>/dev/null || echo "Cluster not accessible")

DRUPAL PODS:
$(kubectl get pods -n drupal 2>/dev/null || echo "Drupal namespace not accessible")

BACKUP CONTENTS:
- etcd snapshot: $(ls -lh $BACKUP_DIR/etcd/ 2>/dev/null || echo "None")
- MySQL dump: $(ls -lh $BACKUP_DIR/mysql/ 2>/dev/null || echo "None")
- Drupal files: $(ls -lh $BACKUP_DIR/drupal-files/ 2>/dev/null || echo "None")
- Manifests: $(ls $BACKUP_DIR/manifests/ 2>/dev/null | wc -l) files
- Secrets: $(ls $BACKUP_DIR/secrets/ 2>/dev/null | wc -l) files
- Config (Ansible/SSH): $(ls $BACKUP_DIR/config/ 2>/dev/null | wc -l) items
- Rancher: $(ls -lh $BACKUP_DIR/rancher/*.tar.gz 2>/dev/null || echo "Not installed")

TOTAL SIZE: $(du -sh $BACKUP_DIR | cut -f1)

RECOVERY:
To restore this backup:
  cd /home/formation/k8s-infra
  ./restore.sh $TIMESTAMP


EOF

# CLEANUP: Garder seulement les 7 derniers backups
echo ""
echo "Nettoyage des anciens backups (retention: 7 jours)..."
cd "$BACKUP_ROOT"
ls -t | tail -n +8 | xargs -r rm -rf
REMAINING=$(ls -1 | wc -l)
echo "   Backups restants: $REMAINING"

# RESUME
BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
echo ""
echo ""
echo "          BACKUP TERMINE                                "
echo ""
echo ""
echo "Location: $BACKUP_DIR"
echo "Size: $BACKUP_SIZE"
echo "Retention: 7 jours"
echo ""
echo "Contenu:"
echo "  - Etcd snapshot (etat cluster K3s)"
echo "  - MySQL dump (toutes les bases)"
echo "  - Drupal files (PVC)"
echo "  - Manifests Kubernetes"
echo "  - Secrets (vault.yml + .vault_password)"
echo "  - Config Ansible/SSH (inventory, playbooks, cles SSH)"
if [ -f "$BACKUP_DIR/rancher/rancher-data-$TIMESTAMP.tar.gz" ]; then
    echo "  - Rancher (/opt/rancher + config Docker)"
else
    echo "  - Rancher (non installe)"
fi
echo ""
echo "Pour restaurer:"
echo "  $HOME/k8s-infra/restore.sh $TIMESTAMP"
echo ""
