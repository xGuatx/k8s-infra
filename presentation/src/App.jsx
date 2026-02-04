import React, { useState, useEffect } from 'react';
import {
  clusterMetrics,
  components,
  haFeatures,
  disasterRecovery,
  deploymentProcess,
  technicalChoices,
  challenges
} from './data/infrastructure';
import mermaid from 'mermaid';

function App() {
  const [activeTab, setActiveTab] = useState('overview');

  useEffect(() => {
    mermaid.initialize({
      startOnLoad: true,
      theme: 'default',
      securityLevel: 'loose'
    });
    mermaid.contentLoaded();
  }, [activeTab]);

  return (
    <div className="container">
      <header style={{
        background: 'white',
        borderRadius: '12px',
        padding: '32px',
        marginBottom: '20px',
        textAlign: 'center',
        boxShadow: '0 4px 6px rgba(0, 0, 0, 0.1)'
      }}>
        <h1 style={{
          fontSize: '2.5rem',
          background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
          WebkitBackgroundClip: 'text',
          WebkitTextFillColor: 'transparent',
          marginBottom: '12px'
        }}>
           Infrastructure K3s Haute Disponibilite
        </h1>
        <p style={{ color: '#64748b', fontSize: '1.1rem' }}>
          Plateforme Kubernetes production-ready avec monitoring, backup et disaster recovery
        </p>
      </header>

      <div className="tab-container">
        <div className="tabs">
          <button
            className={`tab ${activeTab === 'overview' ? 'active' : ''}`}
            onClick={() => setActiveTab('overview')}
          >
             Vue d'ensemble
          </button>
          <button
            className={`tab ${activeTab === 'architecture' ? 'active' : ''}`}
            onClick={() => setActiveTab('architecture')}
          >
             Architecture
          </button>
          <button
            className={`tab ${activeTab === 'components' ? 'active' : ''}`}
            onClick={() => setActiveTab('components')}
          >
             Composants
          </button>
          <button
            className={`tab ${activeTab === 'ha' ? 'active' : ''}`}
            onClick={() => setActiveTab('ha')}
          >
             Haute Disponibilite
          </button>
          <button
            className={`tab ${activeTab === 'dr' ? 'active' : ''}`}
            onClick={() => setActiveTab('dr')}
          >
             Disaster Recovery
          </button>
          <button
            className={`tab ${activeTab === 'choices' ? 'active' : ''}`}
            onClick={() => setActiveTab('choices')}
          >
             Choix Techniques
          </button>
          <button
            className={`tab ${activeTab === 'challenges' ? 'active' : ''}`}
            onClick={() => setActiveTab('challenges')}
          >
             Defis & Solutions
          </button>
        </div>
      </div>

      {activeTab === 'overview' && <OverviewTab />}
      {activeTab === 'architecture' && <ArchitectureTab />}
      {activeTab === 'components' && <ComponentsTab />}
      {activeTab === 'ha' && <HATab />}
      {activeTab === 'dr' && <DRTab />}
      {activeTab === 'choices' && <ChoicesTab />}
      {activeTab === 'challenges' && <ChallengesTab />}
    </div>
  );
}

function OverviewTab() {
  return (
    <>
      <div className="grid grid-3">
        <div className="metric-card">
          <h3>{clusterMetrics.nodes}</h3>
          <p>Nuds Masters</p>
        </div>
        <div className="metric-card">
          <h3>{clusterMetrics.totalRAM}</h3>
          <p>RAM Totale</p>
        </div>
        <div className="metric-card">
          <h3>{clusterMetrics.uptime}</h3>
          <p>Disponibilite Cible</p>
        </div>
      </div>

      <div className="card">
        <h2> Objectifs du Projet</h2>
        <ul>
          <li><strong>Haute Disponibilite:</strong> Cluster survivant a la perte d'un nud complet</li>
          <li><strong>Automatisation Complete:</strong> Deploiement 100% automatise via Ansible (45 minutes)</li>
          <li><strong>Disaster Recovery:</strong> Restauration complete possible en 30-45 minutes</li>
          <li><strong>Monitoring:</strong> Visibilite temps reel sur tous les composants</li>
          <li><strong>Securite:</strong> Secrets chiffres, TLS automatise, backups GPG</li>
        </ul>
      </div>

      <div className="card">
        <h2> Stack Technique</h2>
        <div className="grid grid-2">
          <div>
            <h3>Orchestration</h3>
            <span className="badge badge-primary">K3s (Kubernetes)</span>
            <span className="badge badge-primary">3 Masters</span>
            <span className="badge badge-primary">Embedded etcd</span>
          </div>
          <div>
            <h3>Storage</h3>
            <span className="badge badge-success">Longhorn</span>
            <span className="badge badge-success">Replication 3x</span>
            <span className="badge badge-success">Snapshots</span>
          </div>
          <div>
            <h3>Application</h3>
            <span className="badge badge-warning">Drupal</span>
            <span className="badge badge-warning">MySQL 8.0</span>
            <span className="badge badge-warning">3 Replicas</span>
          </div>
          <div>
            <h3>Monitoring</h3>
            <span className="badge badge-secondary">Prometheus</span>
            <span className="badge badge-secondary">Grafana</span>
            <span className="badge badge-secondary">AlertManager</span>
          </div>
        </div>
      </div>

      <div className="card">
        <h2> Points Forts</h2>
        <div className="grid grid-2">
          <div>
            <h3> Resilience</h3>
            <p>Tolerance a la panne d'un nud sans perte de service</p>
          </div>
          <div>
            <h3> Automatisation</h3>
            <p>Deploiement complet sans intervention manuelle</p>
          </div>
          <div>
            <h3> Observabilite</h3>
            <p>Metriques, logs et dashboards temps reel</p>
          </div>
          <div>
            <h3> Recuperation</h3>
            <p>Restauration complete depuis backups quotidiens</p>
          </div>
        </div>
      </div>
    </>
  );
}

function ArchitectureTab() {
  useEffect(() => {
    mermaid.contentLoaded();
  }, []);

  const clusterDiagram = `
graph TB
    subgraph "Infrastructure Layer"
        K13[k8s-master-1<br/>Master + etcd]
        K14[k8s-master-2<br/>Master + etcd]
        K15[k8s-master-3<br/>Master + etcd]
    end

    subgraph "Storage Layer"
        L1[Longhorn<br/>Replica 1]
        L2[Longhorn<br/>Replica 2]
        L3[Longhorn<br/>Replica 3]
    end

    subgraph "Application Layer"
        D1[Drupal Pod 1]
        D2[Drupal Pod 2]
        D3[Drupal Pod 3]
        M1[MySQL Master]
        M2[MySQL Slave 1]
        M3[MySQL Slave 2]
    end

    subgraph "Monitoring Layer"
        P[Prometheus]
        G[Grafana]
        A[AlertManager]
    end

    K13 -.->|etcd sync| K14
    K14 -.->|etcd sync| K15
    K15 -.->|etcd sync| K13

    K13 --> L1
    K14 --> L2
    K15 --> L3

    L1 -.->|replicate| L2
    L2 -.->|replicate| L3
    L3 -.->|replicate| L1

    D1 --> M1
    D2 --> M1
    D3 --> M1

    M1 -->|replicate| M2
    M1 -->|replicate| M3

    P -.->|scrape| K13
    P -.->|scrape| K14
    P -.->|scrape| K15
    G --> P
    A --> P

    style K13 fill:#667eea
    style K14 fill:#667eea
    style K15 fill:#667eea
    style M1 fill:#f59e0b
    style M2 fill:#10b981
    style M3 fill:#10b981
  `;

  const deploymentFlow = `
graph LR
    A[.env.tmp] --> B[deploy.sh]
    B --> C[SSH Config]
    C --> D[K3s Bootstrap]
    D --> E[Longhorn]
    E --> F[Cert-Manager]
    F --> G[MySQL StatefulSet]
    G --> H[Drupal Deployment]
    H --> I[Monitoring Stack]
    I --> J[Backup Setup]
    J --> K[ Production Ready]

    style A fill:#fef3c7
    style K fill:#d1fae5
  `;

  return (
    <>
      <div className="card">
        <h2> Architecture Globale</h2>
        <div className="alert alert-info">
          <strong>Architecture 3-tiers HA:</strong> Separation claire entre infrastructure,
          storage, application et monitoring. Chaque couche est resiliente a la panne d'un composant.
        </div>
        <div className="mermaid">{clusterDiagram}</div>
      </div>

      <div className="card">
        <h2> Flux de Deploiement</h2>
        <p>Processus automatise end-to-end en 45 minutes</p>
        <div className="mermaid">{deploymentFlow}</div>

        <h3 style={{ marginTop: '20px' }}> Detail des Phases</h3>
        <table className="comparison-table">
          <thead>
            <tr>
              <th>Phase</th>
              <th>Duree</th>
              <th>Description</th>
            </tr>
          </thead>
          <tbody>
            {deploymentProcess.steps.map((step, idx) => (
              <tr key={idx}>
                <td><strong>{step.phase}</strong></td>
                <td>{step.time}</td>
                <td>{step.description}</td>
              </tr>
            ))}
          </tbody>
        </table>

        <div className="alert alert-success" style={{ marginTop: '16px' }}>
          <strong>Total: {deploymentProcess.totalTime}</strong> -
          {' '}{deploymentProcess.automation} -
          {' '}Idempotent: {deploymentProcess.idempotent ? '' : ''}
        </div>
      </div>

      <div className="card">
        <h2> Acces Services</h2>
        <ul>
          <li><strong>Drupal:</strong> http://k8s-master-1.example.com:30080</li>
          <li><strong>Grafana:</strong> http://k8s-master-1.example.com:30300</li>
          <li><strong>Prometheus:</strong> http://k8s-master-1.example.com:30090</li>
          <li><strong>AlertManager:</strong> http://k8s-master-1.example.com:30903</li>
          <li><strong>Longhorn UI:</strong> http://k8s-master-1.example.com:30880</li>
        </ul>
      </div>
    </>
  );
}

function ComponentsTab() {
  const [category, setCategory] = useState('all');
  const categories = ['all', 'Orchestration', 'Storage', 'Security', 'Application', 'Database', 'Backup', 'Monitoring', 'Visualization', 'Alerting', 'Disaster Recovery', 'IaC'];

  const filtered = category === 'all'
    ? components
    : components.filter(c => c.category === category);

  return (
    <>
      <div className="card">
        <h2> Stack Technologique Complete</h2>
        <p>Selectionnez une categorie pour filtrer les composants</p>
        <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', marginTop: '16px' }}>
          {categories.map(cat => (
            <button
              key={cat}
              onClick={() => setCategory(cat)}
              className={`badge ${category === cat ? 'badge-primary' : 'badge-secondary'}`}
              style={{ cursor: 'pointer', border: 'none' }}
            >
              {cat === 'all' ? 'Tous' : cat}
            </button>
          ))}
        </div>
      </div>

      {filtered.map((comp, idx) => (
        <div className="card" key={idx}>
          <h2>{comp.icon} {comp.name} <span className="badge badge-success">{comp.category}</span></h2>
          <p><strong>Version:</strong> {comp.version}</p>
          <p>{comp.description}</p>

          <h3 style={{ marginTop: '16px', color: '#2563eb' }}> Pourquoi ce choix ?</h3>
          <p>{comp.whyChosen}</p>

          <h3 style={{ marginTop: '16px', color: '#f59e0b' }}> Alternatives evaluees</h3>
          <p>{comp.alternatives}</p>
        </div>
      ))}
    </>
  );
}

function HATab() {
  return (
    <>
      <div className="card">
        <h2> Strategie Haute Disponibilite</h2>
        <div className="alert alert-warning">
          <strong>Principe:</strong> Toute panne d'un composant unique ne doit PAS entrainer
          d'interruption de service. Architecture N+1 sur tous les composants critiques.
        </div>
      </div>

      <div className="card">
        <h2> Resilience par Composant</h2>
        <table className="comparison-table">
          <thead>
            <tr>
              <th>Composant</th>
              <th>Implementation HA</th>
              <th>Resistance Pannes</th>
            </tr>
          </thead>
          <tbody>
            {haFeatures.map((feature, idx) => (
              <tr key={idx}>
                <td><strong>{feature.feature}</strong></td>
                <td>{feature.implementation}</td>
                <td><span className="badge badge-success">{feature.survivability}</span></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <div className="card">
        <h2> Tests de Resilience</h2>
        <div className="grid grid-2">
          <div className="alert alert-success">
            <h3> Test 1: Perte d'un nud</h3>
            <p><strong>Action:</strong> Arret brutal k8s-master-1</p>
            <p><strong>Resultat attendu:</strong> Pods reschedules automatiquement sur k8s-master-2/k8s-master-3</p>
            <p><strong>Downtime:</strong> 0 secondes</p>
          </div>
          <div className="alert alert-success">
            <h3> Test 2: Perte MySQL master</h3>
            <p><strong>Action:</strong> Kill pod mysql-0</p>
            <p><strong>Resultat attendu:</strong> Drupal bascule sur replicas, master redemarre</p>
            <p><strong>Downtime:</strong> &lt; 30 secondes</p>
          </div>
          <div className="alert alert-warning">
            <h3> Test 3: Perte de 2 nuds</h3>
            <p><strong>Action:</strong> Arret k8s-master-1 + k8s-master-2</p>
            <p><strong>Resultat attendu:</strong> Cluster perd quorum etcd, mode degrade</p>
            <p><strong>Downtime:</strong> Jusqu'a retour d'un nud</p>
          </div>
          <div className="alert alert-info">
            <h3> Test 4: Restauration complete</h3>
            <p><strong>Action:</strong> Destruction 3 nuds + restore depuis k8s-orchestrator</p>
            <p><strong>Resultat attendu:</strong> Cluster reconstruit avec donnees</p>
            <p><strong>Downtime:</strong> 30-45 minutes</p>
          </div>
        </div>
      </div>
    </>
  );
}

function DRTab() {
  return (
    <>
      <div className="card">
        <h2> Strategie Disaster Recovery</h2>
        <div className="grid grid-2">
          <div className="metric-card">
            <h3>{disasterRecovery.rto}</h3>
            <p>RTO (Recovery Time Objective)</p>
          </div>
          <div className="metric-card">
            <h3>{disasterRecovery.rpo}</h3>
            <p>RPO (Recovery Point Objective)</p>
          </div>
        </div>
      </div>

      <div className="card">
        <h2> Strategie de Backup</h2>
        <table className="comparison-table">
          <thead>
            <tr>
              <th>Type</th>
              <th>Frequence</th>
              <th>Emplacement</th>
              <th>Outils</th>
            </tr>
          </thead>
          <tbody>
            {disasterRecovery.backupStrategy.map((backup, idx) => (
              <tr key={idx}>
                <td><strong>{backup.type}</strong></td>
                <td>{backup.frequency}</td>
                <td><code>{backup.location}</code></td>
                <td><span className="badge badge-primary">{backup.tools}</span></td>
              </tr>
            ))}
          </tbody>
        </table>
        <div className="alert alert-info" style={{ marginTop: '16px' }}>
          <strong>Retention:</strong> {disasterRecovery.retention} -
          Nettoyage automatique des backups anciens
        </div>
      </div>

      <div className="card">
        <h2> Scenarios de Recuperation</h2>
        {disasterRecovery.recoveryScenarios.map((scenario, idx) => (
          <div key={idx} style={{ marginBottom: '24px' }}>
            <h3>{scenario.scenario}</h3>
            <div style={{ display: 'flex', gap: '16px', marginBottom: '12px' }}>
              <span className="badge badge-warning">Action: {scenario.action}</span>
              <span className="badge badge-danger">Downtime: {scenario.downtime}</span>
            </div>
            <ol>
              {scenario.steps.map((step, sidx) => (
                <li key={sidx} style={{ marginBottom: '8px' }}>{step}</li>
              ))}
            </ol>
          </div>
        ))}
      </div>

      <div className="card">
        <h2> Fichiers Critiques a Sauvegarder</h2>
        <div className="alert alert-warning">
          <h3> Sans ces fichiers, restauration = IMPOSSIBLE</h3>
          <ul>
            <li><code>/tmp/k8s-infra/CREDENTIALS.txt</code> - Tous les mots de passe</li>
            <li><code>/tmp/k8s-infra/ansible/.vault_password</code> - Cle dechiffrement Ansible Vault</li>
            <li><code>/tmp/k8s-infra/backup-gpg-private.key</code> - Cle dechiffrement backups GPG</li>
            <li><code>/tmp/k8s-infra/.env.tmp</code> - Mots de passe SSH/Sudo</li>
          </ul>
          <p style={{ marginTop: '16px' }}>
            <strong>Recommandation:</strong> Sauvegarder dans KeePass/1Password/Bitwarden
            immediatement apres le premier deploiement
          </p>
        </div>
      </div>
    </>
  );
}

function ChoicesTab() {
  return (
    <>
      <div className="card">
        <h2> Justification des Choix Techniques</h2>
        <p>Chaque decision architecturale a ete prise en evaluant les alternatives et en pesant les trade-offs.</p>
      </div>

      {technicalChoices.map((choice, idx) => (
        <div className="card" key={idx}>
          <h2> {choice.choice}</h2>
          <div className="grid grid-2">
            <div>
              <h3 style={{ color: '#10b981' }}> Raison du Choix</h3>
              <p>{choice.reason}</p>
            </div>
            <div>
              <h3 style={{ color: '#2563eb' }}> Impact</h3>
              <p>{choice.impact}</p>
            </div>
          </div>
          <div className="alert alert-warning" style={{ marginTop: '16px' }}>
            <h3> Trade-off</h3>
            <p>{choice.tradeoff}</p>
          </div>
        </div>
      ))}

      <div className="card">
        <h2> Principes Directeurs</h2>
        <div className="grid grid-2">
          <div>
            <h3>1. Simplicite  &gt; Complexite</h3>
            <p>Technologies matures avec documentation abondante</p>
          </div>
          <div>
            <h3>2. Open Source  &gt; Proprietaire</h3>
            <p>Pas de vendor lock-in, communaute active</p>
          </div>
          <div>
            <h3>3. Automatisation  &gt; Manuel</h3>
            <p>Infrastructure as Code, reproductibilite</p>
          </div>
          <div>
            <h3>4. Observabilite  &gt; Boite Noire</h3>
            <p>Metriques, logs, alertes sur tous les composants</p>
          </div>
        </div>
      </div>
    </>
  );
}

function ChallengesTab() {
  return (
    <>
      <div className="card">
        <h2> Defis Rencontres & Solutions Apportees</h2>
        <p>Retour d'experience sur les obstacles techniques et leur resolution.</p>
      </div>

      {challenges.map((challenge, idx) => (
        <div className="card" key={idx}>
          <h2> Defi #{idx + 1}: {challenge.challenge}</h2>
          <div className="alert alert-warning">
            <h3> Probleme Rencontre</h3>
            <p>{challenge.challenge}</p>
          </div>
          <div className="alert alert-success">
            <h3> Solution Appliquee</h3>
            <p>{challenge.solution}</p>
          </div>
          <div className="alert alert-info">
            <h3> Lecon Apprise</h3>
            <p>{challenge.lesson}</p>
          </div>
        </div>
      ))}

      <div className="card">
        <h2> Evolution du Projet</h2>
        <table className="comparison-table">
          <thead>
            <tr>
              <th>Iteration</th>
              <th>Probleme</th>
              <th>Correction</th>
              <th>Temps Resolution</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>1</td>
              <td>Timeout K3s API</td>
              <td>Ajout systemd start K3s</td>
              <td>2h debugging + 30min fix</td>
            </tr>
            <tr>
              <td>2</td>
              <td>hostname command not found</td>
              <td>Remplace par $HOSTNAME</td>
              <td>1h debugging + 10min fix</td>
            </tr>
            <tr>
              <td>3</td>
              <td>xtrabackup ImagePullBackOff</td>
              <td>Migration vers Percona official</td>
              <td>30min recherche + 10min fix</td>
            </tr>
            <tr>
              <td>4</td>
              <td>MySQL CrashLoopBackOff</td>
              <td>Fix probes avec authentification</td>
              <td>3h debugging + 20min fix</td>
            </tr>
            <tr>
              <td>5</td>
              <td>PVC bloquant init containers</td>
              <td>Reduction a 2GB</td>
              <td>2h investigation + 15min fix</td>
            </tr>
            <tr>
              <td>6</td>
              <td>Cert-Manager pas HA</td>
              <td>Configuration 3 replicas</td>
              <td>1h audit + 15min fix</td>
            </tr>
          </tbody>
        </table>
      </div>

      <div className="card">
        <h2> Competences Developpees</h2>
        <div className="grid grid-3">
          <div className="badge badge-primary">Kubernetes/K3s</div>
          <div className="badge badge-primary">StatefulSets</div>
          <div className="badge badge-primary">Helm Charts</div>
          <div className="badge badge-success">Ansible</div>
          <div className="badge badge-success">Ansible Vault</div>
          <div className="badge badge-success">Infrastructure as Code</div>
          <div className="badge badge-warning">MySQL Replication</div>
          <div className="badge badge-warning">Backup Strategies</div>
          <div className="badge badge-warning">Disaster Recovery</div>
          <div className="badge badge-secondary">Prometheus</div>
          <div className="badge badge-secondary">Grafana</div>
          <div className="badge badge-secondary">Observabilite</div>
        </div>
      </div>
    </>
  );
}

export default App;
