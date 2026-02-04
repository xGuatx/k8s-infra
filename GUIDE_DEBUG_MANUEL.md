# Guide de Debogage Manuel - Infrastructure K3s HA

##  Table des Matieres

1. [Vue d'ensemble](#vue-densemble)
2. [Prerequis et Environnement](#prerequis-et-environnement)
3. [Corrections Appliquees](#corrections-appliquees)
4. [Procedures de Base](#procedures-de-base)
5. [Deploiement Complet](#deploiement-complet)
6. [Debogage des Problemes Courants](#debogage-des-problemes-courants)
7. [Tests et Verifications](#tests-et-verifications)
8. [Backup et Restore](#backup-et-restore)
9. [Nettoyage](#nettoyage)
10. [Commandes Utiles](#commandes-utiles)

---

## Vue d'ensemble

### Architecture
- **Orchestration**: k8s-orchestrator.example.com (nud de controle, execute Ansible)
- **Cluster K3s HA**:
  - k8s-master-1.example.com (master 1)
  - k8s-master-2.example.com (master 2)
  - k8s-master-3.example.com (master 3)

### Credentials
- **SSH User**: formation
- **SSH/SUDO Password**: <YOUR_SSH_PASSWORD>

### Structure des Fichiers
```
/home/guat/
 k8s-infra.tar.gz                    # Archive a deployer
 k8s-infra/                          # Repertoire de travail
     deploy.sh                       # Script de deploiement principal
     ansible/
        inventory/
           hosts.yml               # Inventaire Ansible
           group_vars/
               all.yml             # Variables globales
               vault.yml           # Secrets (chiffre)
               orchestration/      # Variables pour k8s-orchestrator
                   vault.yml
        playbooks/
           00-bootstrap-k3s.yml    # Installation K3s (FIX SYSTEMD)
           01-deploy-infrastructure.yml
           02-configure-velero-backups.yml
           03-configure-security.yml
           04-configure-ingress.yml
           05-configure-monitoring-dashboards.yml
        kubeconfig.yaml             # Genere lors du deploiement
     helm/
         charts/
             drupal-stack/
                 values.yaml
                 templates/
                     mysql-statefulset.yaml  # FIX HOSTNAME + XTRABACKUP
```

---

## Prerequis et Environnement

### Sur votre Machine Locale (guat@WSL)
```bash
# Variables d'environnement
export SSH_PASSWORD='<YOUR_SSH_PASSWORD>'
export SUDO_PASSWORD='<YOUR_SSH_PASSWORD>'
export SSH_USER='formation'

# Fichier .env.tmp (dans /home/guat/k8s-infra/)
cat > /home/guat/k8s-infra/.env.tmp << EOF
SSH_PASSWORD=<YOUR_SSH_PASSWORD>
SUDO_PASSWORD=<YOUR_SSH_PASSWORD>
SSH_USER=formation
EOF
```

### Connexion SSH aux Nuds
```bash
# Sans mot de passe a chaque fois
alias ssh13='sshpass -p "<YOUR_SSH_PASSWORD>" ssh -o StrictHostKeyChecking=no formation@k8s-master-1.example.com'
alias ssh14='sshpass -p "<YOUR_SSH_PASSWORD>" ssh -o StrictHostKeyChecking=no formation@k8s-master-2.example.com'
alias ssh15='sshpass -p "<YOUR_SSH_PASSWORD>" ssh -o StrictHostKeyChecking=no formation@k8s-master-3.example.com'
alias ssh16='sshpass -p "<YOUR_SSH_PASSWORD>" ssh -o StrictHostKeyChecking=no formation@k8s-orchestrator.example.com'

# Connexion avec kubectl configure
alias k16='ssh16 "export KUBECONFIG=/tmp/k8s-infra/ansible/kubeconfig.yaml && kubectl"'
```

---

## Corrections Appliquees

### 1. Fix Systemd (00-bootstrap-k3s.yml)

**Probleme**: K3s etait installe mais pas demarre automatiquement apres k3s-uninstall.sh

**Solution**: Ajout d'une tache `Ensure K3s service is started` dans le playbook

**Lignes modifiees** :
- `/home/guat/k8s-infra/ansible/playbooks/00-bootstrap-k3s.yml:51-55`
- `/home/guat/k8s-infra/ansible/playbooks/00-bootstrap-k3s.yml:124-128`

```yaml
    - name: Ensure K3s service is started
      systemd:
        name: k3s
        state: started
        enabled: yes
```

### 2. Fix Hostname (mysql-statefulset.yaml)

**Probleme**: Commande `hostname` non disponible dans l'image MySQL Docker

**Solution**: Utiliser `$HOSTNAME` au lieu de `$(hostname)`

**Fichier**: `/home/guat/k8s-infra/helm/charts/drupal-stack/templates/mysql-statefulset.yaml`

**Lignes modifiees**:
- Ligne 40: `[[ $HOSTNAME =~ -([0-9]+)$ ]] || exit 1`
- Ligne 63: `[[ $HOSTNAME =~ -([0-9]+)$ ]] || exit 1`

### 3. Fix Xtrabackup Image (mysql-statefulset.yaml)

**Probleme**: Image `gcr.io/google-samples/xtrabackup:1.0` n'est plus disponible

**Solution**: Utiliser `perconalab/percona-xtrabackup:8.0`

**Fichier**: `/home/guat/k8s-infra/helm/charts/drupal-stack/templates/mysql-statefulset.yaml`

**Lignes modifiees**:
- Ligne 56: `image: perconalab/percona-xtrabackup:8.0`
- Ligne 122: `image: perconalab/percona-xtrabackup:8.0`

### 4. Fix Cles du Secret MySQL (playbook + values)

**Probleme**: Les cles dans le secret ne correspondaient pas aux noms attendus par le chart

**Solution**: Utiliser les noms de cles corrects dans `values.yaml:34-37`

```yaml
auth:
  existingSecret: mysql-secret
  rootPasswordKey: mysql-root-password
  databaseKey: mysql-database
  userKey: mysql-user
  passwordKey: mysql-password
```

---

## Procedures de Base

### 1. Suppression Complete du Cluster K3s

```bash
# Sur les 3 nuds du cluster
for i in 13 14 15; do
  echo "=== Nettoyage k8s$i ==="
  sshpass -p '<YOUR_SSH_PASSWORD>' ssh -o StrictHostKeyChecking=no \
    formation@k8s$i.example.com \
    "echo '<YOUR_SSH_PASSWORD>' | sudo -S /usr/local/bin/k3s-uninstall.sh"
done

# Verification
for i in 13 14 15; do
  echo "=== Status k8s$i ==="
  sshpass -p '<YOUR_SSH_PASSWORD>' ssh -o StrictHostKeyChecking=no \
    formation@k8s$i.example.com \
    "systemctl is-active k3s 2>/dev/null || echo 'K3s non installe'"
done
```

### 2. Preparation de l'Archive sur k8s-orchestrator

```bash
# Depuis votre machine locale
cd /home/guat
tar czf k8s-infra.tar.gz k8s-infra/

# Upload vers k8s-orchestrator
sshpass -p '<YOUR_SSH_PASSWORD>' scp -o StrictHostKeyChecking=no \
  k8s-infra.tar.gz formation@k8s-orchestrator.example.com:/tmp/

# Extraction sur k8s-orchestrator
ssh16 "cd /tmp && rm -rf k8s-infra && tar xzf k8s-infra.tar.gz"
```

---

## Deploiement Complet

### Methode 1: Deploiement Automatique (Recommande)

```bash
# Lancer le deploiement complet
ssh16 "cd /tmp/k8s-infra && nohup ./deploy.sh > /tmp/deploy.log 2>&1 &"

# Surveiller en temps reel
ssh16 "tail -f /tmp/deploy.log"

# Surveillance filtree (phases importantes)
watch -n 10 'sshpass -p "<YOUR_SSH_PASSWORD>" ssh -o StrictHostKeyChecking=no \
  formation@k8s-orchestrator.example.com \
  "tail -100 /tmp/deploy.log | grep -E \"(|PHASE|PLAY RECAP|fatal|failed=)\""'
```

### Methode 2: Deploiement Manuel Phase par Phase

```bash
# Se connecter a k8s-orchestrator
ssh16

# Variables
export KUBECONFIG=/tmp/k8s-infra/ansible/kubeconfig.yaml
cd /tmp/k8s-infra

# Phase 0: Prerequis
# (Ansible, Helm, kubectl deja installes normalement)

# Phase 1: Generer les secrets
./deploy.sh
# Appuyer sur Ctrl+C apres la generation des secrets

# Phase 2: Configurer SSH
ansible-playbook ansible/playbooks/setup-ssh-keys.yml -i ansible/inventory/hosts.yml

# Phase 3: Installer K3s
ansible-playbook ansible/playbooks/00-bootstrap-k3s.yml \
  -i ansible/inventory/hosts.yml \
  --vault-password-file ansible/.vault_password

# Verifier que K3s fonctionne
kubectl get nodes

# Phase 4: Deployer l'infrastructure
ansible-playbook ansible/playbooks/01-deploy-infrastructure.yml \
  -i ansible/inventory/hosts.yml \
  --vault-password-file ansible/.vault_password

# Phase 5-10: Suite du deploiement
ansible-playbook ansible/playbooks/02-configure-velero-backups.yml \
  -i ansible/inventory/hosts.yml --vault-password-file ansible/.vault_password

ansible-playbook ansible/playbooks/03-configure-security.yml \
  -i ansible/inventory/hosts.yml --vault-password-file ansible/.vault_password

ansible-playbook ansible/playbooks/04-configure-ingress.yml \
  -i ansible/inventory/hosts.yml --vault-password-file ansible/.vault_password

ansible-playbook ansible/playbooks/05-configure-monitoring-dashboards.yml \
  -i ansible/inventory/hosts.yml --vault-password-file ansible/.vault_password
```

---

## Debogage des Problemes Courants

### Probleme 1: K3s ne demarre pas

**Symptomes**:
```
fatal: [k8s-master-1.example.com]: FAILED! => {"msg": "Timeout when waiting for 127.0.0.1:6443"}
```

**Diagnostic**:
```bash
# Verifier le statut K3s
ssh13 "sudo systemctl status k3s"

# Verifier les logs
ssh13 "sudo journalctl -u k3s -n 100 --no-pager"
```

**Solution**:
- Verifier que le fix systemd est bien present dans `00-bootstrap-k3s.yml`
- Demarrer manuellement: `ssh13 "sudo systemctl start k3s"`

### Probleme 2: MySQL Pods en CrashLoopBackOff

**Symptomes**:
```
mysql-0   0/2   CrashLoopBackOff   5   10m
```

**Diagnostic**:
```bash
# Verifier les evenements
k16 describe pod mysql-0 -n drupal

# Logs du conteneur init
k16 logs mysql-0 -n drupal -c init-mysql
k16 logs mysql-0 -n drupal -c clone-mysql
```

**Solutions courantes**:

1. **Erreur "hostname: command not found"**
   - Verifier que le fix `$HOSTNAME` est applique dans `mysql-statefulset.yaml`

2. **Erreur "ImagePullBackOff" pour xtrabackup**
   - Verifier que l'image est `perconalab/percona-xtrabackup:8.0`
   - Test manuel: `k16 run test --image=perconalab/percona-xtrabackup:8.0 --rm -it -- bash`

3. **Erreur "couldn't find key mysql-root-password"**
   - Verifier le secret:
     ```bash
     k16 get secret mysql-secret -n drupal -o yaml
     k16 get secret mysql-secret -n drupal -o jsonpath='{.data}' | jq
     ```
   - Les cles doivent etre: `mysql-root-password`, `mysql-database`, `mysql-user`, `mysql-password`

### Probleme 3: Helm Timeout lors de l'installation

**Symptomes**:
```
Error: context deadline exceeded
```

**Diagnostic**:
```bash
# Voir tous les pods
k16 get pods -n drupal -o wide

# Identifier les pods en erreur
k16 get pods -n drupal --field-selector=status.phase!=Running

# Logs detailles
k16 describe pod <pod-name> -n drupal
```

**Solution**:
```bash
# Augmenter le timeout Helm
helm upgrade drupal-stack ./helm/charts/drupal-stack \
  -n drupal --wait --timeout 20m

# Ou installer sans wait et verifier manuellement
helm upgrade drupal-stack ./helm/charts/drupal-stack \
  -n drupal --timeout 20m
```

### Probleme 4: Namespace bloque en "Terminating"

**Symptomes**:
```bash
k16 get namespace drupal
# STATUS: Terminating (bloque)
```

**Solution**:
```bash
# Forcer la suppression
k16 get namespace drupal -o json | \
  jq '.spec.finalizers = []' | \
  k16 replace --raw "/api/v1/namespaces/drupal/finalize" -f -
```

---

## Tests et Verifications

### Verification Complete apres Deploiement

```bash
#!/bin/bash
# Sauvegarder en tant que check-cluster.sh

export KUBECONFIG=/tmp/k8s-infra/ansible/kubeconfig.yaml

echo "=== Verification des Nuds K3s ==="
kubectl get nodes -o wide

echo -e "\n=== Verification des Namespaces ==="
kubectl get namespaces

echo -e "\n=== Verification Longhorn ==="
kubectl get pods -n longhorn-system

echo -e "\n=== Verification Cert-Manager ==="
kubectl get pods -n cert-manager

echo -e "\n=== Verification Drupal + MySQL ==="
kubectl get pods -n drupal -o wide
kubectl get pvc -n drupal
kubectl get svc -n drupal

echo -e "\n=== Verification Prometheus + Grafana ==="
kubectl get pods -n monitoring
kubectl get svc -n monitoring

echo -e "\n=== Verification PV/PVC ==="
kubectl get pv
kubectl get pvc --all-namespaces

echo -e "\n=== Verification des Secrets ==="
kubectl get secrets -n drupal

echo -e "\n=== Resume des Pods en Erreur ==="
kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded
```

Execution:
```bash
ssh16 "bash /tmp/k8s-infra/check-cluster.sh"
```

### Test de Connectivite MySQL

```bash
# Depuis un pod de test
k16 run mysql-client --image=mysql:8.0 -it --rm --restart=Never -n drupal -- \
  mysql -h mysql-primary -u drupal -pdrupalpass123 -e "SHOW DATABASES;"

# Test depuis Drupal
k16 exec -it deployment/drupal -n drupal -- \
  php -r "new PDO('mysql:host=mysql-primary;dbname=drupal', 'drupal', 'drupalpass123');"
```

### Test de Replication MySQL

```bash
# Verifier les 3 instances MySQL
for i in 0 1 2; do
  echo "=== mysql-$i ==="
  k16 exec mysql-$i -n drupal -c mysql -- \
    mysql -uroot -ppGseVnJxiI3wm3vEaKCtOVaVT -e "SHOW SLAVE STATUS\G"
done
```

### Test des Services Web

```bash
# Port-forward Drupal
k16 port-forward -n drupal svc/drupal 8080:80 &
curl http://localhost:8080

# Port-forward Grafana
k16 port-forward -n monitoring svc/grafana 3000:80 &
curl http://localhost:3000
```

---

## Backup et Restore

### Backup Manuel avec Velero

```bash
# Creer un backup de tout le cluster
k16 create backup full-cluster-backup \
  --include-namespaces drupal,longhorn-system,cert-manager,monitoring

# Backup d'un namespace specifique
k16 create backup drupal-backup \
  --include-namespaces drupal

# Lister les backups
k16 get backups

# Details d'un backup
k16 describe backup drupal-backup
```

### Restore depuis un Backup

```bash
# Restore complet
k16 create restore full-cluster-restore \
  --from-backup full-cluster-backup

# Restore d'un namespace
k16 create restore drupal-restore \
  --from-backup drupal-backup \
  --namespace-mappings drupal:drupal-restored

# Suivre le restore
k16 get restore -w
k16 describe restore drupal-restore
```

### Backup MySQL Manuel (sans Velero)

```bash
# Backup de la base Drupal
k16 exec mysql-0 -n drupal -c mysql -- \
  mysqldump -uroot -ppGseVnJxiI3wm3vEaKCtOVaVT drupal \
  > /tmp/drupal-backup-$(date +%Y%m%d-%H%M%S).sql

# Restore
cat /tmp/drupal-backup-20251017-090000.sql | \
  k16 exec -i mysql-0 -n drupal -c mysql -- \
  mysql -uroot -ppGseVnJxiI3wm3vEaKCtOVaVT drupal
```

### Test du Restore

1. **Preparer un backup de test**:
```bash
# Creer des donnees de test
k16 exec mysql-0 -n drupal -c mysql -- \
  mysql -uroot -ppGseVnJxiI3wm3vEaKCtOVaVT -e \
  "CREATE DATABASE test_restore; USE test_restore; CREATE TABLE test(id INT); INSERT INTO test VALUES(1);"

# Creer le backup
k16 create backup test-restore-backup --include-namespaces drupal
```

2. **Simuler une perte de donnees**:
```bash
# Supprimer le namespace
k16 delete namespace drupal

# Attendre la suppression complete
k16 wait --for=delete namespace/drupal --timeout=60s
```

3. **Effectuer le restore**:
```bash
# Restore
k16 create restore test-restore-restore --from-backup test-restore-backup

# Verifier
k16 get restore test-restore-restore -w
k16 get pods -n drupal

# Verifier les donnees
k16 exec mysql-0 -n drupal -c mysql -- \
  mysql -uroot -ppGseVnJxiI3wm3vEaKCtOVaVT -e "USE test_restore; SELECT * FROM test;"
```

---

## Nettoyage

### Nettoyage Complet (Recommencer depuis Zero)

```bash
#!/bin/bash
# Sauvegarder en tant que full-cleanup.sh

echo "=== 1. Suppression du cluster K3s sur k8s-master-1-15 ==="
for i in 13 14 15; do
  echo "Nettoyage k8s$i..."
  sshpass -p '<YOUR_SSH_PASSWORD>' ssh -o StrictHostKeyChecking=no \
    formation@k8s$i.example.com \
    "echo '<YOUR_SSH_PASSWORD>' | sudo -S /usr/local/bin/k3s-uninstall.sh" \
    2>&1 | tail -3
done

echo -e "\n=== 2. Nettoyage sur k8s-orchestrator ==="
sshpass -p '<YOUR_SSH_PASSWORD>' ssh -o StrictHostKeyChecking=no \
  formation@k8s-orchestrator.example.com \
  "rm -rf /tmp/k8s-infra /tmp/deploy*.log /tmp/kubeconfig-k3s.yaml"

echo -e "\n=== 3. Suppression NOPASSWD sudo (optionnel) ==="
for i in 13 14 15; do
  sshpass -p '<YOUR_SSH_PASSWORD>' ssh -o StrictHostKeyChecking=no \
    formation@k8s$i.example.com \
    "echo '<YOUR_SSH_PASSWORD>' | sudo -S rm -f /etc/sudoers.d/formation"
done

echo -e "\n=== Nettoyage termine ==="
```

### Nettoyage Partiel (Garder K3s, Redeployer l'Infrastructure)

```bash
# Supprimer uniquement les applications
ssh16 "export KUBECONFIG=/tmp/k8s-infra/ansible/kubeconfig.yaml && \
  kubectl delete namespace drupal monitoring velero --ignore-not-found=true && \
  helm uninstall longhorn -n longhorn-system --ignore-not-found && \
  helm uninstall cert-manager -n cert-manager --ignore-not-found"

# Redeployer l'infrastructure
ssh16 "cd /tmp/k8s-infra && \
  ansible-playbook ansible/playbooks/01-deploy-infrastructure.yml \
  -i ansible/inventory/hosts.yml --vault-password-file ansible/.vault_password"
```

---

## Commandes Utiles

### Raccourcis Kubectl

```bash
# Ajouter a ~/.bashrc sur k8s-orchestrator
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgpa='kubectl get pods --all-namespaces'
alias kgn='kubectl get nodes'
alias kd='kubectl describe'
alias kl='kubectl logs'
alias ke='kubectl exec -it'
alias kaf='kubectl apply -f'
alias kdel='kubectl delete'

export KUBECONFIG=/tmp/k8s-infra/ansible/kubeconfig.yaml
```

### Surveillance Continue

```bash
# Watch tous les pods
watch -n 2 'kubectl get pods --all-namespaces -o wide'

# Watch uniquement les pods en erreur
watch -n 5 'kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded'

# Watch les evenements
kubectl get events --all-namespaces --watch

# Logs en temps reel
kubectl logs -f deployment/drupal -n drupal
```

### Debugging Avance

```bash
# Shell dans un pod
kubectl exec -it mysql-0 -n drupal -c mysql -- bash

# Copier des fichiers depuis/vers un pod
kubectl cp drupal/mysql-0:/var/lib/mysql/error.log ./mysql-error.log
kubectl cp ./test-file.txt drupal/mysql-0:/tmp/test-file.txt

# Executer une commande dans tous les pods MySQL
for i in 0 1 2; do
  echo "=== mysql-$i ==="
  kubectl exec mysql-$i -n drupal -c mysql -- hostname
done

# Top des ressources
kubectl top nodes
kubectl top pods -n drupal
```

### Gestion Helm

```bash
# Lister les releases
helm list -A

# Historique d'une release
helm history drupal-stack -n drupal

# Rollback
helm rollback drupal-stack 1 -n drupal

# Template sans installation (dry-run)
helm template drupal-stack ./helm/charts/drupal-stack -n drupal

# Differences avant upgrade
helm diff upgrade drupal-stack ./helm/charts/drupal-stack -n drupal
```

### Inspection des Ressources

```bash
# Obtenir le YAML d'une ressource
kubectl get pod mysql-0 -n drupal -o yaml

# Format JSON avec jq
kubectl get pod mysql-0 -n drupal -o json | jq '.spec.containers[].image'

# Lister toutes les images utilisees
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\t"}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' | sort | uniq

# Voir les annotations/labels
kubectl get pod mysql-0 -n drupal -o jsonpath='{.metadata.annotations}' | jq
kubectl get pod mysql-0 -n drupal -o jsonpath='{.metadata.labels}' | jq
```

---

## Checklist de Deploiement

###  Pre-deploiement

- [ ] Archive k8s-infra.tar.gz creee et uploadee sur k8s-orchestrator
- [ ] Fichier .env.tmp cree avec les credentials
- [ ] K3s desinstalle sur k8s-master-1, k8s-master-2, k8s-master-3
- [ ] Connexion SSH fonctionnelle vers tous les nuds
- [ ] Corrections appliquees (systemd, hostname, xtrabackup)

###  Pendant le Deploiement

- [ ] Phase 0: Prerequis installes (Ansible, Helm, kubectl)
- [ ] Phase 1: Secrets generes et chiffres
- [ ] Phase 2: Cles SSH configurees
- [ ] Phase 2B: NOPASSWD sudo configure
- [ ] Phase 3: Connectivite Ansible verifiee
- [ ] Phase 4: Cluster K3s installe (3 masters)
- [ ] Phase 5: Infrastructure deployee (Longhorn, Cert-Manager, Drupal, MySQL)
- [ ] Phase 6: Securite configuree
- [ ] Phase 7: Velero configure
- [ ] Phase 8: Ingress configure
- [ ] Phase 9: Monitoring configure
- [ ] Phase 10: Premier backup effectue

###  Post-deploiement

- [ ] Tous les nuds K3s en status "Ready"
- [ ] Tous les pods en status "Running"
- [ ] PVC tous en status "Bound"
- [ ] Services exposes correctement
- [ ] Connectivite MySQL fonctionnelle
- [ ] Replication MySQL active (mysql-1 et mysql-2)
- [ ] Grafana accessible
- [ ] Backup Velero reussi
- [ ] Test de restore reussi

---

## Logs et Fichiers Importants

### Sur k8s-orchestrator

```
/tmp/k8s-infra/                         # Repertoire de travail
/tmp/deploy.log                         # Log du deploiement
/tmp/k8s-infra/ansible/kubeconfig.yaml  # Config kubectl
/tmp/k8s-infra/ansible/.vault_password  # Mot de passe Vault (genere auto)
```

### Sur k8s-master-1/14/15

```
/etc/rancher/k3s/k3s.yaml              # Kubeconfig K3s
/var/lib/rancher/k3s/server/node-token # Token pour joindre le cluster
/var/log/k3s.log                        # Logs K3s (si configure)
journalctl -u k3s                       # Logs systemd K3s
```

### Dans Kubernetes

```bash
# Logs des controleurs
kubectl logs -n kube-system deploy/coredns
kubectl logs -n kube-system deploy/local-path-provisioner

# Logs Longhorn
kubectl logs -n longhorn-system deploy/longhorn-driver-deployer

# Logs MySQL
kubectl logs mysql-0 -n drupal -c mysql --tail=100
kubectl logs mysql-0 -n drupal -c xtrabackup --tail=100
```

---

## Contacts et Ressources

### Documentation
- K3s: https://docs.k3s.io/
- Longhorn: https://longhorn.io/docs/
- Cert-Manager: https://cert-manager.io/docs/
- Velero: https://velero.io/docs/
- Helm: https://helm.sh/docs/

### Commandes de Support

```bash
# Generer un rapport de diagnostic complet
kubectl cluster-info dump --output-directory=/tmp/cluster-dump

# Collecter les logs de tous les pods
for ns in drupal monitoring longhorn-system cert-manager; do
  kubectl logs --all-containers=true --prefix=true -n $ns \
    --selector='!job-name' > /tmp/logs-$ns.txt
done

# Exporter toutes les ressources
kubectl get all --all-namespaces -o yaml > /tmp/all-resources.yaml
```

---

## Notes Finales

### Temps Estimes
- Nettoyage complet: ~2 minutes
- Deploiement K3s: ~8 minutes
- Deploiement infrastructure: ~15-20 minutes
- **Total**: ~40-45 minutes pour un deploiement complet

### Points d'Attention
1. **Toujours** verifier que K3s est demarre apres installation
2. **Toujours** attendre que Longhorn soit pret avant d'installer Drupal
3. Les PVC Longhorn peuvent prendre 1-2 minutes a se bind
4. MySQL prend ~3-5 minutes pour demarrer completement (init + clone + xtrabackup)
5. Le premier pod MySQL (mysql-0) demarre seul, mysql-1 et mysql-2 attendent qu'il soit Ready

### En Cas de Probleme
1. Verifier les logs du pod en erreur
2. Verifier les evenements du namespace
3. Verifier les PVC et PV
4. Verifier les secrets
5. En dernier recours: nettoyage complet et redeploiement

**Bonne chance ! **
