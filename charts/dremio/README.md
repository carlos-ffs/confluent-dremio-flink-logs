# Dremio + MinIO Helm Chart

- [Dremio + MinIO Helm Chart](#dremio--minio-helm-chart)
  - [Overview](#overview)
  - [Prerequisites](#prerequisites)
    - [Resource Requirements](#resource-requirements)
      - [Total minimum resource requests:](#total-minimum-resource-requests)
      - [Storage requirements:](#storage-requirements)
  - [Installing the Chart](#installing-the-chart)
    - [Before you begin](#before-you-begin)
    - [Easy Installation Script](#easy-installation-script)
    - [Step by step](#step-by-step)
      - [1. Add the required Helm repositories](#1-add-the-required-helm-repositories)
      - [2. Build chart dependencies](#2-build-chart-dependencies)
      - [3. Create the namespace](#3-create-the-namespace)
      - [4. Install the chart](#4-install-the-chart)
  - [Dremio Configuration](#dremio-configuration)
    - [Distributed Storage Configuration](#distributed-storage-configuration)
  - [Accessing Dremio](#accessing-dremio)
  - [Upgrading](#upgrading)
  - [Uninstalling the Chart](#uninstalling-the-chart)
  - [Troubleshooting](#troubleshooting)
    - [Checking Pod Status](#checking-pod-status)
    - [Viewing Logs](#viewing-logs)
  - [Additional Resources](#additional-resources)


This Helm chart deploys Dremio and MinIO on Kubernetes, providing a complete data analytics platform with distributed storage capabilities.

> [!CAUTION]  
> This chart is NOT intended for production use. But as solution to quickly deploy Dremio for testing and evaluation purposes. 
> Performance is highly degraded with this setup.

## Overview

[Dremio](https://www.dremio.com/) is a data lakehouse platform that provides fast, self-service SQL analytics directly on data lake storage. This Helm chart deploys Dremio along with MinIO, an S3-compatible object storage, to provide a complete solution for data analytics.

## Prerequisites

- Kubernetes 1.21+
- Helm 3.7+
- Sufficient resources to run the Dremio and MinIO components
- Dremio License Key
- Dremio Quay.io Pull Secret

### Resource Requirements


#### Total minimum resource requests:
- CPU: 7.5
- Memory: 13Gi
- Storage: 28Gi


## Installing the Chart

### Before you begin

1. Clone this repository or download the chart files.
2. Set the `.dockerconfigjson` value in `templates/pull-secret.yaml` to your Dremio Quay.io Pull Secret (the value is base64 encoded).
3. Change the `dremio-helm.dremio.license` value in `values.yaml` to your Dremio License Key.

### Easy Installation Script

If you have `kubectl` and `helm` installed, you can use the `install.sh` script to install Dremio and MinIO with default settings:

```bash
./install.sh
```


### Step by step

#### 1. Add the required Helm repositories
```bash
helm repo add minio https://charts.min.io/
```

#### 2. Build chart dependencies

```bash
helm dependency build .
```

#### 3. Create the namespace

```bash
kubectl create namespace dremio --dry-run=client -o yaml | kubectl apply -f -
```

#### 4. Install the chart

```bash
helm upgrade --install --atomic --timeout 15m dremio . -n dremio
```



## Dremio Configuration

For a complete list of configuration options, please refer to the `values.yaml` file.


### Distributed Storage Configuration

The chart configures Dremio to use MinIO as distributed storage by default. The configuration is set in the `distStorage` section:

**Important Note:** The `fs.s3a.endpoint` value in the distributed storage configuration must match your MinIO service endpoint. If you modify `minio.fullnameOverride` or deploy to a different namespace, update the endpoint accordingly (format: `<minio-service-name>.<namespace>.svc.cluster.local:9000`).

```yaml
distStorage:
  type: "aws"
  aws:
    bucketName: "dremio"
    ...
    extraProperties: |
      <property>
        <n>fs.s3a.endpoint</n>
        <value>minio.dremio.svc.cluster.local:9000</value>
      </property>
      ...
      <property>
        <n>fs.s3a.connection.ssl.enabled</n>
        <value>false</value>
      </property>
```

## Accessing Dremio

After the deployment is complete, you can access the Dremio UI in your browser: `http://localhost:9047`


## Upgrading

To upgrade the chart to a newer version:

```bash
helm dependency update .
helm upgrade dremio . -n dremio
```

## Uninstalling the Chart

To uninstall/delete the `dremio` deployment:

```bash
helm uninstall dremio -n dremio
```

This will remove all the Kubernetes components associated with the chart and delete the release.

## Troubleshooting

### Checking Pod Status

```bash
kubectl get pods -n dremio
```

### Viewing Logs

```bash
kubectl logs -f <pod-name> -n dremio
```

## Additional Resources

- [Dremio Documentation](https://docs.dremio.com/)
- [MinIO Documentation](https://docs.min.io/)
