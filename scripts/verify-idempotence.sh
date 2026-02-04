#!/bin/bash
# Script de verification de l'idempotence
# Verifie que k8s-orchestrator est dans un etat sain et coherent

set -euo pipefail

echo ""
echo "   VERIFICATION IDEMPOTENCE & SANTE K8S16              "
echo ""
echo ""

ERRORS=0
WARNINGS=0

check_ok() {
    echo "   $1"
}

check_warn() {
    echo "   $1"
    WARNINGS=$((WARNINGS + 1))
}

check_error() {
    echo "   $1"
    ERRORS=$((ERRORS + 1))
}

# 1. Verifier outils systeme
echo "[1/8] Verification outils systeme..."
for tool in ansible helm kubectl jq git curl; do
    if command -v $tool &> /dev/null; then
        check_ok "$tool installe"
    else
        check_error "$tool manquant"
    fi
done

# 2. Verifier modules Python
echo "[2/8] Verification modules Python..."
if python3 -c "import kubernetes" 2>/dev/null; then
    check_ok "Module Python kubernetes OK"
else
    check_error "Module Python kubernetes manquant"
fi

# 3. Verifier secrets
echo "[3/8] Verification secrets..."
if [ -f "$HOME/k8s-infra/ansible/.vault_password" ]; then
    check_ok ".vault_password existe"
    if [ "$(stat -c %a $HOME/k8s-infra/ansible/.vault_password)" = "600" ]; then
        check_ok "Permissions .vault_password correctes (600)"
    else
        check_warn "Permissions .vault_password incorrectes (attendu: 600)"
    fi
else
    check_warn ".vault_password manquant (normal si pas encore deploye)"
fi

if [ -f "$HOME/k8s-infra/ansible/inventory/group_vars/vault.yml" ]; then
    if head -1 "$HOME/k8s-infra/ansible/inventory/group_vars/vault.yml" | grep -q "\$ANSIBLE_VAULT"; then
        check_ok "vault.yml chiffre"
    else
        check_error "vault.yml NON chiffre (risque securite!)"
    fi
else
    check_warn "vault.yml manquant (normal si pas encore deploye)"
fi

if [ -f "$HOME/k8s-infra/CREDENTIALS.txt" ]; then
    check_ok "CREDENTIALS.txt existe"
    if [ "$(stat -c %a $HOME/k8s-infra/CREDENTIALS.txt)" = "600" ]; then
        check_ok "Permissions CREDENTIALS.txt correctes (600)"
    else
        check_warn "Permissions CREDENTIALS.txt incorrectes (attendu: 600)"
    fi
else
    check_warn "CREDENTIALS.txt manquant (normal si pas encore deploye)"
fi

# 4. Verifier backups
echo "[4/8] Verification backups..."
if [ -d "/opt/k8s-backups" ]; then
    check_ok "Repertoire /opt/k8s-backups existe"
    BACKUP_COUNT=$(ls -1 /opt/k8s-backups 2>/dev/null | wc -l)
    if [ $BACKUP_COUNT -gt 0 ]; then
        check_ok "Backups trouves: $BACKUP_COUNT"
        LATEST_BACKUP=$(ls -t /opt/k8s-backups | head -1)
        check_ok "Dernier backup: $LATEST_BACKUP"
    else
        check_warn "Aucun backup trouve (normal si pas encore deploye)"
    fi
else
    check_warn "Repertoire /opt/k8s-backups manquant (normal si pas encore deploye)"
fi

# 5. Verifier cron
echo "[5/8] Verification backups automatiques..."
if crontab -l 2>/dev/null | grep -q "backup-to-k8s-orchestrator.sh"; then
    check_ok "Tache cron backup configuree"
    CRON_LINE=$(crontab -l | grep backup-to-k8s-orchestrator.sh)
    check_ok "Schedule: $CRON_LINE"
else
    check_warn "Tache cron backup non configuree (normal si pas encore deploye)"
fi

# 6. Verifier Docker (si Rancher)
echo "[6/8] Verification Docker & Rancher..."
if command -v docker &> /dev/null; then
    check_ok "Docker installe"

    if sudo docker ps -a 2>/dev/null | grep -q rancher-server; then
        check_ok "Container Rancher existe"
        if sudo docker ps 2>/dev/null | grep -q rancher-server; then
            check_ok "Container Rancher running"
        else
            check_warn "Container Rancher existe mais n'est pas running"
        fi

        if [ -d "/opt/rancher" ]; then
            check_ok "Data Rancher persiste (/opt/rancher)"
        else
            check_error "Data Rancher manquant (/opt/rancher)"
        fi
    else
        check_warn "Rancher non installe (optionnel)"
    fi
else
    check_warn "Docker non installe (optionnel, requis pour Rancher)"
fi

# 7. Verifier Ansible inventory
echo "[7/8] Verification Ansible inventory..."
if [ -f "$HOME/k8s-infra/ansible/inventory/hosts.yml" ]; then
    check_ok "Inventory Ansible (hosts.yml) present"
elif [ -f "$HOME/k8s-infra/ansible/inventory/hosts.ini" ]; then
    check_ok "Inventory Ansible (hosts.ini) present"
else
    check_error "Inventory Ansible manquant (hosts.yml attendu)"
fi

if [ -f "$HOME/k8s-infra/ansible/ansible.cfg" ]; then
    check_ok "ansible.cfg existe"
else
    check_warn "ansible.cfg manquant"
fi

# 8. Verifier connectivite cluster (si deploye)
echo "[8/8] Verification connectivite cluster..."
if [ -f "$HOME/k8s-infra/ansible/kubeconfig.yaml" ]; then
    check_ok "kubeconfig existe"
    export KUBECONFIG="$HOME/k8s-infra/ansible/kubeconfig.yaml"
    if kubectl get nodes &>/dev/null; then
        NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
        check_ok "Cluster accessible ($NODE_COUNT nuds)"
    else
        check_warn "Cluster non accessible (normal si pas deploye ou arrete)"
    fi
else
    check_warn "kubeconfig manquant (normal si pas encore deploye)"
fi

# Resume
echo ""
echo ""
echo "              RESUME VERIFICATION                       "
echo ""
echo ""
echo "Erreurs: $ERRORS"
echo "Avertissements: $WARNINGS"
echo ""

if [ $ERRORS -gt 0 ]; then
    echo " Problemes critiques detectes!"
    echo "   Certaines fonctionnalites pourraient ne pas fonctionner."
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo "  Avertissements detectes"
    echo "   Ceci est normal si l'infrastructure n'est pas encore deployee."
    echo "   Si deployee, verifier les avertissements ci-dessus."
    exit 0
else
    echo " Tout est OK!"
    echo "   k8s-orchestrator est dans un etat sain et coherent."
    exit 0
fi
