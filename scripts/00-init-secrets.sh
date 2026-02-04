#!/bin/bash
# Initialize secure secrets management
# Creates encrypted Ansible Vault and generates strong passwords

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$SCRIPT_DIR/../ansible"
VAULT_FILE="$ANSIBLE_DIR/inventory/group_vars/vault.yml"

echo ""
echo "         SECURE SECRETS INITIALIZATION                  "
echo ""
echo ""

# Check if vault already exists
if [ -f "$VAULT_FILE" ]; then
    read -p "Vault file already exists. Recreate? (yes/no): " recreate
    if [ "$recreate" != "yes" ]; then
        echo "Aborted."
        exit 0
    fi
    rm -f "$VAULT_FILE"
fi

# Generate strong random passwords
gen_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

ANSIBLE_SSH_PASSWORD=$(gen_password)
MYSQL_ROOT_PASSWORD=$(gen_password)
MYSQL_USER_PASSWORD=$(gen_password)
MYSQL_REPLICATION_PASSWORD=$(gen_password)
GRAFANA_ADMIN_PASSWORD=$(gen_password)
RANCHER_ADMIN_PASSWORD=$(gen_password)
MINIO_SECRET_KEY=$(gen_password)
VAULT_PASSWORD=$(gen_password)

# Create vault password file
echo "$VAULT_PASSWORD" > "$ANSIBLE_DIR/.vault_password"
chmod 600 "$ANSIBLE_DIR/.vault_password"

# Create vault.yml with all secrets
cat > "$VAULT_FILE" <<EOF
---
# Encrypted secrets - DO NOT commit unencrypted version
# Managed by Ansible Vault

# SSH Access (set this to your actual SSH password)
vault_ansible_password: "$ANSIBLE_SSH_PASSWORD"
vault_ansible_become_password: "$ANSIBLE_SSH_PASSWORD"

# MySQL Credentials
vault_mysql_root_password: "$MYSQL_ROOT_PASSWORD"
vault_mysql_user: "drupal"
vault_mysql_password: "$MYSQL_USER_PASSWORD"
vault_mysql_database: "drupal"
vault_mysql_replication_password: "$MYSQL_REPLICATION_PASSWORD"

# Grafana
vault_grafana_admin_password: "$GRAFANA_ADMIN_PASSWORD"

# Rancher
vault_rancher_password: "$RANCHER_ADMIN_PASSWORD"

# MinIO (Velero backup storage)
vault_minio_access_key: "minio"
vault_minio_secret_key: "$MINIO_SECRET_KEY"

# Velero AWS credentials
vault_velero_aws_access_key_id: "minio"
vault_velero_aws_secret_access_key: "$MINIO_SECRET_KEY"
EOF

# Encrypt the vault file
ansible-vault encrypt "$VAULT_FILE" --vault-password-file="$ANSIBLE_DIR/.vault_password"

# Create credentials reference file (not encrypted, for user reference)
cat > "$SCRIPT_DIR/../CREDENTIALS.txt" <<EOF

              GENERATED CREDENTIALS                     


  IMPORTANT: Store these credentials securely!

ANSIBLE VAULT PASSWORD:
$VAULT_PASSWORD

SSH ACCESS (formation user):
Password: $ANSIBLE_SSH_PASSWORD

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

RANCHER (if installed):
User: admin
Password: $RANCHER_ADMIN_PASSWORD

MINIO (Backup Storage):
Access Key: minio
Secret Key: $MINIO_SECRET_KEY



To view encrypted secrets:
  ansible-vault view $VAULT_FILE --vault-password-file=$ANSIBLE_DIR/.vault_password

To edit encrypted secrets:
  ansible-vault edit $VAULT_FILE --vault-password-file=$ANSIBLE_DIR/.vault_password

To decrypt temporarily:
  ansible-vault decrypt $VAULT_FILE --vault-password-file=$ANSIBLE_DIR/.vault_password

To re-encrypt:
  ansible-vault encrypt $VAULT_FILE --vault-password-file=$ANSIBLE_DIR/.vault_password


EOF

chmod 600 "$SCRIPT_DIR/../CREDENTIALS.txt"

echo ""
echo " Secrets initialized and encrypted with Ansible Vault"
echo " Vault password saved to: $ANSIBLE_DIR/.vault_password"
echo " Credentials reference saved to: $SCRIPT_DIR/../CREDENTIALS.txt"
echo ""
echo "  IMPORTANT SECURITY NOTES:"
echo "  1. NEVER commit .vault_password or CREDENTIALS.txt to git"
echo "  2. Store vault password in a secure password manager"
echo "  3. The vault.yml file is encrypted and safe to commit"
echo "  4. Change SSH password manually: update vault_ansible_password in vault.yml"
echo ""
echo "Next step: Update hosts.ini to use vault variables"
echo ""
