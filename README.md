# Kubernetes Infrastructure - Production Ready

## Quick Overview
- High availability K3s cluster (k8s-master-1-15) orchestrated from external node k8s-orchestrator.
- Idempotent Ansible/Helm/Bash scripts covering deployment, backup, restoration, and monitoring.
- Secrets fully managed by Ansible Vault, GPG-encrypted backups, complete recovery < 30min.

## Quickstart
```bash
# From k8s-orchestrator
cd ~/k8s-infra

# Optional: create an unversioned `.env.tmp` file (SSH_USER=..., SSH_PASSWORD=..., SUDO_PASSWORD=...)
#  Never store passwords in plain text in the repository: keep `.env.tmp` outside VCS
#    (e.g., secure scp from your workstation) or temporarily export variables in the session

./deploy.sh                                    # HTTP deployment (default)
ENABLE_TLS=true ./deploy.sh                    # HTTPS Let's Encrypt (staging)
ENABLE_TLS=true USE_TLS_STAGING=false ./deploy.sh  # HTTPS production
INSTALL_RANCHER=true ./deploy.sh               # Optional Rancher addition

./restore.sh                                   # Restore latest backup
./restore.sh 20250115-020000                   # Restore specific timestamp

./backup/backup-to-k8s-orchestrator-secure.sh             # Immediate full backup
./scripts/verify-idempotence.sh                # Health/idempotence audit k8s-orchestrator
```

## Architecture
```text

 k8s-orchestrator (orchestration & backups)
 - Ansible, Helm, kubectl
 - External backups (/opt/k8s-backups/)
 - Scripts deploy.sh / restore.sh


            Ansible SSH / kubectl


 k8s-master-1     k8s-master-2       k8s-master-3
 Master    Master      Master
 + etcd    + etcd      + etcd



      Longhorn Storage (3x replication)
```

| Node                            | Role | Notes |
|---------------------------------|------|-----------|
| `k8s-orchestrator.example.com`   | Orchestrator | Machine from which to run `deploy.sh`, `restore.sh`, Ansible, backups. Hosts `/opt/k8s-backups`. |
| `k8s-master-1.example.com`   | K3s Master     | Bootstrap node, exposed API, etcd quorum member. |
| `k8s-master-2.example.com`   | K3s Master     | etcd member, hosts application workloads and Longhorn storage. |
| `k8s-master-3.example.com`   | K3s Master     | etcd member, hosts application workloads and Longhorn storage. |

## Main Stack
- **Platform**: K3s `v1.33.5+k3s1` (3 masters), Ansible 2.15+, Helm 3, kubectl.
- **Storage**: Longhorn `v1.7.2`, default StorageClass `longhorn`, 3x replication.
- **Applications**: Drupal 10 (internal chart, 3 pods), MySQL 8.0 (StatefulSet 3 replicas).
- **Observability**: kube-prometheus-stack (Prometheus, Grafana, Alertmanager, exporters) 15-day retention.
- **Security**: Cert-Manager `v1.16.2`, NetworkPolicies, Pod Security Standards (Restricted), encrypted secrets (Vault + etcd).

## Architecture Consistency
- **Centralized control**: all operations (Ansible, Helm, backups) are launched from `k8s-orchestrator`, ensuring that idempotent scripts manage secrets and cluster state.
- **etcd quorum**: the three K3s masters (k8s-master-1-15) ensure high availability; Longhorn 3x replication maintains storage resilience.
- **TLS flow**: Cert-Manager orchestrates Let's Encrypt, Nginx Ingress publishes Drupal/Grafana, NodePorts remain available as fallback.
- **Backups**: `backup-to-k8s-orchestrator-secure.sh` collects etcd, MySQL, Drupal files, manifests, and encrypted secrets, stored on `k8s-orchestrator` with controlled retention.
- **Restoration**: `restore.sh` recalculates configuration (vault, inventory), rebuilds the cluster if necessary, and restores data respecting idempotent choices.

## Scripts & Deployment Flow
| Script | Role | Notes |
|--------|------|-----------|
| `./deploy.sh` | Complete idempotent deployment | Options `ENABLE_TLS`, `USE_TLS_STAGING`, `INSTALL_RANCHER`. |
| `./restore.sh [timestamp]` | Complete restoration | GPG detection, interactive confirmations to preserve existing data. |
| `./backup/backup-to-k8s-orchestrator-secure.sh` | GPG-encrypted backup | 7-day retention, strict permissions, checksums. |
| `./scripts/verify-idempotence.sh` | Consistency audit | Checks tools, secrets, backups, Rancher, cluster. |
| `./scripts/install-prerequisites.sh` | Dependency installation | Installs only what is missing (Ansible, Helm, kubectl). |
| `./scripts/setup-automated-backups.sh` | Daily cron | Single addition (02:00) for secure backup. |

### `deploy.sh` Phases
1. OS prerequisites & packages.
2. Generation/reuse of secrets (Vault, credentials, SSH keys).
3. K3s bootstrap on k8s-master-1-15 and kubeconfig retrieval.
4. Longhorn, Cert-Manager, Drupal/MySQL, monitoring deployment.
5. Security policies application.
6. Velero configuration, automated backups, first snapshot.
7. Optional TLS/Ingress and Rancher activation.

### `restore.sh` Restoration
- Restores Ansible inventory, vault, and SSH keys.
- Recreates K3s cluster if absent (or offers to keep existing).
- Redeploys infrastructure, restores MySQL/Drupal, reconfigures Velero.
- Verifies final state and reports results.

## Daily Operations

### Verification & Idempotence
```bash
./scripts/verify-idempotence.sh
```
The script checks for tool presence (ansible, helm, kubectl, docker), secrets (`vault.yml` encrypted, `.vault_password` permissions), backups `/opt/k8s-backups`, cron task, and cluster connectivity. Plan to install dependencies beforehand (`./scripts/install-prerequisites.sh`).

### Services & Access Points
| Service | NodePort (HTTP) | Ingress HTTPS (optional) | Authentication |
|---------|-----------------|---------------------------|------------------|
| Drupal | `http://k8s-master-1.example.com:30080` | `https://k8s-master-1.example.com` | Credentials generated via Drupal wizard, DB parameters in `CREDENTIALS.txt`. |
| Grafana | `http://grafana.example.com:30080` | `https://grafana.example.com` | `admin` / generated password (`CREDENTIALS.txt`). |
| Prometheus | `http://k8s-master-1.example.com:30090` |  | Read access. |
| Alertmanager | `http://k8s-master-1.example.com:30903` |  | Read access. |
| Rancher (option) |  | `https://k8s-orchestrator.example.com` | Credentials created during installation (`CREDENTIALS.txt`). |

### HTTPS Publishing (Ingress & TLS)
Prerequisites: DNS pointing to nodes, port 80 open for ACME HTTP01.
```bash
ansible-playbook playbooks/04-configure-ingress.yml                            # NodePort only
ansible-playbook playbooks/04-configure-ingress.yml -e enable_tls=true         # HTTPS (staging)
ansible-playbook playbooks/04-configure-ingress.yml -e enable_tls=true \
  -e use_staging_tls=false                                                     # HTTPS (production)
```
Verifications:
```bash
kubectl get pods -n ingress-nginx
kubectl get ingress -A
kubectl describe certificate drupal-tls-prod -n drupal
curl -Ik https://k8s-master-1.example.com
```
Troubleshooting:
- No certificate: `kubectl logs -n cert-manager -l app=cert-manager`, `kubectl get challenges -A`, test `.well-known` response.
- Let's Encrypt limits: switch back to staging, see https://letsencrypt.org/docs/rate-limits/.
- Traffic not routed: `kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx`, check endpoints `kubectl get endpoints -n drupal drupal`.
- Adding an FQDN: duplicate ingress in `playbooks/04-configure-ingress.yml`, adjust `cert-manager.io/cluster-issuer`.

### Backups
Secure pipeline:
1. Generate or import GPG key (`./scripts/manage-gpg-backup-key.sh`).
2. Schedule daily backup (`./scripts/setup-automated-backups.sh`) or manually run `./backup/backup-to-k8s-orchestrator-secure.sh`.
3. Verify `backup-info.txt` and `checksums.sha256` in `/opt/k8s-backups/<timestamp>/`.

Backup contents:
```
/opt/k8s-backups/<timestamp>/
 etcd/etcd-snapshot-*.gpg
 mysql/all-databases-*.sql.gz.gpg
 drupal-files/files-*.tar.gz.gpg
 secrets/vault.yml (encrypted), vault-password-location.txt, kubeconfig.yaml.gpg
 config/id_rsa.gpg, id_rsa.pub, known_hosts, inventory
 backup-info.txt, checksums.sha256
```
Checklist:
- `.vault_password` not backed up (reminder file only).
- Permissions: `chmod 750 /opt/k8s-backups` and `chmod 640` on files.
- Keep GPG key + passphrase with Ansible Vault key in a password manager.
- Monitor `/opt/k8s-backups` disk space (7-day retention).

### Secrets & Security
- Automatic generation via `./deploy.sh` or `./scripts/00-init-secrets.sh` (vault, credentials, SSH keys).
- `ansible/inventory/group_vars/vault.yml` is encrypted (Ansible Vault). `ansible/.vault_password` stays local (permissions 600) and must be backed up in a vault then deleted if necessary.
- Rotation: `ansible-vault edit ansible/inventory/group_vars/vault.yml`, replay relevant playbooks, restart workloads (`kubectl rollout restart ...`).
- Security checklist:
  - Encrypted secrets present (`vault.yml`, `.vault_password`) and backed up off-server.
  - `CREDENTIALS.txt` deleted after export to vault.
  - Recent GPG backup available, cron active.
  - SSH access via keys, passwords changed regularly.
  - TLS tested in staging then production if enabled.
  - `./scripts/verify-idempotence.sh` without critical errors.

#### Local Variables (optional)
```bash
cat <<'EOF' > .env.tmp  # Copy outside git repository then delete if necessary
SSH_USER=formation
SSH_PASSWORD=<ssh_password>
SUDO_PASSWORD=<sudo_password>
EOF

# OR export variables for the duration of your session
export SSH_USER=formation
export SSH_PASSWORD=<ssh_password>
export SUDO_PASSWORD=<sudo_password>
```
> Keep this information in a secrets manager; never commit it.

### Rancher (optional)
**Manual import**:
1. Connect to `https://<rancher-server>`.
2. Import existing cluster (Generic/K3s option) and copy the `kubectl apply` command.
3. From k8s-orchestrator: `export KUBECONFIG=~/k8s-infra/ansible/kubeconfig.yaml`, execute the provided command.

**Ansible automation**:
```yaml
# ansible/playbooks/10-register-to-rancher.yml
---
- name: Register cluster to Rancher
  hosts: localhost
  gather_facts: no
  connection: local
  vars:
    rancher_url: "{{ vault_rancher_url }}"
    rancher_token: "{{ vault_rancher_token }}"
    cluster_name: "k8s-production"
    kubeconfig: "{{ playbook_dir }}/../kubeconfig.yaml"
  environment:
    KUBECONFIG: "{{ kubeconfig }}"
  tasks:
    - name: Request import manifest
      uri:
        url: "{{ rancher_url }}/v3/clusterregistrationtokens"
        method: POST
        headers: { Authorization: "Bearer {{ rancher_token }}" }
        body_format: json
        body: { type: "clusterRegistrationToken", clusterId: "{{ cluster_name }}" }
      register: rancher_token_response
    - name: Deploy Rancher agent
      command: kubectl apply -f {{ rancher_token_response.json.manifestUrl }}
```
Add variables `vault_rancher_url` / `vault_rancher_token` to vault, then run `ansible-playbook playbooks/10-register-to-rancher.yml`.

**Post-integration**: add labels (`environment=production`), verify metrics collection, include `/opt/rancher` in backups (script already planned).
**Uninstallation**:
```bash
kubectl delete namespace cattle-system
kubectl get crd | grep cattle.io | awk '{print $1}' | xargs kubectl delete crd
```

## Troubleshooting
```bash
# Cluster state
kubectl get nodes
kubectl get pods -A

# K3s logs (master)
ssh formation@k8s-master-1.example.com "sudo journalctl -u k3s -n 100 --no-pager"

# TLS / Cert-Manager
kubectl logs -n cert-manager -l app=cert-manager
kubectl get challenges -A
kubectl describe certificate drupal-tls-prod -n drupal

# Rancher (on k8s-orchestrator)
sudo docker logs rancher-server
sudo docker restart rancher-server
curl -k https://localhost/ping
```

## External References
- K3s: https://docs.k3s.io
- Longhorn: https://longhorn.io/docs
- Ansible: https://docs.ansible.com
- kube-prometheus-stack: https://github.com/prometheus-operator/kube-prometheus
- Cert-Manager: https://cert-manager.io/docs
- Drupal: https://www.drupal.org/docs
- Rancher: https://ranchermanager.docs.rancher.com/
