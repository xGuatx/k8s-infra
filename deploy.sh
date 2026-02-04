#!/bin/bash
# Script de deploiement initial complet - 100% AUTOMATIQUE
# A executer depuis k8s-orchestrator pour deployer toute l'infrastructure
# IDEMPOTENT - Peut etre execute plusieurs fois sans casser

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Charger les variables locales si disponibles (.env.tmp)
ENV_FILE_SSH_PASSWORD=""
ENV_FILE_SSH_USER=""
ENV_FILE_SUDO_PASSWORD=""
ENV_FILE="$SCRIPT_DIR/.env.tmp"
if [ -f "$ENV_FILE" ]; then
    while IFS='=' read -r key value; do
        case "$key" in
            SSH_PASSWORD|PWD) ENV_FILE_SSH_PASSWORD="$value" ;;
            SSH_USER|USER) ENV_FILE_SSH_USER="$value" ;;
            SUDO_PASSWORD) ENV_FILE_SUDO_PASSWORD="$value" ;;
            *) ;; 
        esac
    done < "$ENV_FILE"
fi

SSH_USER="${SSH_USER:-${ENV_FILE_SSH_USER:-${USER:-formation}}}"
CURRENT_SSH_PASSWORD="${SSH_PASSWORD:-${ENV_FILE_SSH_PASSWORD:-}}"
SUDO_PASSWORD="${SUDO_PASSWORD:-${ENV_FILE_SUDO_PASSWORD:-}}"

if [ -z "$CURRENT_SSH_PASSWORD" ]; then
    echo " Variable SSH_PASSWORD non definie (utiliser export SSH_PASSWORD=... ou renseigner .env.tmp)."
    exit 1
fi

if [ -z "$SUDO_PASSWORD" ]; then
    echo " Variable SUDO_PASSWORD non definie (utiliser export SUDO_PASSWORD=... ou renseigner .env.tmp)."
    exit 1
fi

export SSH_USER CURRENT_SSH_PASSWORD SUDO_PASSWORD

# Options (modifiables via variables d'environnement)
ENABLE_TLS="${ENABLE_TLS:-false}"           # true pour activer HTTPS
USE_TLS_STAGING="${USE_TLS_STAGING:-true}"  # true pour Let's Encrypt staging (test)
INSTALL_RANCHER="${INSTALL_RANCHER:-false}" # true pour installer Rancher sur k8s-orchestrator

echo ""
echo "   DEPLOIEMENT AUTOMATIQUE INFRASTRUCTURE K3S           "
echo ""
echo ""
echo "Ce script va TOUT installer automatiquement:"
echo "  1. Prerequis (Ansible, Helm, kubectl, etc.)"
echo "  2. Secrets (generation automatique)"
echo "  3. Cluster K3s (k8s-master-1-15)"
echo "  4. Infrastructure (Longhorn, Drupal, monitoring)"
echo "  5. Securite (Network Policies, RBAC, TLS)"
echo "  6. Velero (backups Kubernetes)"
echo "  7. Ingress + Publication services"
echo "  8. Monitoring complet (Dashboards Grafana)"
echo "  9. Backups automatiques quotidiens"
echo " 10. Premier backup"
if [ "$INSTALL_RANCHER" = "true" ]; then
echo " 11. Rancher sur k8s-orchestrator"
fi
echo ""
echo "Options:"
echo "  TLS/HTTPS: $ENABLE_TLS $([ "$ENABLE_TLS" = "true" ] && echo "(Mode: $([ "$USE_TLS_STAGING" = "true" ] && echo "Staging/Test" || echo "Production"))" || echo "")"
echo "  Rancher: $INSTALL_RANCHER"
echo ""
echo " Pour changer les options:"
echo "   ENABLE_TLS=true USE_TLS_STAGING=false ./deploy.sh"
echo "   INSTALL_RANCHER=true ./deploy.sh"
echo ""
echo "  IMPORTANT: Ce script est IDEMPOTENT"
echo "   Il peut etre execute plusieurs fois sans casser k8s-orchestrator"
echo ""
echo "Duree estimee: 40-45 minutes"
echo ""
echo "Demarrage dans 5 secondes... (Ctrl+C pour annuler)"
sleep 5

START_TIME=$(date +%s)

# 
# PHASE 0: INSTALLATION PREREQUIS (IDEMPOTENT)
# 
echo ""
echo " PHASE 0/10: Installation Prerequis "

chmod +x "$SCRIPT_DIR/scripts/install-prerequisites.sh"
"$SCRIPT_DIR/scripts/install-prerequisites.sh"

# 
# PHASE 1: INITIALISATION SECRETS AUTOMATIQUE (IDEMPOTENT)
# 
echo ""
echo " PHASE 1/10: Initialisation Secrets "

if [ -f "$SCRIPT_DIR/ansible/.vault_password" ]; then
    echo "  Les secrets existent deja. Utilisation des secrets existants."
    echo "   Deploiement idempotent - secrets preserves"
else
    echo "Generation automatique des secrets..."

    # Generer vault password
    VAULT_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
    echo "$VAULT_PASSWORD" > "$SCRIPT_DIR/ansible/.vault_password"
    chmod 600 "$SCRIPT_DIR/ansible/.vault_password"

    # Generer passwords forts
    gen_password() {
        openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
    }

    MYSQL_ROOT_PASSWORD=$(gen_password)
    MYSQL_USER_PASSWORD=$(gen_password)
    MYSQL_REPLICATION_PASSWORD=$(gen_password)
    GRAFANA_ADMIN_PASSWORD=$(gen_password)
    MINIO_SECRET_KEY=$(gen_password)
    K3S_ENCRYPTION_KEY=$(openssl rand -base64 32 | tr -d '\n')

    # Creer vault.yml (sans vault_ansible_password car utilisation cles SSH)
    cat > "$SCRIPT_DIR/ansible/inventory/group_vars/vault.yml" <<EOF
---
# Encrypted secrets - Managed by Ansible Vault
# Note: vault_ansible_password non necessaire (cles SSH utilisees)
vault_ansible_become_password: "$CURRENT_SSH_PASSWORD"
vault_mysql_root_password: "$MYSQL_ROOT_PASSWORD"
vault_mysql_user: "drupal"
vault_mysql_password: "$MYSQL_USER_PASSWORD"
vault_mysql_database: "drupal"
vault_mysql_replication_password: "$MYSQL_REPLICATION_PASSWORD"
vault_grafana_admin_password: "$GRAFANA_ADMIN_PASSWORD"
vault_minio_access_key: "minio"
vault_minio_secret_key: "$MINIO_SECRET_KEY"
vault_velero_aws_access_key_id: "minio"
vault_velero_aws_secret_access_key: "$MINIO_SECRET_KEY"
vault_k3s_encryption_key: "$K3S_ENCRYPTION_KEY"
EOF

    # Copier vault.yml vers le repertoire orchestration avant chiffrement
    mkdir -p "$SCRIPT_DIR/ansible/inventory/group_vars/orchestration"
    cp "$SCRIPT_DIR/ansible/inventory/group_vars/vault.yml" \
        "$SCRIPT_DIR/ansible/inventory/group_vars/orchestration/vault.yml"

    # Chiffrer les deux vault files
    ansible-vault encrypt "$SCRIPT_DIR/ansible/inventory/group_vars/vault.yml" \
        --vault-password-file="$SCRIPT_DIR/ansible/.vault_password"
    ansible-vault encrypt "$SCRIPT_DIR/ansible/inventory/group_vars/orchestration/vault.yml" \
        --vault-password-file="$SCRIPT_DIR/ansible/.vault_password"

    # Creer fichier credentials avec instructions IMPORTANTES
    cat > "$SCRIPT_DIR/CREDENTIALS.txt" <<EOF

              CREDENTIALS GENERES                       


  IMPORTANT - PROCEDURE DE SAUVEGARDE SECURISEE:

1. Copier ce fichier dans KeePass/1Password/Bitwarden
2. Sauvegarder la cle GPG privee (si generee)
3. SUPPRIMER ce fichier apres sauvegarde:
   rm $SCRIPT_DIR/CREDENTIALS.txt

Ce fichier contient TOUS les secrets du cluster.
Ne JAMAIS commiter dans git ou laisser sur le serveur.



ANSIBLE VAULT PASSWORD:
$VAULT_PASSWORD

SSH ACCESS (formation user):
Password: $CURRENT_SSH_PASSWORD

MYSQL ROOT:
User: root
Password: $MYSQL_ROOT_PASSWORD

MYSQL DRUPAL:
User: drupal
Database: drupal
Password: $MYSQL_USER_PASSWORD

GRAFANA:
User: admin
Password: $GRAFANA_ADMIN_PASSWORD

MINIO (Backup Storage):
Access Key: minio
Secret Key: $MINIO_SECRET_KEY


Genere le: $(date)


INSTRUCTIONS DISASTER RECOVERY:

Si vous perdez le cluster (k8s-master-1-15):
1. Recuperer .vault_password depuis KeePass/Password Manager
2. Recuperer cle GPG privee depuis KeePass
3. Executer: ./restore.sh [timestamp]
4. Le restore dechiffrera automatiquement les backups GPG

Sans .vault_password ET cle GPG privee: Impossible de restaurer!

EOF

    chmod 600 "$SCRIPT_DIR/CREDENTIALS.txt"

    echo "   Secrets generes et chiffres"
    echo "   CREDENTIALS.txt cree"
    echo ""
    echo "    CRITIQUE: Sauvegarder CREDENTIALS.txt dans KeePass MAINTENANT"
    echo "     Ce fichier sera AUTO-SUPPRIME dans 5 minutes pour securite"
    echo ""

    # Auto-delete CREDENTIALS.txt apres 5 minutes (securite)
    (sleep 300 && rm -f "$SCRIPT_DIR/CREDENTIALS.txt" && \
     echo " CREDENTIALS.txt auto-supprime pour securite" || true) &

    echo "  Timer de suppression active (5 minutes)"
fi

# 
# PHASE 2: CONFIGURATION CLES SSH (SECURITE)
# 
echo ""
echo " PHASE 2/10: Configuration Cles SSH "

# Verifier si cles SSH deja configurees
if [ ! -f ~/.ssh/id_rsa ] || ! ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=no \
    -o ConnectTimeout=2 "${SSH_USER}@k8s-master-1.example.com" "hostname" &>/dev/null; then
    echo "Configuration des cles SSH pour authentification securisee..."
    chmod +x "$SCRIPT_DIR/scripts/setup-ssh-keys.sh"
    SSH_PASSWORD="$CURRENT_SSH_PASSWORD" SSH_USER="$SSH_USER" "$SCRIPT_DIR/scripts/setup-ssh-keys.sh"
else
    echo "   Cles SSH deja configurees (authentification sans mot de passe)"
fi

# 
# PHASE 2B: CONFIGURATION NOPASSWD SUDO
# 
echo ""
echo " PHASE 2B/10: Configuration NOPASSWD Sudo "

chmod +x "$SCRIPT_DIR/scripts/setup-nopasswd-sudo.sh"
SSH_PASSWORD="$CURRENT_SSH_PASSWORD" SUDO_PASSWORD="$SUDO_PASSWORD" "$SCRIPT_DIR/scripts/setup-nopasswd-sudo.sh"

# 
# PHASE 3: TEST CONNECTIVITE ANSIBLE
# 
echo ""
echo " PHASE 3/10: Test Connectivite Ansible "

cd "$SCRIPT_DIR/ansible"

echo "Test connexion aux nuds du cluster..."
if ! ansible k3s_cluster -m ping > /dev/null 2>&1; then
    echo " Impossible de se connecter aux nuds"
    echo "   Verifier la connectivite reseau et les cles SSH"
    exit 1
fi
echo "   Tous les nuds (k8s-master-1-15) accessibles via Ansible"

# 
# PHASE 4: DEPLOIEMENT CLUSTER K3S
# 
echo ""
echo " PHASE 4/10: Deploiement Cluster K3s "
echo "Installation K3s sur k8s-master-1 (master) et k8s-master-2-15 (workers)..."
echo "Duree estimee: ~8 minutes"
echo ""

ansible-playbook playbooks/00-bootstrap-k3s.yml

export KUBECONFIG="$SCRIPT_DIR/ansible/kubeconfig.yaml"

echo ""
echo "Cluster K3s operationnel:"
kubectl get nodes
echo ""

# 
# PHASE 4: DEPLOIEMENT INFRASTRUCTURE
# 
echo ""
echo " PHASE 4/10: Deploiement Infrastructure Complete "
echo "Duree estimee: ~20 minutes"
echo ""
echo "Deploiement en cours:"
echo "  - Longhorn (stockage distribue, replication 2x)"
echo "  - Cert-Manager (gestion TLS)"
echo "  - MySQL (3 replicas avec replication)"
echo "  - Drupal 10 (2 replicas)"
echo "  - Prometheus + Grafana + AlertManager"
echo ""

ansible-playbook playbooks/01-deploy-infrastructure.yml

# 
# PHASE 5: CONFIGURATION SECURITE
# 
echo ""
echo " PHASE 5/10: Configuration Securite "
echo "Duree estimee: ~3 minutes"
echo ""

ansible-playbook playbooks/03-configure-security.yml

# 
# PHASE 6: CONFIGURATION VELERO
# 
echo ""
echo " PHASE 6/10: Configuration Velero (Backups Kubernetes) "
echo "Duree estimee: ~5 minutes"
echo ""

ansible-playbook playbooks/02-configure-velero-backups.yml

# 
# PHASE 7: CONFIGURATION INGRESS + TLS
# 
echo ""
echo " PHASE 7/10: Configuration Ingress + Publication Services "
echo "Duree estimee: ~3 minutes"
echo ""

ansible-playbook playbooks/04-configure-ingress.yml \
  -e "enable_tls=$ENABLE_TLS" \
  -e "use_staging_tls=$USE_TLS_STAGING"

# 
# PHASE 7B: CONFIGURATION MONITORING DASHBOARDS
# 
echo ""
echo " PHASE 7B/11: Configuration Monitoring + Dashboards "
echo "Duree estimee: ~2 minutes"
echo ""
echo "Configuration:"
echo "  - MySQL Exporter + metriques"
echo "  - Grafana Dashboards (Cluster, MySQL, Drupal)"
echo "  - Prometheus ServiceMonitors"
echo ""

ansible-playbook playbooks/05-configure-monitoring-dashboards.yml



# 
# PHASE 7C: CONFIGURATION KUB DASHBOARD
# 
echo ""
echo " PHASE 7C/11: Configuration Kub Dashboards "
echo "Duree estimee: ~2 minutes"
echo ""

ansible-playbook playbooks/06-configure-kubernetes-dashboard.yml


# 
# PHASE 8: BACKUPS AUTOMATIQUES (IDEMPOTENT)
# 
echo ""
echo " PHASE 8/11: Configuration Backups Automatiques "

chmod +x "$SCRIPT_DIR/scripts/setup-automated-backups.sh"
"$SCRIPT_DIR/scripts/setup-automated-backups.sh"

# 
# PHASE 9: PREMIER BACKUP SECURISE
# 
echo ""
echo " PHASE 9/11: Creation Premier Backup Securise (GPG) "

# Verifier si GPG est configure
if ! gpg --list-keys "${GPG_BACKUP_KEY:-backup@example.com}" &>/dev/null; then
    echo "  Cle GPG non trouvee pour les backups securises"
    echo "   Generation automatique de la cle GPG..."

    # Generer cle GPG automatiquement pour backups
    GPG_EMAIL="${GPG_BACKUP_KEY:-backup@example.com}"
    GPG_PASSPHRASE=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)

    cat > /tmp/gpg-gen-key.conf <<EOF
%echo Generating GPG key for backups
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: K8s Backup
Name-Email: $GPG_EMAIL
Expire-Date: 0
Passphrase: $GPG_PASSPHRASE
%commit
%echo Done
EOF

    gpg --batch --gen-key /tmp/gpg-gen-key.conf
    rm -f /tmp/gpg-gen-key.conf

    # Exporter cle privee pour sauvegarde
    gpg --export-secret-keys --armor "$GPG_EMAIL" > "$SCRIPT_DIR/backup-gpg-private.key"
    chmod 600 "$SCRIPT_DIR/backup-gpg-private.key"

    # Ajouter passphrase GPG aux credentials
    cat >> "$SCRIPT_DIR/CREDENTIALS.txt" <<EOF

GPG BACKUP KEY:
Email: $GPG_EMAIL
Passphrase: $GPG_PASSPHRASE
Private Key: $SCRIPT_DIR/backup-gpg-private.key

  IMPORTANT: Sauvegarder backup-gpg-private.key dans Password Manager!
   Sans cette cle, impossible de restaurer les backups.
EOF

    echo "   Cle GPG generee"
    echo "   Cle privee sauvegardee: $SCRIPT_DIR/backup-gpg-private.key"
    echo "    SAUVEGARDER backup-gpg-private.key dans Password Manager!"
fi

chmod +x "$SCRIPT_DIR/backup/backup-to-k8s-orchestrator-secure.sh"
"$SCRIPT_DIR/backup/backup-to-k8s-orchestrator-secure.sh"

# 
# PHASE 10: INSTALLATION RANCHER (OPTIONNEL, IDEMPOTENT)
# 
if [ "$INSTALL_RANCHER" = "true" ]; then
    echo ""
    echo " PHASE 10/11: Installation Rancher sur k8s-orchestrator "
    echo "Duree estimee: ~5 minutes"
    echo ""

    chmod +x "$SCRIPT_DIR/scripts/install-rancher-on-k8s-orchestrator.sh"
    # Passer les options TLS a Rancher
    if [ "$ENABLE_TLS" = "true" ]; then
        if [ "$USE_TLS_STAGING" = "true" ]; then
            USE_LETSENCRYPT=true USE_STAGING=true "$SCRIPT_DIR/scripts/install-rancher-on-k8s-orchestrator.sh"
        else
            USE_LETSENCRYPT=true USE_STAGING=false "$SCRIPT_DIR/scripts/install-rancher-on-k8s-orchestrator.sh"
        fi
    else
        "$SCRIPT_DIR/scripts/install-rancher-on-k8s-orchestrator.sh"
    fi
else
    echo ""
    echo " PHASE 10/11: Rancher (Ignore) "
    echo "   Rancher non installe (INSTALL_RANCHER=false)"
    echo "  Pour installer Rancher:"
    echo "    INSTALL_RANCHER=true ./deploy.sh"
    echo "  Ou manuellement:"
    echo "    ./scripts/install-rancher-on-k8s-orchestrator.sh"
fi

# 
# RESUME FINAL
# 
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo ""
echo ""
echo "        DEPLOIEMENT TERMINE AVEC SUCCES !               "
echo ""
echo ""
echo "Temps total: ${MINUTES}m ${SECONDS}s"
echo ""
echo " CLUSTER KUBERNETES "
kubectl get nodes
echo ""
echo " SERVICES DEPLOYES "
echo ""

if [ "$ENABLE_TLS" = "true" ]; then
    echo "Drupal (HTTPS):"
    echo "  - https://k8s-master-1.example.com"
    echo "  - https://k8s-master-2.example.com"
    echo "  - https://k8s-master-3.example.com"
    echo ""
    echo "Grafana (HTTPS):"
    echo "  - https://grafana.example.com"
    echo "  Credentials: Voir $SCRIPT_DIR/CREDENTIALS.txt"
    echo ""
    if [ "$USE_TLS_STAGING" = "true" ]; then
        echo "  TLS en mode STAGING (certificats de test)"
        echo "   Pour production: ENABLE_TLS=true USE_TLS_STAGING=false ./deploy.sh"
    else
        echo " TLS en mode PRODUCTION (certificats valides)"
    fi
else
    echo "Drupal (HTTP via NodePort):"
    echo "  - http://k8s-master-1.example.com:30080"
    echo "  - http://k8s-master-2.example.com:30080"
    echo "  - http://k8s-master-3.example.com:30080"
    echo ""
    echo "Grafana (HTTP via Ingress):"
    echo "  - http://grafana.example.com:30080"
    echo "  Credentials: Voir $SCRIPT_DIR/CREDENTIALS.txt"
    echo ""
    echo " Pour activer HTTPS:"
    echo "   ENABLE_TLS=true USE_TLS_STAGING=true ./deploy.sh"
fi

echo ""
echo "Prometheus:"
echo "  URL: http://k8s-master-1.example.com:30090"
echo ""
echo "AlertManager:"
echo "  URL: http://k8s-master-1.example.com:30903"
echo ""
echo " MONITORING & DASHBOARDS "
echo ""
echo "Grafana Dashboards configures:"
echo "   K3s Cluster Overview (CPU, RAM, Disk par nud)"
echo "   MySQL Performance (Connections, Queries, Slow queries)"
echo "   Drupal Application (Pods, CPU, RAM, HTTP requests)"
echo ""
echo "Metriques collectees:"
echo "   Kubernetes (nodes, pods, namespaces)"
echo "   MySQL (via mysql-exporter sur port 9104)"
echo "   Drupal (ressources et etat des pods)"
echo "   Ingress Nginx (requests, latency, errors)"
echo ""

if [ "$INSTALL_RANCHER" = "true" ]; then
    echo "Rancher (sur k8s-orchestrator):"
    echo "  URL: https://k8s-orchestrator.example.com"
    echo "  Credentials: /tmp/rancher-credentials.txt"
    echo ""
fi

echo " BACKUPS "
echo ""
echo "Location: /opt/k8s-backups/"
echo "Schedule: Quotidien a 2h00 AM"
echo "Retention: 7 jours"
echo "Dernier backup: $(ls -t /opt/k8s-backups/ 2>/dev/null | head -1 || echo "Aucun")"
echo ""
echo " CREDENTIALS "
echo ""
echo "  IMPORTANT: Sauvegarder immediatement ces fichiers:"
echo "  1. $SCRIPT_DIR/CREDENTIALS.txt"
echo "  2. $SCRIPT_DIR/ansible/.vault_password"
echo ""
echo "Voir les credentials:"
echo "  cat $SCRIPT_DIR/CREDENTIALS.txt"
echo ""
echo " DISASTER RECOVERY "
echo ""
echo "Si k8s-master-1-15 sont perdus, restaurer avec:"
echo "  $SCRIPT_DIR/restore.sh"
echo ""
echo "Temps de recuperation: ~30 minutes"
echo ""
echo " HEALTH CHECK "
echo ""
kubectl get pods -A | grep -E "drupal|mysql|prometheus|grafana|longhorn" | head -15
echo ""
echo " RECONFIGURATION POSSIBLE "
echo ""
echo "Ce script est IDEMPOTENT. Vous pouvez:"
echo "  - Activer TLS: ENABLE_TLS=true ./deploy.sh"
echo "  - TLS Production: ENABLE_TLS=true USE_TLS_STAGING=false ./deploy.sh"
echo "  - Installer Rancher: INSTALL_RANCHER=true ./deploy.sh"
echo "  - Relancer sans risque: ./deploy.sh"
echo ""
echo ""
echo "   Infrastructure Production Ready !                  "
echo ""
echo ""
