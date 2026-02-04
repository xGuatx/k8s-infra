#!/bin/bash
# Restore complet depuis un backup k8s-orchestrator
# Detecte automatiquement si backup chiffre (GPG) ou non
# Reconstruit le cluster K3s et restaure toutes les donnees
# Usage: ./restore.sh [timestamp]

set -euo pipefail

BACKUP_ROOT="/opt/k8s-backups"
TIMESTAMP=${1:-$(ls -t $BACKUP_ROOT 2>/dev/null | head -1)}
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -d "$BACKUP_DIR" ]; then
    echo " Backup introuvable: $BACKUP_DIR"
    echo ""
    echo "Backups disponibles:"
    ls -lt $BACKUP_ROOT 2>/dev/null | grep ^d || echo "Aucun backup trouve"
    exit 1
fi

# Detecter si backup est chiffre (presence de fichiers .gpg)
GPG_FILES_COUNT=$(find "$BACKUP_DIR" -name "*.gpg" -type f | wc -l)

if [ "$GPG_FILES_COUNT" -gt 0 ]; then
    echo ""
    echo "   BACKUP CHIFFRE DETECTE (GPG)                         "
    echo ""
    echo ""
    echo "Ce backup contient $GPG_FILES_COUNT fichiers chiffres GPG"
    echo "Redirection vers script de restauration securisee..."
    echo ""

    # Utiliser le script de restore securise
    SECURE_RESTORE="$SCRIPT_DIR/backup/restore-from-secure-backup.sh"

    if [ -f "$SECURE_RESTORE" ]; then
        exec "$SECURE_RESTORE" "$TIMESTAMP"
    else
        echo " Script de restauration securisee introuvable:"
        echo "   $SECURE_RESTORE"
        exit 1
    fi
fi

echo ""
echo "   BACKUP NON CHIFFRE DETECTE (Legacy)                  "
echo ""
echo ""
echo "  Ce backup n'est PAS chiffre (ancienne version)"
echo "   Il est recommande d'utiliser les backups chiffres GPG"
echo ""

echo ""
echo "     RESTORE COMPLET DEPUIS BACKUP K8S16                "
echo ""
echo ""
echo "Backup: $TIMESTAMP"
echo "Source: $BACKUP_DIR"
echo ""
cat "$BACKUP_DIR/backup-info.txt" 2>/dev/null || true
echo ""
read -p "  Continuer la restauration? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Annule."
    exit 0
fi

START_TIME=$(date +%s)

# PHASE 1: Restaurer les secrets et configuration
echo ""
echo " PHASE 1/6: Restauration Configuration Complete "

echo "[1/5] Restauration vault.yml..."
mkdir -p "$HOME/k8s-infra/ansible/inventory/group_vars"
cp "$BACKUP_DIR/secrets/vault.yml" \
  "$HOME/k8s-infra/ansible/inventory/group_vars/vault.yml"

echo "[2/5] Restauration .vault_password..."
if [ -f "$BACKUP_DIR/secrets/.vault_password" ]; then
  cp "$BACKUP_DIR/secrets/.vault_password" \
    "$HOME/k8s-infra/ansible/.vault_password"
  chmod 600 "$HOME/k8s-infra/ansible/.vault_password"
else
  echo "    .vault_password absent du backup."
  if [ ! -f "$HOME/k8s-infra/ansible/.vault_password" ]; then
    read -p "   Entrer le mot de passe Ansible Vault: " -s restore_vault_password
    echo ""
    mkdir -p "$HOME/k8s-infra/ansible"
    echo "$restore_vault_password" > "$HOME/k8s-infra/ansible/.vault_password"
    chmod 600 "$HOME/k8s-infra/ansible/.vault_password"
    unset restore_vault_password
  else
    echo "   Utilisation du .vault_password existant"
  fi
fi

echo "[3/5] Restauration inventory Ansible..."
if [ -d "$BACKUP_DIR/config/inventory" ]; then
  cp -r "$BACKUP_DIR/config/inventory" "$HOME/k8s-infra/ansible/"
fi

echo "[4/5] Restauration ansible.cfg..."
if [ -f "$BACKUP_DIR/config/ansible.cfg" ]; then
  cp "$BACKUP_DIR/config/ansible.cfg" "$HOME/k8s-infra/ansible/"
fi

echo "[5/5] Restauration cles SSH..."
if [ -f "$BACKUP_DIR/config/id_rsa" ]; then
  mkdir -p ~/.ssh
  cp "$BACKUP_DIR/config/id_rsa" ~/.ssh/
  cp "$BACKUP_DIR/config/id_rsa.pub" ~/.ssh/
  chmod 600 ~/.ssh/id_rsa
  chmod 644 ~/.ssh/id_rsa.pub
fi

if [ -f "$BACKUP_DIR/config/known_hosts" ]; then
  cp "$BACKUP_DIR/config/known_hosts" ~/.ssh/
fi

echo "   Configuration restauree (vault, inventory, SSH)"

# PHASE 2: Reconstruire le cluster K3s
echo ""
echo " PHASE 2/6: Reconstruction Cluster K3s "
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
        echo "   Cluster K3s reconstruit"
    else
        echo "   Cluster K3s existant conserve"
    fi
else
    echo "Aucun cluster detecte, bootstrap nouveau cluster K3s..."
    ansible-playbook playbooks/00-bootstrap-k3s.yml
    echo "   Cluster K3s cree"
fi

# PHASE 3: Restaurer l'infrastructure (Longhorn, Cert-Manager, etc.)
echo ""
echo " PHASE 3/6: Restauration Infrastructure "

echo "Deploiement infrastructure..."
ansible-playbook playbooks/01-deploy-infrastructure.yml

echo "Configuration securite..."
ansible-playbook playbooks/03-configure-security.yml

echo "   Infrastructure restauree"

# PHASE 4: Restaurer les donnees applicatives
echo ""
echo " PHASE 4/6: Restauration Donnees "

# Attendre que les pods MySQL soient prets
echo "[1/3] Attente pods MySQL..."
kubectl wait --for=condition=ready pod -l app=mysql -n drupal --timeout=300s

# Restaurer MySQL
echo "[2/3] Restauration MySQL..."
MYSQL_POD=$(kubectl get pod -n drupal -l app=mysql -o jsonpath='{.items[0].metadata.name}')
MYSQL_DUMP=$(ls -t $BACKUP_DIR/mysql/*.sql.gz 2>/dev/null | head -1)

if [ -f "$MYSQL_DUMP" ]; then
    echo "  - Dump: $(basename $MYSQL_DUMP)"

    # Verifier si la base contient deja des donnees
    DRUPAL_DB_EXISTS=$(kubectl exec -n drupal $MYSQL_POD -- bash -c \
      "MYSQL_PWD=\$(cat /run/secrets/mysql-secret/mysql-root-password) mysql -u root -e 'SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME=\"drupal\"' -sN" 2>/dev/null || echo "0")

    if [ "$DRUPAL_DB_EXISTS" -gt "0" ]; then
        echo "    Base Drupal existante detectee. Options:"
        echo "    1) Conserver les donnees existantes (idempotent)"
        echo "    2) Ecraser avec le backup (perte donnees actuelles)"
        read -p "  Choix (1/2): " mysql_choice

        if [ "$mysql_choice" = "2" ]; then
            # Copier le dump dans le pod
            kubectl cp "$MYSQL_DUMP" drupal/$MYSQL_POD:/tmp/restore.sql.gz

            # Restaurer
            kubectl exec -n drupal $MYSQL_POD -- bash -c \
              "gunzip < /tmp/restore.sql.gz | MYSQL_PWD=\$(cat /run/secrets/mysql-secret/mysql-root-password) mysql -u root"

            echo "   MySQL restaure depuis backup"
        else
            echo "   Donnees MySQL existantes conservees"
        fi
    else
        # Aucune donnee existante, restaurer directement
        kubectl cp "$MYSQL_DUMP" drupal/$MYSQL_POD:/tmp/restore.sql.gz

        kubectl exec -n drupal $MYSQL_POD -- bash -c \
          "gunzip < /tmp/restore.sql.gz | MYSQL_PWD=\$(cat /run/secrets/mysql-secret/mysql-root-password) mysql -u root"

        echo "   MySQL restaure depuis backup"
    fi
else
    echo "   Pas de dump MySQL trouve"
fi

# Restaurer Drupal files
echo "[3/3] Restauration fichiers Drupal..."
DRUPAL_POD=$(kubectl get pod -n drupal -l app=drupal -o jsonpath='{.items[0].metadata.name}')
DRUPAL_FILES=$(ls -t $BACKUP_DIR/drupal-files/*.tar.gz 2>/dev/null | head -1)

if [ -f "$DRUPAL_FILES" ] && [ -n "$DRUPAL_POD" ]; then
    kubectl cp "$DRUPAL_FILES" drupal/$DRUPAL_POD:/tmp/files.tar.gz
    kubectl exec -n drupal $DRUPAL_POD -- \
      tar xzf /tmp/files.tar.gz -C /var/www/html/sites/default/files/
    echo "   Fichiers Drupal restaures"
else
    echo "   Pas de fichiers Drupal trouves"
fi

# PHASE 5: Restaurer Velero
echo ""
echo " PHASE 5/7: Configuration Velero & Backups "

ansible-playbook playbooks/02-configure-velero-backups.yml

# PHASE 6: Restaurer Rancher (si present dans backup)
echo ""
echo " PHASE 6/7: Restauration Rancher (sur k8s-orchestrator) "

if [ -f "$BACKUP_DIR/rancher/rancher-data-"*".tar.gz" ]; then
    echo "  - Backup Rancher detecte, restauration..."

    # Verifier si Rancher est deja running
    if sudo docker ps 2>/dev/null | grep -q rancher-server; then
        echo "    Rancher container actif detecte. Options:"
        echo "    1) Conserver Rancher existant (idempotent)"
        echo "    2) Restaurer depuis backup (perte configuration actuelle)"
        read -p "  Choix (1/2): " rancher_choice

        if [ "$rancher_choice" != "2" ]; then
            echo "   Rancher existant conserve"
            # Sortir de cette section sans restaurer
            SKIP_RANCHER_RESTORE=true
        fi
    fi

    if [ "${SKIP_RANCHER_RESTORE:-false}" = "false" ]; then
        # Arreter Rancher container s'il existe
        if sudo docker ps -a 2>/dev/null | grep -q rancher-server; then
            echo "    Arret container Rancher existant..."
            sudo docker stop rancher-server 2>/dev/null || true
            sudo docker rm rancher-server 2>/dev/null || true
        fi

        # Restaurer les donnees Rancher
        if [ -d "/opt/rancher" ]; then
            echo "    Sauvegarde ancien /opt/rancher vers /opt/rancher.old..."
            # Eviter l'accumulation: supprimer les anciens backups de plus de 7 jours
            find /opt -maxdepth 1 -name "rancher.old.*" -type d -mtime +7 -exec sudo rm -rf {} \; 2>/dev/null || true
            sudo mv /opt/rancher /opt/rancher.old.$(date +%Y%m%d-%H%M%S) 2>/dev/null || true
        fi

        echo "    Extraction backup Rancher..."
        RANCHER_BACKUP=$(ls -t $BACKUP_DIR/rancher/rancher-data-*.tar.gz | head -1)
        sudo tar xzf "$RANCHER_BACKUP" -C /opt/ 2>/dev/null || echo "   Erreur extraction Rancher"

        # Recuperer la config du container depuis le backup
        if [ -f "$BACKUP_DIR/rancher/rancher-container-config.json" ]; then
            RANCHER_VERSION=$(jq -r '.[0].Config.Image' "$BACKUP_DIR/rancher/rancher-container-config.json" 2>/dev/null || echo "rancher/rancher:latest")
            echo "    Version Rancher: $RANCHER_VERSION"

            # Redemarrer Rancher avec les memes parametres
            echo "    Redemarrage container Rancher..."
            sudo docker run -d \
              --name rancher-server \
              --restart=unless-stopped \
              -p 80:80 -p 443:443 \
              -v /opt/rancher:/var/lib/rancher \
              --privileged \
              $RANCHER_VERSION

            echo "   Rancher restaure"
            echo "   Attente demarrage Rancher (30 secondes)..."
            sleep 30

            if sudo docker ps | grep -q rancher-server; then
                echo "   Rancher operationnel"
            else
                echo "   Rancher container non running, verifier les logs:"
                echo "     sudo docker logs rancher-server"
            fi
        fi
    fi
else
    echo "   Pas de backup Rancher trouve (skip)"
fi



## PHASE 8: Install Derniers composants
echo ""
echo " PHASE 8/9: Install Derniers composants "

sleep 30  # Laisser le temps aux pods de stabiliser

e PHASE 8: Configuration des derniers composants
echo "Configuration securite..."
ansible-playbook playbooks/03-configure-security.yml

echo "Configuration ingress + TLS..."
ansible-playbook playbooks/04-configure-ingress.yml -e "enable_tls=false use_staging_tls=true"

echo "Configuration monitoring + dashboards..."
ansible-playbook playbooks/05-configure-monitoring-dashboards.yml

echo "Configuration Kubernetes Dashboard..."
ansible-playbook playbooks/06-configure-kubernetes-dashboard.yml

# PHASE 9: Verification
echo ""
echo " PHASE 9/9: Verification "

sleep 30  # Laisser le temps aux pods de stabiliser

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
echo "          RESTAURATION TERMINEE                         "
echo ""
echo ""
echo "Temps de recuperation: ${MINUTES}m ${SECONDS}s"
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
echo "  3. Creer nouveau backup:"
echo "     $HOME/k8s-infra/backup/backup-to-k8s-orchestrator.sh"
echo ""
