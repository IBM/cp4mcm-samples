# IBM Cloud Pak for Multicloud Management Backup

## Clone GitHub Repository

```
git clone https://github.com/IBM/cp4mcm-samples.git
```

## Build Docker Image

Go to `<Path of cp4mcm-samples>/bcdr/backup`.

```
docker build -t cp4mcm-bcdr:latest .
```

## Push Docker Image to Image Registry

```
docker tag cp4mcm-bcdr:latest <Image Registry Server URL>/<Repository>/cp4mcm-bcdr:latest
```

```
docker login <Image Registry Server URL> -u <USERNAME>
```

```
docker push <Image Registry Server URL>/<Repository>/cp4mcm-bcdr:latest
```

## Package Helm Chart


1. Go to `<Path of cp4mcm-samples>/bcdr/backup`.

2. Update `values.yaml` located `./helm` with all the required information.

```
helm package ./helm
```

## Login to OpenShift Cluster

```
oc login --token=<TOKEN> --server=<URL>
```

## Create Image Pull Secret

```
oc create secret docker-registry backup-secret -n velero --docker-server=<Image Registry Server URL> --docker-username=<USERNAME> --docker-password=<PASSWORD> --docker-email=<EMAIL>
```

## Deploy Backup Job


Go to `<Path to cp4mcm-samples>/backup`.

```
helm install backup-job clusterbackup-0.1.0.tgz
```

## Monitor Backup Job

```
oc get pods -n velero
```

```
oc logs -f <backup-job-***>
```

Wait until the execution is complete. After completion, check the status of backup by using the following command:

```
velero get backup
```