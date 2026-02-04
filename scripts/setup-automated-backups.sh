#!/bin/bash
# Configure automated daily backups via cron on k8s-orchestrator
# Uses SECURE backup script with GPG encryption

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ENV_FILE_SUDO_PASSWORD=""
ENV_FILE_SSH_PASSWORD=""
ENV_FILE="$REPO_ROOT/.env.tmp"
if [ -f "$ENV_FILE" ]; then
    while IFS='=' read -r key value; do
        case "$key" in
            SUDO_PASSWORD) ENV_FILE_SUDO_PASSWORD="$value" ;;
            SSH_PASSWORD|PWD) ENV_FILE_SSH_PASSWORD="$value" ;;
        esac
    done < "$ENV_FILE"
fi

SUDO_PASSWORD="${SUDO_PASSWORD:-${ENV_FILE_SUDO_PASSWORD:-}}"
if [ -z "$SUDO_PASSWORD" ]; then
    echo " SUDO_PASSWORD non defini (export SUDO_PASSWORD=... ou renseigner .env.tmp)."
    exit 1
fi

if sudo -n true 2>/dev/null; then
    SUDO_MODE="NOPASS"
else
    SUDO_MODE="PASSWORD"
fi

run_sudo() {
    if [ "$EUID" -eq 0 ]; then
        "$@"
    elif [ "$SUDO_MODE" = "NOPASS" ]; then
        sudo "$@"
    else
        printf '%s\n' "$SUDO_PASSWORD" | sudo -S "$@"
    fi
}

BACKUP_SCRIPT="$HOME/k8s-infra/backup/backup-to-k8s-orchestrator-secure.sh"
BACKUP_LOG="/var/log/k8s-backup.log"
CRON_SCHEDULE="0 2 * * *"  # 2h00 AM quotidien

echo ""
echo "     CONFIGURATION BACKUPS AUTOMATIQUES                 "
echo ""
echo ""

# Creer le repertoire de backup
echo "[1/4] Creation repertoire /opt/k8s-backups..."
run_sudo mkdir -p /opt/k8s-backups
run_sudo chown "$(whoami)":"$(whoami)" /opt/k8s-backups
echo "   /opt/k8s-backups cree"

# Creer le fichier de log
echo "[2/4] Configuration logs..."
run_sudo touch $BACKUP_LOG
run_sudo chown "$(whoami)":"$(whoami)" $BACKUP_LOG
echo "   $BACKUP_LOG cree"

# Rendre le script executable
echo "[3/4] Permissions script backup..."
chmod +x "$BACKUP_SCRIPT"
echo "   $BACKUP_SCRIPT executable"

# Ajouter au cron
echo "[4/4] Configuration cron..."

# Verifier si deja dans cron
if crontab -l 2>/dev/null | grep -q "backup-to-k8s-orchestrator"; then
    # Mettre a jour l'ancienne tache si elle existe
    if crontab -l 2>/dev/null | grep -q "backup-to-k8s-orchestrator.sh"; then
        echo "   Ancienne tache cron detectee, mise a jour vers version securisee..."
        crontab -l 2>/dev/null | grep -v "backup-to-k8s-orchestrator.sh" | crontab -
        (crontab -l 2>/dev/null; echo "$CRON_SCHEDULE $BACKUP_SCRIPT >> $BACKUP_LOG 2>&1") | crontab -
        echo "   Tache cron mise a jour (backup securise GPG)"
    else
        echo "   Tache cron deja configuree (version securisee)"
    fi
else
    # Ajouter au cron
    (crontab -l 2>/dev/null; echo "$CRON_SCHEDULE $BACKUP_SCRIPT >> $BACKUP_LOG 2>&1") | crontab -
    echo "   Tache cron ajoutee (backup securise GPG)"
fi

echo ""
echo ""
echo "    BACKUPS AUTOMATIQUES SECURISES CONFIGURES           "
echo ""
echo ""
echo "Schedule: $CRON_SCHEDULE (2h00 AM quotidien)"
echo "Script: $BACKUP_SCRIPT"
echo "Logs: $BACKUP_LOG"
echo "Stockage: /opt/k8s-backups"
echo "Retention: 7 jours (automatique)"
echo ""
echo "Securite:"
echo "   Chiffrement GPG de tous les fichiers sensibles"
echo "   .vault_password NOT backed up (Password Manager)"
echo "   Secrets K8s exclus des manifests"
echo "   Permissions 640 sur les backups"
echo "   Checksums SHA256 pour integrite"
echo ""
echo "Cron actuel:"
crontab -l | grep backup || echo "  (aucune tache backup)"
echo ""
echo "Tester manuellement:"
echo "  $BACKUP_SCRIPT"
echo ""
echo "Voir les logs:"
echo "  tail -f $BACKUP_LOG"
echo ""
echo "Restaurer depuis backup securise:"
echo "  $HOME/k8s-infra/backup/restore-from-secure-backup.sh [timestamp]"
echo ""
