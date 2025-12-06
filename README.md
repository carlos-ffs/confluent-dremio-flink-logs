# Real-Time Log Analytics with Confluent, Dremio & Apache Iceberg

#### MISSING ADDING DREMIO DEFAULT USER TO THE CATALOG RULES

This workshop demonstrates a real-time log analytics pipeline that streams Kubernetes logs into a queryable data lakehouse. The architecture combines Confluent Platform for streaming, Apache Iceberg for table format, and Dremio for SQL analytics - all deployed on Kubernetes using GitOps principles with ArgoCD.

**What You'll Build**: A complete pipeline that captures every log from your Kubernetes cluster, streams it through Kafka, transforms it into Iceberg tables, and makes it instantly queryable through Dremio's SQL interface - enabling real-time log analytics, troubleshooting, and observability at scale.

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
            catalog["Dremio Catalog Services<br/>📋 REST Catalog API<br/>🔐 OAuth2 authentication<br/>📊 Table: fluent_bit.logs"]
            coordinator["Dremio Coordinator + Executors<br/>🔍 SQL Query Engine<br/>⏮️ Time travel queries<br/>📈 Real-time analytics"]
        end

        subgraph storage["Object Storage"]
            minio["MinIO (S3-compatible)<br/>🗄️ Bucket: dremio<br/>📦 Parquet data files<br/>📝 Iceberg metadata"]
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

1. **Log Collection (Fluent Bit)**
   - Deployed as a DaemonSet on every Kubernetes node
   - Automatically discovers and tails logs from all pods
   - Enriches logs with Kubernetes metadata (namespace, pod name, labels, etc.)
   - Formats logs as JSON for structured processing

2. **Stream Buffering (Kafka)**
   - Receives logs on the `fluent-bit` topic
   - Provides durability and replay capability (1-hour retention)
   - Enables decoupling between log collection and processing
   - Handles backpressure and ensures no log loss

3. **Lakehouse Integration (Iceberg Sink Connector)**
   - Consumes logs from Kafka in micro-batches
   - Automatically creates the `fluent_bit.logs` Iceberg table
   - Converts JSON logs to Parquet format for efficient storage
   - Commits data every 60 seconds for near-real-time availability
   - Handles schema evolution as log formats change

4. **Catalog Management (Dremio Catalog Services)**
   - Provides REST Catalog API for Iceberg operations
   - Manages table metadata, snapshots, and schema versions
   - Authenticates connector via OAuth2 with Personal Access Token
   - Coordinates concurrent writes and maintains ACID guarantees

5. **Object Storage (MinIO)**
   - Stores Iceberg data files in Parquet format
   - Stores Iceberg metadata files (manifests, snapshots)
   - Provides S3-compatible API for seamless integration
   - Enables cost-effective, scalable storage

6. **Analytics Layer (Dremio)**
   - Queries Iceberg tables directly from MinIO
   - Provides SQL interface for log analysis
   - Supports time travel to query historical snapshots
   - Enables joins with other data sources
   - Powers dashboards and visualizations

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

### Step 5: Build Iceberg Kafka Connector (Optional)

We need to build a custom version of the Iceberg Kafka connector that includes the [Dremio Auth Manager](https://github.com/dremio/iceberg-auth-manager) for OAuth2 authentication with Dremio Catalog. The connector must contain the Dremio Auth Manager JAR in its `lib/` directory.

**Note**: A pre-built connector is already configured and will be automatically downloaded by Kafka Connect. However, in the future, the pre-build connector might be deleted from the S3 bucket. You need to build the connector yourself if you want to:
- Use a different version of Apache Iceberg
- Customize the connector
- Use a different version of Dremio Auth Manager

#### Prerequisites for Building

- **Java**: JDK 17, or 21 (the script defaults to JDK 21)
- **Maven**: For downloading dependencies
- **Build tools**: `git`, `unzip`, `zip`

#### Building the Connector

Run the build script:

```bash
./scripts/build-iceberg-kafka-connector.sh
```

The script performs the following steps:

1. **Clones Apache Iceberg**
   - Creates a working directory: `./iceberg-kafka-connector-build/`
   - Clones from: `https://github.com/apache/iceberg.git`
   - Optional: Uncomment line 35 to checkout a specific release tag

2. **Builds Iceberg Kafka Connect Runtime**
   - Uses Gradle to build only the Kafka Connect module
   - Skips tests for faster build (typically 5-10 minutes)
   - Output: `iceberg-kafka-connect-runtime-*.zip`

3. **Downloads Dremio Auth Manager**
   - Version: `0.1.3` (configurable via `AUTHMGR_VERSION` variable)
   - Downloads from Maven Central: `com.dremio.iceberg.authmgr:authmgr-oauth2-runtime`
   - Stored in: `~/.m2/repository/`

4. **Bundles Components**
   - Extracts the Iceberg connector ZIP
   - Adds the Auth Manager JAR to the `lib/` directory
   - Re-packages into: `iceberg-kafka-connect-with-authmgr-0.1.3.zip`

5. **Outputs Build Information**
   - Final ZIP location: `./iceberg-kafka-connector-build/iceberg-kafka-connect-with-authmgr-0.1.3.zip`
   - SHA-512 checksum for verification
   - Confirms Auth Manager JAR is included

#### Using Your Custom Build

After building, you need to make the connector available to Kafka Connect:

1. **Upload the ZIP file** to a location accessible from your Kubernetes cluster:
   ```bash
   # Example: Upload to S3
   aws s3 cp ./iceberg-kafka-connector-build/iceberg-kafka-connect-with-authmgr-0.1.3.zip \
     s3://your-bucket/connectors/

   # Get the public URL
   aws s3 presign s3://your-bucket/connectors/iceberg-kafka-connect-with-authmgr-0.1.3.zip
   ```
   
   [!IMPORTANT]
   Your uploaded ZIP file URL must end with `.zip` for Confluent Kafka Connect to recognize it as a plugin archive.

2. **Update the connector configuration** in `charts/confluent-resources/templates/confluent-platform-quick.yaml`:
   ```yaml
   # Around line 170-173
   build:
     type: onDemand
     onDemand:
       plugins:
         url:
           - archivePath: https://your-url/iceberg-kafka-connect-with-authmgr-0.1.3.zip
             checksum: <your-sha512-checksum>
             name: iceberg-kafka-connect-with-authmgr-0.1.3
   ```

3. **Commit and push** the changes - ArgoCD will automatically sync and redeploy Kafka Connect with your custom connector.

#### Troubleshooting Build Issues

**Java version errors**:
```bash
# Check Java version
java -version

# On macOS, list available Java versions
/usr/libexec/java_home -V

# Set JAVA_HOME manually before running script
export JAVA_HOME=$(/usr/libexec/java_home -v 21)
```

**Gradle build failures**:
- Ensure you have sufficient memory (4GB+ recommended)
- Check internet connection for downloading dependencies
- Try cleaning the build: `cd iceberg-kafka-connector-build/iceberg && ./gradlew clean`

**Maven download failures**:
- Verify Maven is installed: `mvn --version`
- Check Maven Central is accessible
- Clear Maven cache: `rm -rf ~/.m2/repository/com/dremio/iceberg/authmgr/`

**Note**: The connector is already pre-built and hosted at the URL specified in `charts/confluent-resources/templates/confluent-platform-quick.yaml`. You only need to build it if you want to use a different version or customize it.

If you build your own connector:
1. Upload the ZIP file to an accessible URL (S3, HTTP server, etc.)
2. Update the connector URL and checksum in `charts/confluent-resources/templates/confluent-platform-quick.yaml` (lines 171-172)

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
2. Format the data folder:
   - Select the `fluent-bit-logs` source
   - On the `data` folder click on `Format Folder` (right side)
   - Choose `Parquet` as the format
   - Click `Save`

3. Now you can query the data using Dremio's SQL interface, something like:
   ```sql
    SELECT 
        CAST(CONCAT(SUBSTR(REGEXP_REPLACE(REGEXP_REPLACE(data."time",'Z$',''),'T',' '),1, 19),'.',
            LPAD(SUBSTR(COALESCE(REGEXP_EXTRACT(REGEXP_REPLACE(REGEXP_REPLACE(data."time",'Z$',''),'T',' '), '\\.(\\d+)', 1), '000'),1, 3),3, '0')) AS TIMESTAMP) 
            AS timestamp_,
        data.kubernetes.pod_name AS pod_name, 
        data.kubernetes.namespace_name AS namespace,
        log, data."stream" AS "stream", kubernetes
    FROM "fluent-bit-logs".data AS data
    WHERE data.log LIKE '%error%'
    ORDER BY timestamp_ DESC
   ```



## Component Details

### Confluent for Kubernetes (CFK)

CFK is a cloud-native management control plane for deploying and managing Confluent in your Kubernetes private cloud environment. It provides a standard and simple interface to customize, deploy, and manage Confluent Platform through declarative API.

**Namespace**: `confluent`

**Components**:
  - **KRaft Controllers**: 3 replicas for metadata management
  - **Kafka Brokers**: 3 replicas with internal and external listeners
  - **Schema Registry**: 1 replica
  - **Kafka Connect**: 3 replicas with Iceberg connector pre-installed
  - **ksqlDB**: 1 replica for stream processing
  - **Control Center**: 1 replica for management UI
  - **Kafka REST Proxy**: 1 replica

**Access**:
```bash
# Control Center UI
kubectl port-forward svc/controlcenter -n confluent 9021:9021
# Access at http://localhost:9021
# Login with default credentials:
#   - Username: c3
#   - Password: c3-secret

# External Kafka access (NodePort)
# Brokers available at localhost:30000, localhost:30001, localhost:30002
```

**Authentication**:
- RBAC enabled with MDS (Metadata Service)
- TLS enabled on all listeners
- Credentials stored in secrets (check `charts/confluent-resources/templates/users-secret.yaml`)

### Dremio

Dremio is a high-performance data lakehouse platform that enables self-service analytics and AI directly on data lakes (like S3, ADLS) and other sources, allowing users to run SQL queries with data warehouse speeds, without complex data movement. Built on open standards (Arrow, Iceberg, Polaris), it offers a unified semantic layer, data virtualization, and autonomous query optimization (via "Reflections") for lightning-fast BI and AI agent access, making data engineering simpler and eliminating vendor lock-in. 

**Namespace**: `dremio`

**Components**:
- **Coordinator**: 1 replica (2 CPU, 4Gi memory)
- **Executor**: Elastic engines (configurable)
- **Catalog Services**: 1 replica for Iceberg catalog
- **MongoDB**: 1 replica for metadata storage
- **Zookeeper**: 1 replica for coordination
- **NATS**: 3 replicas for messaging
- **MinIO**: Standalone mode for S3-compatible storage

**Access**:
```bash
# Dremio UI
kubectl port-forward svc/dremio-client -n dremio 9047:9047
# Access at http://localhost:9047
# Default credentials (since we set debug.addDefaultUser=true)
# Username: dremio
# Password: dremio123
```

**Storage**:
- **Distributed Storage**: MinIO bucket `dremio` at `s3://dremio/`
- **Catalog Storage**: MinIO bucket `dremio` at `s3://dremio/catalog`

### Fluent Bit

**Namespace**: `fluent-bit`

Fluent Bit collects logs from all Kubernetes pods and forwards them to Kafka topic `fluent-bit`.

**Configuration**:
- Output: Kafka broker at `kafka.confluent.svc.cluster.local:9071`
- Topic: `fluent-bit`
- Authentication: SASL_SSL with username `fluent-bit-user`

### Iceberg Sink Connector

The connector reads from the `fluent-bit` Kafka topic and writes to Iceberg tables in Dremio.

**Configuration**:
- **Connector Class**: `org.apache.iceberg.connect.IcebergSinkConnector`
- **Source Topic**: `fluent-bit`
- **Target Table**: `fluent_bit.logs`
- **Catalog Type**: REST (Dremio Catalog API)
- **Catalog URI**: `http://dremio-client.dremio.svc.cluster.local:8181/api/catalog`
- **Authentication**: OAuth2 with Dremio Personal Access Token


## Troubleshooting

### Dremio Issues

```bash
# Check coordinator logs
kubectl logs -n dremio dremio-master-0

# Check catalog services
kubectl logs -n dremio -l app=dremio-catalog-services

# Check MinIO
kubectl logs -n dremio -l app=minio
```

### Connector Issues

```bash
# Check connector status
kubectl get connector -n confluent fluent-bit-dremio-sink -o yaml

# View connector logs (in Connect pod)
kubectl logs -n confluent connect-0 | grep iceberg

# Restart connector
kubectl delete connector fluent-bit-dremio-sink -n confluent
# ArgoCD will recreate it
```

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
