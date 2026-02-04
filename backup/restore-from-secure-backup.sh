#!/bin/bash
# Restore complet depuis un backup SECURISE (GPG encrypted)
# Reconstruit le cluster K3s et restaure toutes les donnees
# Compatible avec backup-to-k8s-orchestrator-secure.sh
# Usage: ./restore-from-secure-backup.sh [timestamp]

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
ENV_FILE_SSH_PASSWORD="${SSH_PASSWORD:-${ENV_FILE_SSH_PASSWORD:-}}"

BACKUP_ROOT="/opt/k8s-backups"
TIMESTAMP=${1:-$(ls -t $BACKUP_ROOT 2>/dev/null | head -1)}
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"
TEMP_DECRYPT_DIR="/tmp/k8s-restore-decrypt-$$"

if [ ! -d "$BACKUP_DIR" ]; then
    echo " Backup introuvable: $BACKUP_DIR"
    echo ""
    echo "Backups disponibles:"
    ls -lt $BACKUP_ROOT 2>/dev/null | grep ^d || echo "Aucun backup trouve"
    exit 1
fi

# Verifier que GPG est disponible
if ! command -v gpg &> /dev/null; then
    echo " GPG non installe!"
    echo "   Installer avec: sudo apt install gnupg"
    exit 1
fi

# Verifier que la cle GPG est disponible
GPG_RECIPIENT="${GPG_BACKUP_KEY:-backup@example.com}"
if ! gpg --list-keys "$GPG_RECIPIENT" &>/dev/null; then
    echo " Cle GPG $GPG_RECIPIENT introuvable!"
    echo ""
    echo "Pour restaurer, importer d'abord la cle privee GPG:"
    echo "  gpg --import backup-private.key"
    echo ""
    echo "Puis faire confiance a la cle:"
    echo "  gpg --edit-key $GPG_RECIPIENT"
    echo "  gpg> trust"
    echo "  gpg> 5 (ultimate)"
    echo "  gpg> quit"
    exit 1
fi

echo ""
echo "   RESTORE DEPUIS BACKUP SECURISE (GPG Encrypted)      "
echo ""
echo ""
echo "Backup: $TIMESTAMP"
echo "Source: $BACKUP_DIR"
echo "GPG Key: $GPG_RECIPIENT"
echo ""
cat "$BACKUP_DIR/backup-info.txt" 2>/dev/null || true
echo ""

# Verifier l'integrite des checksums
if [ -f "$BACKUP_DIR/checksums/SHA256SUMS" ]; then
    echo "Verification integrite (checksums)..."
    cd "$BACKUP_DIR"
    if sha256sum -c checksums/SHA256SUMS --quiet 2>/dev/null; then
        echo "   Checksums valides"
    else
        echo "    ATTENTION: Checksums invalides detectes!"
        read -p "Continuer malgre les erreurs de checksum? (yes/no): " checksum_confirm
        if [ "$checksum_confirm" != "yes" ]; then
            echo "Restauration annulee."
            exit 1
        fi
    fi
fi

echo ""
read -p "  Continuer la restauration? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Annule."
    exit 0
fi

START_TIME=$(date +%s)

# Creer repertoire temporaire pour dechiffrement
mkdir -p "$TEMP_DECRYPT_DIR"
trap "rm -rf $TEMP_DECRYPT_DIR" EXIT

# Fonction de dechiffrement GPG
decrypt_file() {
    local encrypted_file="$1"
    local output_file="$2"

    if [ ! -f "$encrypted_file" ]; then
        echo "    Fichier non trouve: $encrypted_file"
        return 1
    fi

    echo "  Dechiffrement $(basename $encrypted_file)..."
    gpg --decrypt --batch --yes --quiet "$encrypted_file" > "$output_file" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo "     Dechiffre: $(du -h $output_file | cut -f1)"
        return 0
    else
        echo "     Erreur dechiffrement"
        return 1
    fi
}

# PHASE 1: Restaurer les secrets et configuration
echo ""
echo " PHASE 1/7: Dechiffrement & Restauration Configuration "

echo "[1/6] Verification .vault_password..."
if [ -f "$BACKUP_DIR/secrets/vault-password-location.txt" ]; then
    cat "$BACKUP_DIR/secrets/vault-password-location.txt"
    echo ""
    echo "  .vault_password n'est PAS dans le backup (securite)"
    echo ""
    read -p "Avez-vous recupere .vault_password depuis votre Password Manager? (yes/no): " vault_pwd_confirm

    if [ "$vault_pwd_confirm" != "yes" ]; then
        echo ""
        echo " .vault_password requis pour continuer!"
        echo "   1. Ouvrir Password Manager (1Password, Bitwarden, etc.)"
        echo "   2. Recuperer 'Ansible Vault Password'"
        echo "   3. echo 'password' > $HOME/k8s-infra/ansible/.vault_password"
        echo "   4. chmod 600 $HOME/k8s-infra/ansible/.vault_password"
        exit 1
    fi

    # Verifier que .vault_password existe localement
    if [ ! -f "$HOME/k8s-infra/ansible/.vault_password" ]; then
        echo ""
        read -p "Entrer le mot de passe Ansible Vault: " -s vault_password
        echo ""
        mkdir -p "$HOME/k8s-infra/ansible"
        echo "$vault_password" > "$HOME/k8s-infra/ansible/.vault_password"
        chmod 600 "$HOME/k8s-infra/ansible/.vault_password"
        echo "   .vault_password cree"
    else
        echo "   .vault_password deja present localement"
    fi
fi

echo "[2/6] Restauration vault.yml (deja chiffre avec Ansible Vault)..."
mkdir -p "$HOME/k8s-infra/ansible/inventory/group_vars"
cp "$BACKUP_DIR/secrets/vault.yml" \
  "$HOME/k8s-infra/ansible/inventory/group_vars/vault.yml"
echo "   vault.yml restaure"

echo "[3/6] Dechiffrement kubeconfig.yaml..."
if [ -f "$BACKUP_DIR/secrets/kubeconfig.yaml.gpg" ]; then
    mkdir -p "$HOME/k8s-infra/ansible"
    decrypt_file "$BACKUP_DIR/secrets/kubeconfig.yaml.gpg" \
                 "$HOME/k8s-infra/ansible/kubeconfig.yaml"
else
    echo "    kubeconfig.yaml.gpg non trouve (sera regenere par Ansible)"
fi

echo "[4/6] Restauration inventory Ansible..."
if [ -d "$BACKUP_DIR/config/inventory" ]; then
    cp -r "$BACKUP_DIR/config/inventory" "$HOME/k8s-infra/ansible/"
    echo "   Inventory restaure"
fi

echo "[5/6] Restauration ansible.cfg et playbooks..."
if [ -f "$BACKUP_DIR/config/ansible.cfg" ]; then
    cp "$BACKUP_DIR/config/ansible.cfg" "$HOME/k8s-infra/ansible/"
fi
if [ -d "$BACKUP_DIR/config/playbooks" ]; then
    cp -r "$BACKUP_DIR/config/playbooks" "$HOME/k8s-infra/ansible/" 2>/dev/null || true
fi
echo "   Configuration Ansible restauree"

echo "[6/6] Dechiffrement cles SSH..."
if [ -f "$BACKUP_DIR/config/id_rsa.gpg" ]; then
    mkdir -p ~/.ssh
    decrypt_file "$BACKUP_DIR/config/id_rsa.gpg" ~/.ssh/id_rsa
    chmod 600 ~/.ssh/id_rsa

    # Cle publique (non chiffree)
    if [ -f "$BACKUP_DIR/config/id_rsa.pub" ]; then
        cp "$BACKUP_DIR/config/id_rsa.pub" ~/.ssh/
        chmod 644 ~/.ssh/id_rsa.pub
    fi
fi

if [ -f "$BACKUP_DIR/config/known_hosts" ]; then
    cp "$BACKUP_DIR/config/known_hosts" ~/.ssh/
fi

echo "   Configuration complete restauree (vault, SSH, Ansible)"

# PHASE 2: Dechiffrer etcd snapshot
echo ""
echo " PHASE 2/7: Dechiffrement Etcd Snapshot "

ETCD_ENCRYPTED=$(ls -t $BACKUP_DIR/etcd/*.gpg 2>/dev/null | head -1)
if [ -f "$ETCD_ENCRYPTED" ]; then
    ETCD_DECRYPTED="$TEMP_DECRYPT_DIR/etcd-snapshot"
    decrypt_file "$ETCD_ENCRYPTED" "$ETCD_DECRYPTED"
else
    echo "    Etcd snapshot non trouve"
fi

# PHASE 3: Reconstruire le cluster K3s
echo ""
echo " PHASE 3/7: Reconstruction Cluster K3s "
cd "$HOME/k8s-infra/ansible"

export KUBECONFIG="$HOME/k8s-infra/ansible/kubeconfig.yaml"

# Verifier si un cluster K3s existe deja
if kubectl get nodes &>/dev/null; then
    echo "  Cluster K3s detecte. Options:"
    echo "  1) Conserver le cluster existant (idempotent)"
    echo "  2) Detruire et reconstruire (perte de donnees actuelles)"
    read -p "Choix (1/2): " choice

    if [ "$choice" = "2" ]; then
        echo "Destruction cluster existant..."
        ansible k3s_workers -m shell -a "/usr/local/bin/k3s-agent-uninstall.sh" 2>/dev/null || true
        ansible k3s_master -m shell -a "/usr/local/bin/k3s-uninstall.sh" 2>/dev/null || true
        sleep 10

        echo "Bootstrap nouveau cluster K3s..."
        ansible-playbook playbooks/00-bootstrap-k3s.yml

        # Restaurer etcd snapshot si disponible
        if [ -f "$ETCD_DECRYPTED" ]; then
            echo "Restauration etcd snapshot..."
            scp "$ETCD_DECRYPTED" "${SSH_USER}@k8s-master-1.example.com:/tmp/etcd-restore"
            ssh "${SSH_USER}@k8s-master-1.example.com" \
              "sudo k3s server --cluster-reset --cluster-reset-restore-path=/tmp/etcd-restore" || \
              echo "    Restauration etcd manuelle requise"
        fi

        echo "   Cluster K3s reconstruit"
    else
        echo "   Cluster K3s existant conserve"
    fi
else
    echo "Aucun cluster detecte, bootstrap nouveau cluster K3s..."
    ansible-playbook playbooks/00-bootstrap-k3s.yml
    echo "   Cluster K3s cree"
fi

# PHASE 4: Restaurer l'infrastructure
echo ""
echo " PHASE 4/7: Restauration Infrastructure "

echo "Deploiement infrastructure..."
ansible-playbook playbooks/01-deploy-infrastructure.yml

echo "Configuration securite..."
ansible-playbook playbooks/03-configure-security.yml

echo "   Infrastructure restauree"

# PHASE 5: Dechiffrer et restaurer les donnees applicatives
echo ""
echo " PHASE 5/7: Dechiffrement & Restauration Donnees "

# Attendre que les pods MySQL soient prets
echo "[1/3] Attente pods MySQL..."
kubectl wait --for=condition=ready pod -l app=mysql -n drupal --timeout=300s

# Dechiffrer MySQL dump
echo "[2/3] Dechiffrement et restauration MySQL..."
MYSQL_ENCRYPTED=$(ls -t $BACKUP_DIR/mysql/*.gpg 2>/dev/null | head -1)

if [ -f "$MYSQL_ENCRYPTED" ]; then
    MYSQL_DECRYPTED="$TEMP_DECRYPT_DIR/mysql-dump.sql.gz"
    decrypt_file "$MYSQL_ENCRYPTED" "$MYSQL_DECRYPTED"

    MYSQL_POD=$(kubectl get pod -n drupal -l app=mysql -o jsonpath='{.items[0].metadata.name}')

    # Verifier si la base contient deja des donnees
    DRUPAL_DB_EXISTS=$(kubectl exec -n drupal $MYSQL_POD -- bash -c \
      "MYSQL_PWD=\$(cat /run/secrets/mysql-secret/mysql-root-password) mysql -u root -e 'SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME=\"drupal\"' -sN" 2>/dev/null || echo "0")

    if [ "$DRUPAL_DB_EXISTS" -gt "0" ]; then
        echo "    Base Drupal existante detectee. Options:"
        echo "    1) Conserver les donnees existantes (idempotent)"
        echo "    2) Ecraser avec le backup (perte donnees actuelles)"
        read -p "  Choix (1/2): " mysql_choice

        if [ "$mysql_choice" = "2" ]; then
            kubectl cp "$MYSQL_DECRYPTED" drupal/$MYSQL_POD:/tmp/restore.sql.gz
            kubectl exec -n drupal $MYSQL_POD -- bash -c \
              "gunzip < /tmp/restore.sql.gz | MYSQL_PWD=\$(cat /run/secrets/mysql-secret/mysql-root-password) mysql -u root"
            echo "   MySQL restaure depuis backup dechiffre"
        else
            echo "   Donnees MySQL existantes conservees"
        fi
    else
        kubectl cp "$MYSQL_DECRYPTED" drupal/$MYSQL_POD:/tmp/restore.sql.gz
        kubectl exec -n drupal $MYSQL_POD -- bash -c \
          "gunzip < /tmp/restore.sql.gz | MYSQL_PWD=\$(cat /run/secrets/mysql-secret/mysql-root-password) mysql -u root"
        echo "   MySQL restaure depuis backup dechiffre"
    fi
else
    echo "    Dump MySQL chiffre non trouve"
fi

# Dechiffrer et restaurer Drupal files
echo "[3/3] Dechiffrement et restauration fichiers Drupal..."
DRUPAL_ENCRYPTED=$(ls -t $BACKUP_DIR/drupal-files/*.gpg 2>/dev/null | head -1)

if [ -f "$DRUPAL_ENCRYPTED" ]; then
    DRUPAL_DECRYPTED="$TEMP_DECRYPT_DIR/drupal-files.tar.gz"
    decrypt_file "$DRUPAL_ENCRYPTED" "$DRUPAL_DECRYPTED"

    DRUPAL_POD=$(kubectl get pod -n drupal -l app=drupal -o jsonpath='{.items[0].metadata.name}')

    if [ -n "$DRUPAL_POD" ]; then
        kubectl cp "$DRUPAL_DECRYPTED" drupal/$DRUPAL_POD:/tmp/files.tar.gz
        kubectl exec -n drupal $DRUPAL_POD -- \
          tar xzf /tmp/files.tar.gz -C /var/www/html/sites/default/files/
        echo "   Fichiers Drupal restaures depuis backup dechiffre"
    fi
else
    echo "    Fichiers Drupal chiffres non trouves"
fi

# PHASE 6: Restaurer Velero
echo ""
echo " PHASE 6/7: Configuration Velero & Backups "

ansible-playbook playbooks/02-configure-velero-backups.yml

# PHASE 7: Restaurer Rancher (si present dans backup)
echo ""
echo " PHASE 7/7: Restauration Rancher (sur k8s-orchestrator) "

RANCHER_ENCRYPTED=$(ls -t $BACKUP_DIR/rancher/*.gpg 2>/dev/null | head -1)

if [ -f "$RANCHER_ENCRYPTED" ]; then
    echo "  - Backup Rancher chiffre detecte"

    # Verifier si Rancher est deja running
    if sudo docker ps 2>/dev/null | grep -q rancher-server; then
        echo "    Rancher container actif detecte. Options:"
        echo "    1) Conserver Rancher existant (idempotent)"
        echo "    2) Restaurer depuis backup (perte configuration actuelle)"
        read -p "  Choix (1/2): " rancher_choice

        if [ "$rancher_choice" != "2" ]; then
            echo "   Rancher existant conserve"
            SKIP_RANCHER_RESTORE=true
        fi
    fi

    if [ "${SKIP_RANCHER_RESTORE:-false}" = "false" ]; then
        # Dechiffrer Rancher data
        RANCHER_DECRYPTED="$TEMP_DECRYPT_DIR/rancher-data.tar.gz"
        decrypt_file "$RANCHER_ENCRYPTED" "$RANCHER_DECRYPTED"

        # Arreter Rancher container s'il existe
        if sudo docker ps -a 2>/dev/null | grep -q rancher-server; then
            echo "    Arret container Rancher existant..."
            sudo docker stop rancher-server 2>/dev/null || true
            sudo docker rm rancher-server 2>/dev/null || true
        fi

        # Restaurer les donnees Rancher
        if [ -d "/opt/rancher" ]; then
            echo "    Sauvegarde ancien /opt/rancher..."
            find /opt -maxdepth 1 -name "rancher.old.*" -type d -mtime +7 -exec sudo rm -rf {} \; 2>/dev/null || true
            sudo mv /opt/rancher /opt/rancher.old.$(date +%Y%m%d-%H%M%S) 2>/dev/null || true
        fi

        echo "    Extraction backup Rancher dechiffre..."
        sudo tar xzf "$RANCHER_DECRYPTED" -C /opt/ 2>/dev/null || echo "    Erreur extraction Rancher"

        # Recuperer la config du container
        if [ -f "$BACKUP_DIR/rancher/rancher-container-config.json" ]; then
            RANCHER_VERSION=$(jq -r '.[0].Config.Image' "$BACKUP_DIR/rancher/rancher-container-config.json" 2>/dev/null || echo "rancher/rancher:latest")
            echo "    Version Rancher: $RANCHER_VERSION"

            # Redemarrer Rancher
            echo "    Redemarrage container Rancher..."
            sudo docker run -d \
              --name rancher-server \
              --restart=unless-stopped \
              -p 80:80 -p 443:443 \
              -v /opt/rancher:/var/lib/rancher \
              --privileged \
              $RANCHER_VERSION

            echo "   Rancher restaure depuis backup dechiffre"
            sleep 30

            if sudo docker ps | grep -q rancher-server; then
                echo "   Rancher operationnel"
            else
                echo "    Rancher container non running, verifier:"
                echo "     sudo docker logs rancher-server"
            fi
        fi
    fi
else
    echo "    Pas de backup Rancher trouve (skip)"
fi

# PHASE 8: Verification
echo ""
echo " PHASE 8/8: Verification "

sleep 30

echo ""
echo "Nodes:"
kubectl get nodes

echo ""
echo "Drupal:"
kubectl get pods -n drupal

echo ""
echo "Monitoring:"
kubectl get pods -n monitoring | grep -E "prometheus|grafana|alertmanager" || true

# Calcul temps de recuperation
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo ""
echo ""
echo "     RESTAURATION SECURISEE TERMINEE                    "
echo ""
echo ""
echo "Temps de recuperation: ${MINUTES}m ${SECONDS}s"
echo "Fichiers dechiffres: $(ls -1 $TEMP_DECRYPT_DIR 2>/dev/null | wc -l)"
echo ""
echo "Securite:"
echo "   Backups dechiffres avec GPG"
echo "   .vault_password recupere depuis Password Manager"
echo "   Checksums verifies"
echo "   Fichiers temporaires nettoyes automatiquement"
echo ""
echo "Services:"
echo "  Drupal:      http://k8s-master-1.example.com:30080"
echo "  Grafana:     http://k8s-master-1.example.com:30300"
echo "  Prometheus:  http://k8s-master-1.example.com:30090"
if sudo docker ps 2>/dev/null | grep -q rancher-server; then
    echo "  Rancher:     https://k8s-orchestrator.example.com"
fi
echo ""
echo "Verifications:"
echo "  1. Tester acces Drupal et verifier contenu"
echo "  2. Verifier replication MySQL:"
echo "     kubectl exec -it mysql-0 -n drupal -- mysql -u root -p"
echo "  3. Creer nouveau backup securise:"
echo "     $HOME/k8s-infra/backup/backup-to-k8s-orchestrator-secure.sh"
echo ""
echo "  IMPORTANT:"
echo "  - Fichiers dechiffres dans $TEMP_DECRYPT_DIR seront supprimes a la sortie"
echo "  - Conserver cle GPG privee dans Password Manager"
echo "  - Conserver .vault_password dans Password Manager"
echo ""
