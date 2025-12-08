# Real-Time Log Analytics with Confluent, Dremio & Apache Iceberg <!-- omit in toc -->

This workshop demonstrates a real-time log analytics pipeline that streams Kubernetes logs into a queryable data lakehouse. The architecture combines Confluent Platform for streaming, Apache Iceberg for table format, and Dremio for SQL analytics - all deployed on Kubernetes using GitOps principles with ArgoCD.

**What You'll Build**: A complete pipeline that captures every log from your Kubernetes cluster, streams it through Kafka, transforms it into Iceberg tables, and makes it instantly queryable through Dremio's SQL interface - enabling real-time log analytics, troubleshooting, and observability at scale.

## Table of Contents <!-- omit in toc -->

- [Architecture Overview](#architecture-overview)
  - [Data Flow Pipeline](#data-flow-pipeline)
    - [Pipeline Stages Explained](#pipeline-stages-explained)
    - [Key Benefits of This Architecture](#key-benefits-of-this-architecture)
- [Prerequisites](#prerequisites)
  - [Required Software](#required-software)
  - [System Requirements](#system-requirements)
- [Setup Instructions](#setup-instructions)
  - [Step 1: Fork This Repository](#step-1-fork-this-repository)
  - [Step 2: Configure Private Repository Access (If Applicable)](#step-2-configure-private-repository-access-if-applicable)
  - [Step 3: Configure Kubernetes Context](#step-3-configure-kubernetes-context)
  - [Step 4: Configure Dremio Secrets](#step-4-configure-dremio-secrets)
  - [Step 5: Build Iceberg Kafka Connector (Optional)](#step-5-build-iceberg-kafka-connector-optional)
  - [Step 6: Deploy the Stack](#step-6-deploy-the-stack)
  - [Step 7: Monitor Deployment](#step-7-monitor-deployment)
- [Post-Deployment Configuration](#post-deployment-configuration)
  - [1. Update Personal Access Token (PAT) in Kafka Connector](#1-update-personal-access-token-pat-in-kafka-connector)
  - [2. Create Dremio Source for MinIO](#2-create-dremio-source-for-minio)
  - [Common Issues](#common-issues)
- [Useful Resources](#useful-resources)

## Architecture Overview

The workshop sets up the following components:

- **Confluent Platform**: Full Kafka ecosystem with KRaft controllers, Schema Registry, Connect, ksqlDB, and Control Center
- **Dremio**: Data lakehouse platform with Iceberg catalog support
- **Apache Iceberg**: Table format for data lakes with Kafka Connect integration
- **Fluent Bit**: Log aggregation and forwarding to Kafka
- **MinIO**: S3-compatible object storage for Iceberg tables
- **ArgoCD**: GitOps continuous deployment

### Data Flow Pipeline

The workshop implements a complete log analytics pipeline with the following data flow:

```mermaid
graph TB
    subgraph k8s["Kubernetes Cluster"]
        pods["Pod Logs<br/>(stdout/stderr)<br/>All Namespaces"]

        subgraph fluent["Log Collection Layer"]
            fb["Fluent Bit<br/>(DaemonSet)<br/>Collects & enriches logs<br/>with K8s metadata"]
        end

        subgraph confluent["Confluent Platform"]
            kafka["Kafka Brokers (3 nodes)<br/>📨 Topic: fluent-bit<br/>⏱️ Retention: 1h / 500MB<br/>🔒 SASL_SSL encrypted"]
            connect["Kafka Connect (3 workers)<br/>Iceberg Sink Connector<br/>⚙️ Batch commits every 60s"]
        end

        subgraph dremio["Dremio Platform"]
            catalog["Dremio Catalog Services<br/>REST Catalog API<br/>🔐 OAuth2 authentication<br/>Table: fluent_bit.logs"]
            coordinator["Dremio Coordinator + Executors<br/>🔍 SQL Query Engine<br/>⏮️ Time travel queries<br/>📈 Real-time analytics"]
        end

        subgraph storage["Object Storage"]
            minio["MinIO (S3-compatible)<br/>Bucket: dremio<br/>Parquet data files<br/>Iceberg metadata"]
        end
    end

    pods ==>|"JSON logs with<br/>K8s metadata"| fb
    fb ==>|"Streaming events<br/>(encrypted)"| kafka
    kafka ==>|"Consume from<br/>fluent-bit topic"| connect
    connect ==>|"Iceberg write ops<br/>(REST API)"| catalog
    catalog ==>|"Parquet files +<br/>metadata"| minio
    minio -.->|"Read Iceberg<br/>tables"| coordinator

    style pods fill:#e1f5ff,stroke:#0288d1,stroke-width:2px,color:#000
    style fb fill:#fff3e0,stroke:#f57c00,stroke-width:2px,color:#000
    style kafka fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px,color:#000
    style connect fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px,color:#000
    style catalog fill:#e8f5e9,stroke:#388e3c,stroke-width:2px,color:#000
    style coordinator fill:#e8f5e9,stroke:#388e3c,stroke-width:2px,color:#000
    style minio fill:#fce4ec,stroke:#c2185b,stroke-width:2px,color:#000

    style k8s fill:none,stroke:#424242,stroke-width:3px,color:#000
    style fluent fill:none,stroke:#f57c00,stroke-width:2px,stroke-dasharray: 5 5,color:#000
    style confluent fill:none,stroke:#7b1fa2,stroke-width:2px,stroke-dasharray: 5 5,color:#000
    style dremio fill:none,stroke:#388e3c,stroke-width:2px,stroke-dasharray: 5 5,color:#000
    style storage fill:none,stroke:#c2185b,stroke-width:2px,stroke-dasharray: 5 5,color:#000
```

#### Pipeline Stages Explained

1. **Log Collection (Fluent Bit)**: Fluent Bit runs as a DaemonSet on every Kubernetes node, automatically discovering and tailing logs from all running pods. It enriches each log entry with Kubernetes metadata, such as the namespace, pod name, and labels. It also applies custom filters and formats everything as structured JSON for easier downstream processing.

2. **Stream Buffering (Kafka)**: All collected logs are streamed into Kafka, landing on the fluent-bit topic. Kafka acts as a durable buffer with a one-hour retention window, ensuring that no logs are lost even during processing slowdowns. This setup decouples log collection from processing, providing replay capability and handling backpressure gracefully.

3. **Lakehouse Integration (Iceberg Sink Connector)**: An Iceberg Sink Connector consumes logs from Kafka in small, continuous batches. It automatically creates and manages an Iceberg table named fluent_bit.logs, converting JSON logs into Parquet files for efficient analytics and storage. Data is committed every 60 seconds, making logs available for near-real-time analysis, while schema evolution is handled automatically as log formats change.

4. **Catalog Management (Dremio Catalog Services)**: The Dremio Catalog Services component exposes a REST-based Catalog API used for managing Iceberg operations. It maintains table metadata, schema versions, and snapshots while enforcing ACID guarantees for concurrent writes. Authentication is handled via OAuth2 using a personal access token.

5. **Object Storage (MinIO)**: MinIO serves as the object storage layer, holding both the Parquet data files and the associated Iceberg metadata (such as manifests and snapshots). Because it provides an S3-compatible API, it integrates seamlessly with the rest of the pipeline while offering scalable, cost-effective storage.

6. **Analytics Layer (Dremio)**: Finally, Dremio provides the analytics interface, querying Iceberg tables stored in MinIO directly. Users can run SQL queries on the logs, perform time-travel queries to inspect historical data, and join log data with other sources. This layer powers dashboards, reports, and visualizations for observability and operational insights.

#### Key Benefits of This Architecture

- **Real-time**: Logs queryable within ~60 seconds of generation
- **Scalable**: Handles high log volumes with Kafka buffering
- **Cost-effective**: Parquet compression + object storage
- **ACID compliant**: Iceberg ensures data consistency
- **Time travel**: Query logs from any point in time
- **Schema evolution**: Adapts to changing log formats
- **SQL-friendly**: Standard SQL for log analysis
- **Decoupled**: Each component can scale independently

## Prerequisites

### Required Software

1. **Kubernetes Cluster**
   - Docker Desktop with Kubernetes enabled, or
   - Minikube, Kind, or any other local Kubernetes cluster
   - Minimum resources: 8 CPU cores, 16GB RAM

2. **Command Line Tools**
   - `kubectl` - Kubernetes CLI
   - `helm` - Kubernetes package manager (v3+)
   - `openssl` - For generating TLS certificates
   - `git` - For cloning repositories
   - `k9s` (**Optional**, but I highly recommend it) - Kubernetes CLI with a terminal UI

3. **For Building Iceberg Connector** (Optional - pre-built connector is available)
   - Java 17 or 21 (JDK)
   - Maven
   - `unzip` and `zip` utilities

4. **Dremio Credentials**
   - Dremio license key
   - Dremio Quay.io pull secret (for container images)

### System Requirements

- **CPU**: 8+ cores recommended
- **Memory**: 16GB+ RAM
- **Disk**: 50GB+ free space
- **Network**: Internet access for pulling container images

## Setup Instructions

### Step 1: Fork This Repository

Fork this repository to your own GitHub account so you can make changes and have ArgoCD sync from your fork.

### Step 2: Configure Private Repository Access (If Applicable)

If your forked repository is **private**, you need to configure ArgoCD with GitHub credentials:

1. **Create a GitHub Personal Access Token (PAT)**:
   - Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
   - Generate a new token with `repo` scope (full control of private repositories)
   - Copy the token value

2. **Update `init-resources/argocd-git-repository.yaml`**:
   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: private-repo
     namespace: argocd
     labels:
       argocd.argoproj.io/secret-type: repository
   stringData:
     type: git
     url: https://github.com/<YOUR_USERNAME>/<YOUR_REPO_NAME>
     username: <YOUR_GITHUB_USERNAME>
     password: <YOUR_GITHUB_PAT>
   ```

### Step 3: Configure Kubernetes Context

Ensure your `kubectl` is configured to point to your Kubernetes cluster:

```bash
export KUBECONFIG=/path/to/your/.kube/config
kubectl config current-context
kubectl cluster-info
```

### Step 4: Configure Dremio Secrets


Edit `scripts/dremio-secrets.yaml` and replace the placeholder values:

1. **Docker Pull Secret**: Get your Dremio Quay.io credentials and set the `<YOUR_BASE64_ENCODED_DOCKER_CONFIG_JSON>` value.
2. **Dremio License**: Replace `<YOUR_DREMIO_LICENSE_KEY>` with your actual license key.

> [!NOTE]
> You can read more about **how to request a Dremio Enterprise Edition Free Trial** [here](https://docs.dremio.com/current/admin/licensing/free-trial/).

### Step 5: Build Iceberg Kafka Connector (Optional)

The Iceberg Kafka connector requires the [Dremio Auth Manager](https://github.com/dremio/iceberg-auth-manager) JAR in its `lib/` directory for OAuth2 authentication with Dremio Catalog.

A **pre-built connector is already configured** and will be automatically downloaded from my S3 bucket (public read access). You only need to build a custom connector if you want to customize it or if the pre-built version is unavailable.

To build a custom version, see:

> **[Build Iceberg Kafka Connector Documentation](docs/build-iceberg-kafka-connector.md)**

> [!TIP] 
> If you want to upload the pre-built connector to your own S3 bucket, you can download the zip file from [this release](https://github.com/carlos-ffs/confluent-dremio-flink-logs/releases/tag/iceberg-kafka-connect-with-authmgr-0.1.3) and upload it to your S3 bucket.

### Step 6: Deploy the Stack

Run the main deployment script:

```bash
# For public repositories
./scripts/run.sh

# For private repositories
./scripts/run.sh --private-repository
```

This script will:
1. Generate TLS certificates for Confluent Platform (optional, you can use the provided self-signed certs)
2. Create the `argocd` namespace
3. Install ArgoCD using Helm
4. Apply private repository credentials (if `--private-repository` flag is used)
5. Wait for Dremio namespace to be created
6. Apply Dremio secrets

### Step 7: Monitor Deployment

Watch the ArgoCD applications sync:

```bash
# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port-forward to ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access ArgoCD at https://localhost:8080
# Username: admin
# Password: (from command above)
```

Monitor pod status:

```bash
# Watch all namespaces
watch kubectl get pods -A

# Check specific namespaces
kubectl get pods -n confluent
kubectl get pods -n dremio
kubectl get pods -n fluent-bit
kubectl get pods -n monitoring
```

## Post-Deployment Configuration

### 1. Update Personal Access Token (PAT) in Kafka Connector

1. The Dremio resources job (`charts/dremio/templates/dremio-resources-creator.yaml`) creates a PAT and stores it in a Kubernetes secret. The token has a lifetime of 179 days.
2. To get the pat value run the following command:
   ```bash
   kubectl get secret dremio-root-pat -n dremio -o jsonpath='{.data.pat}' | base64 -d
   ```
3. Update the token in `charts/confluent-resources/templates/connectors.yaml`:
   ```yaml
   iceberg.catalog.rest.auth.oauth2.token-exchange.subject-token: "<YOUR_PAT_TOKEN>"
   ```
4. Commit and push changes (ArgoCD will auto-sync, or you can manually sync)
5. Verify the data Flow, by checking that logs are flowing through the pipeline:
    ```bash
    # Check Kafka topic has messages
    kubectl port-forward svc/controlcenter -n confluent 9021:9021
    # Access Control Center at http://localhost:9021
    # Login with default credentials (c3/c3-secret)
    # Check "Topics" and verify "fluent-bit" has messages

    # Check connector status
    kubectl get connector -n confluent
    kubectl describe connector fluent-bit-dremio-sink -n confluent

    # Check the connect server logs
    kubectl logs -n confluent connect-0
    ```

### 2. Create Dremio Source for MinIO

After checking that the connector is running and data is being written to Iceberg tables, you need to create a Dremio source to query the data. This source will point to the MinIO bucket where Iceberg stores its data. Based on the connector configuration, the data will be written to the `fluent_bit.logs` table in the `dremio` bucket, which translates to `s3://dremio/catalog/fluent_bit/logs`.

1. In Dremio UI, add a new S3 source:
   - **Name**: `fluent-bit-logs`
   - **AWS Access Key**: `dremio-minio-user`
   - **AWS Access Secret**: `dremio-minio-123`
   - Disable `Encrypt connection`
   - In **Advanced Options**:
     - **Root Path**: `/dremio/catalog/fluent_bit/logs`
     - **Connection Properties** (add the following properties):
       - `fs.s3a.endpoint`: `minio.dremio.svc.cluster.local:9000`
       - `fs.s3a.path.style.access`: `true`
       - `dremio.s3.compat`: `true`
2. Format the `data` folder:
   - Select the `fluent-bit-logs` source
   - On the `data` folder click on `Format Folder` (right side)
   - Choose `Parquet` as the format
   - Click `Save`

3. Now you can query the data using Dremio's SQL interface, something like:
   ```sql
      -- ALTER TABLE "fluent-bit-logs".data REFRESH METADATA; -- Uncomment this line if you need to refresh the metadata
      SELECT 
         data."time" as timestamp_,
         data.kubernetes.pod_name AS pod_name, 
         data.kubernetes.namespace_name AS namespace,
         log, data."stream" AS "stream", kubernetes
      FROM "fluent-bit-logs".data AS data
      -- WHERE data.log LIKE '%error%'
      ORDER BY timestamp_ DESC
   ```

> [!TIP]
> If you need to manually create or modify the source, see the API payload in `charts/dremio/templates/dremio-resources-creator.yaml` (lines 235-239).


### Common Issues

1. **Pods stuck in Pending**: Check resource availability
   ```bash
   kubectl describe pod <pod-name> -n <namespace>
   ```

2. **ImagePullBackOff for Dremio**: Verify pull secret is correct
   ```bash
   kubectl get secret dremio-pull-secret -n dremio -o yaml
   ```

3. **Connector fails to authenticate**: Verify Dremio PAT token is valid and has correct permissions

4. **No data in Iceberg tables**: Check Fluent Bit is sending to Kafka, and connector is running

## Useful Resources

- [Dremio Documentation](https://docs.dremio.com/)
- [Confluent Platform Documentation](https://docs.confluent.io/)
- [Apache Iceberg Sink Connector](https://iceberg.apache.org/docs/nightly/kafka-connect/#apache-iceberg-sink-connector)
- [Fluent Bit Documentation](https://docs.fluentbit.io/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
