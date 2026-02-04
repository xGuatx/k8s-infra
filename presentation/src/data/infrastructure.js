export const clusterMetrics = {
  nodes: 3,
  masters: 3,
  totalCPU: '3 vCPUs (250m request  6 pods = 1.5 vCPU baseline)',
  totalRAM: '6 GB (32GB, 512Mi request  6 pods = 3GB baseline)',
  storageCapacity: '12 GB total (62Gi PVC: MySQL 32Gi + Drupal 32Gi)',
  uptime: '99.9%'
};

export const components = [
  {
    name: 'K3s',
    version: 'Latest',
    category: 'Orchestration',
    description: 'Distribution Kubernetes legere optimisee pour production',
    icon: '',
    whyChosen: 'Empreinte memoire reduite (< 512MB), installation simplifiee, parfait pour clusters de taille moyenne',
    alternatives: 'Kubernetes vanilla (trop lourd), MicroK8s (moins mature), K0s (moins de documentation)'
  },
  {
    name: 'Longhorn',
    version: 'Latest',
    category: 'Storage',
    description: 'Stockage distribue avec replication 3x pour haute disponibilite',
    icon: '',
    whyChosen: 'Solution native cloud, replication automatique, snapshots integres, interface web intuitive',
    alternatives: 'Ceph (complexe a maintenir), Rook (overhead important), NFS (pas de HA native)'
  },
  {
    name: 'Cert-Manager',
    version: 'v1.16.2',
    category: 'Security',
    description: 'Gestion automatisee des certificats TLS avec renouvellement',
    icon: '',
    whyChosen: 'Standard de facto, integration native Kubernetes, renouvellement automatique Let\'s Encrypt',
    alternatives: 'Certificats manuels (maintenance lourde), Traefik seul (moins de fonctionnalites)'
  },
  {
    name: 'Drupal',
    version: '10-apache',
    category: 'Application',
    description: 'CMS open-source (3 replicas) avec MySQL en replication master-slave (3 replicas)',
    icon: '',
    whyChosen: 'Flexibilite, scalabilite horizontale, ecosysteme riche de modules, communaute active, pod anti-affinity pour HA',
    alternatives: 'WordPress (moins scalable), Joomla (communaute plus petite), CMS custom (cout developpement)'
  },
  {
    name: 'MySQL',
    version: '8.0',
    category: 'Database',
    description: 'Base de donnees relationnelle avec replication master-slave (3 replicas)',
    icon: '',
    whyChosen: 'Performance eprouvee, replication native, compatibilite Drupal, tooling mature',
    alternatives: 'PostgreSQL (moins de plugins Drupal), MariaDB (fork, moins de support), MongoDB (pas relationnel)'
  },
  {
    name: 'Percona XtraDB Cluster',
    version: '8.0',
    category: 'Backup',
    description: 'Image MySQL avec xtrabackup integre pour replication et backup a chaud',
    icon: '',
    whyChosen: 'Backup non bloquant via xtrabackup, restauration rapide, compatibilite MySQL 8.0, replication slave automatique',
    alternatives: 'mysqldump (bloquant), Velero seul (pas de backup MySQL hot), snapshots manuels'
  },
  {
    name: 'Prometheus',
    version: 'Latest (kube-prometheus-stack)',
    category: 'Monitoring',
    description: 'Metriques temps reel de tous les composants du cluster',
    icon: '',
    whyChosen: 'Standard industrie, integration Kubernetes native, PromQL puissant, ecosysteme riche',
    alternatives: 'InfluxDB (moins de support K8s), Datadog (payant), CloudWatch (vendor lock-in)'
  },
  {
    name: 'Grafana',
    version: 'Latest (kube-prometheus-stack)',
    category: 'Visualization',
    description: 'Dashboards interactifs pour visualiser les metriques',
    icon: '',
    whyChosen: 'Visualisation puissante, dashboards pre-configures, alerting integre, multi-sources',
    alternatives: 'Kibana (oriente logs), custom dashboards (temps developpement), Datadog (payant)'
  },
  {
    name: 'AlertManager',
    version: 'Latest',
    category: 'Alerting',
    description: 'Gestion centralisee des alertes et notifications',
    icon: '',
    whyChosen: 'Routing flexible, grouping intelligent, integration Prometheus native, silence management',
    alternatives: 'PagerDuty (payant), OpsGenie (payant), Alerting custom (maintenance)'
  },
  {
    name: 'Velero',
    version: 'Latest',
    category: 'Disaster Recovery',
    description: 'Backup/restore complet du cluster (namespace, PV, secrets)',
    icon: '',
    whyChosen: 'Backup complet cluster, migration facile, restauration granulaire, support multi-cloud',
    alternatives: 'Kasten K10 (payant), Stash (moins mature), scripts custom (risque)'
  },
  {
    name: 'Ansible',
    version: 'Latest',
    category: 'IaC',
    description: 'Automation complete du deploiement et configuration',
    icon: '',
    whyChosen: 'Agentless, playbooks reutilisables, idempotence, courbe apprentissage faible',
    alternatives: 'Terraform (moins adapte config), SaltStack (agent requis), Chef/Puppet (complexes)'
  },
  {
    name: 'Ansible Vault',
    version: 'Latest',
    category: 'Security',
    description: 'Chiffrement des secrets (passwords, API keys)',
    icon: '',
    whyChosen: 'Integre Ansible, chiffrement AES-256, rotation facile, pas de service externe',
    alternatives: 'HashiCorp Vault (complexe), Sealed Secrets (moins flexible), Git-crypt (moins securise)'
  }
];

export const architecture = {
  layers: [
    {
      name: 'Infrastructure',
      nodes: ['k8s-master-1', 'k8s-master-2', 'k8s-master-3'],
      description: '3 nuds masters en mode embedded etcd pour HA native'
    },
    {
      name: 'Storage',
      components: ['Longhorn'],
      description: 'Replication 3x sur tous les nuds, snapshots quotidiens'
    },
    {
      name: 'Application',
      components: ['Drupal (3 replicas)', 'MySQL (3 replicas master-slave)'],
      description: 'Anti-affinity pour distribution sur nuds separes'
    },
    {
      name: 'Monitoring',
      components: ['Prometheus', 'Grafana', 'AlertManager'],
      description: 'Visibilite complete + alerting automatique'
    }
  ]
};

export const haFeatures = [
  {
    feature: 'Cluster K3s',
    implementation: '3 masters avec embedded etcd',
    survivability: 'Perte de 1 nud sans impact'
  },
  {
    feature: 'MySQL',
    implementation: '1 master + 2 slaves avec replication synchrone',
    survivability: 'Failover automatique si master down'
  },
  {
    feature: 'Drupal',
    implementation: '3 replicas avec pod anti-affinity',
    survivability: 'Service maintenu avec 1-2 pods actifs'
  },
  {
    feature: 'Longhorn Storage',
    implementation: 'Replication 3x de tous les volumes',
    survivability: 'Donnees accessibles meme si 2 nuds down'
  },
  {
    feature: 'Cert-Manager',
    implementation: '3 replicas (controller + webhook + cainjector)',
    survivability: 'Renouvellement TLS maintenu'
  },
  {
    feature: 'Monitoring',
    implementation: 'Prometheus + Grafana avec PVC persistants',
    survivability: 'Metriques historiques preservees'
  }
];

export const disasterRecovery = {
  backupStrategy: [
    {
      type: 'Secrets',
      frequency: 'Lors du deploiement',
      location: '/opt/k8s-backups sur k8s-orchestrator',
      tools: 'Ansible Vault + GPG'
    },
    {
      type: 'MySQL Data',
      frequency: 'Quotidien (2h AM)',
      location: '/opt/k8s-backups sur k8s-orchestrator',
      tools: 'Percona XtraBackup'
    },
    {
      type: 'Drupal Files',
      frequency: 'Quotidien (2h AM)',
      location: '/opt/k8s-backups sur k8s-orchestrator',
      tools: 'tar + rsync'
    },
    {
      type: 'Cluster State',
      frequency: 'Quotidien (2h AM)',
      location: '/opt/k8s-backups sur k8s-orchestrator',
      tools: 'Velero'
    },
    {
      type: 'Longhorn Volumes',
      frequency: 'Snapshots automatiques',
      location: 'Longhorn internal',
      tools: 'Longhorn'
    }
  ],
  retention: '7 jours',
  rto: '30-45 minutes',
  rpo: '24 heures',
  recoveryScenarios: [
    {
      scenario: 'Perte d\'un nud',
      action: 'Automatique',
      downtime: '0 secondes',
      steps: ['K8s reschedule automatiquement les pods sur nuds sains']
    },
    {
      scenario: 'Perte de 2 nuds',
      action: 'Manuel',
      downtime: '5-10 minutes',
      steps: ['Attendre retour d\'un nud', 'Cluster reprend automatiquement']
    },
    {
      scenario: 'Perte totale cluster (3 nuds)',
      action: 'Restore complet',
      downtime: '30-45 minutes',
      steps: [
        '1. Creer .env.tmp avec SSH_PASSWORD',
        '2. Executer ./restore.sh sur k8s-orchestrator',
        '3. Script restaure secrets + cluster + donnees',
        '4. Verification kubectl get nodes'
      ]
    },
    {
      scenario: 'Corruption base MySQL',
      action: 'Restore MySQL',
      downtime: '10-15 minutes',
      steps: [
        '1. Identifier backup a restaurer',
        '2. Stopper pods MySQL',
        '3. Restaurer depuis /opt/k8s-backups',
        '4. Redemarrer pods'
      ]
    }
  ]
};

export const deploymentProcess = {
  steps: [
    { phase: 'Preparation', time: '2 min', description: 'Creation .env.tmp, upload archive sur k8s-orchestrator' },
    { phase: 'SSH Config', time: '3 min', description: 'Configuration cles SSH sans password' },
    { phase: 'K3s Bootstrap', time: '10 min', description: 'Installation K3s sur 3 nuds + formation cluster etcd' },
    { phase: 'Longhorn', time: '8 min', description: 'Deploiement storage distribue avec replication 3x' },
    { phase: 'Cert-Manager', time: '5 min', description: 'Installation gestionnaire certificats TLS' },
    { phase: 'Drupal Stack', time: '12 min', description: 'MySQL (StatefulSet 3 replicas) + Drupal (Deployment 3 replicas)' },
    { phase: 'Monitoring', time: '10 min', description: 'Prometheus + Grafana + AlertManager' },
    { phase: 'Backup Setup', time: '5 min', description: 'Configuration backups automatiques + Velero' }
  ],
  totalTime: '45 minutes',
  automation: '100% automatise',
  idempotent: true
};

export const technicalChoices = [
  {
    choice: 'K3s vs Kubernetes vanilla',
    reason: 'K3s utilise < 512MB RAM vs 2-4GB pour K8s standard',
    impact: 'Cluster operationnel sur infrastructure modeste',
    tradeoff: 'Moins de composants optionnels (mais suffisants pour notre usage)'
  },
  {
    choice: 'Embedded etcd vs external',
    reason: 'Simplicite deploiement, moins de composants a maintenir',
    impact: '3 nuds suffisent (pas besoin de nuds etcd dedies)',
    tradeoff: 'Legere augmentation charge masters (negligeable avec 3 nuds)'
  },
  {
    choice: 'StatefulSet MySQL vs Operator',
    reason: 'Controle total, pas de dependance externe, apprentissage Kubernetes',
    impact: 'Configuration sur mesure, init containers custom',
    tradeoff: 'Maintenance manuelle failover (acceptable pour formation)'
  },
  {
    choice: 'Longhorn vs Ceph',
    reason: 'Longhorn: installation 5min, UI intuitive. Ceph: configuration complexe',
    impact: 'Equipe operationnelle immediatement',
    tradeoff: 'Longhorn moins mature que Ceph (mais largement suffisant)'
  },
  {
    choice: 'Ansible vs Terraform',
    reason: 'Ansible: configuration ET deploiement. Terraform: infra principalement',
    impact: 'Un seul outil pour tout le pipeline',
    tradeoff: 'Moins adapte si besoin multi-cloud (non requis ici)'
  },
  {
    choice: 'Prometheus vs solutions proprietaires',
    reason: 'Standard open-source, pas de vendor lock-in, communaute massive',
    impact: 'Portabilite, pas de couts licensing',
    tradeoff: 'Necessite configuration manuelle dashboards (compense par kube-prometheus-stack)'
  },
  {
    choice: 'PVC 2GB vs demandes initiales plus elevees',
    reason: 'Ressources limitees (3 nuds formation), init containers bloquaient avec PVC > 5GB',
    impact: 'Tous les pods demarrent sans erreur OutOfDisk, total 12GB (MySQL 6GB + Drupal 6GB)',
    tradeoff: 'Espace reduit mais amplement suffisant pour CMS + base de donnees de demonstration'
  },
  {
    choice: 'NodePort vs LoadBalancer/Ingress',
    reason: 'Simplicite acces direct, pas de dependance cloud provider',
    impact: 'Acces immediat via IP:port sans configuration DNS',
    tradeoff: 'Pas de load balancing externe (non critique avec 3 nuds HA)'
  }
];

export const challenges = [
  {
    challenge: 'PVC trop volumineux bloquant init containers',
    solution: 'Reduction a 2GB apres analyse des besoins reels',
    lesson: 'Toujours dimensionner selon ressources disponibles, pas specs theoriques'
  },
  {
    challenge: 'hostname command inexistant dans containers MySQL',
    solution: 'Remplacement $(hostname) par variable $HOSTNAME',
    lesson: 'Images Docker minimalistes = verifier commandes disponibles'
  },
  {
    challenge: 'Image xtrabackup Google depreciee',
    solution: 'Migration vers image Percona officielle et maintenue',
    lesson: 'Toujours utiliser images officielles avec support long terme'
  },
  {
    challenge: 'MySQL probes echouant sans authentification',
    solution: 'Ajout $MYSQL_ROOT_PASSWORD dans commandes liveness/readiness',
    lesson: 'Les probes doivent respecter securite application'
  },
  {
    challenge: 'Cert-Manager en 1 replica = pas de HA',
    solution: 'Configuration 3 replicas (controller + webhook + cainjector)',
    lesson: 'Penser HA des le depart, pas en reaction a incident'
  },
  {
    challenge: 'Longhorn lent a nettoyer lors k3s-uninstall',
    solution: 'Patience + timeout augmentes, nettoyage automatise',
    lesson: 'Storage distribue = temps nettoyage significatif'
  }
];
