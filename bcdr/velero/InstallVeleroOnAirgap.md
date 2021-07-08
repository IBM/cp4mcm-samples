# Installing Velero in an air gap environment

Follow the steps to install Velero in an air gap environment. Visit [here](https://velero.io/) to know more about the Velero.

## Before you begin
- You need to install the `docker` CLI on a workstation machine, where you can access the internet and the `oc`, `jq`, and `Helm` CLIs on a air gap environment, where you can access the OpenShift cluster. 
- Provision S3 bucket. It should be S3 compliant object store, such as AWS S3 bucket, IBM Cloud Object Store, minio.

## Procedure

### 1. Log in to the workstation machine, where `docker` CLI is installed.

### 2. Download the `cp4mcm-samples` zip file by running the following command:

```
wget https://github.com/IBM/cp4mcm-samples/archive/refs/heads/master.zip
```

Move the `master.zip` file to the `/tmp` directory in the air gap environment.

### 3. Download the Velero Helm Chart zip by running the following command:

```
wget https://github.com/vmware-tanzu/helm-charts/releases/download/velero-2.14.7/velero-2.14.7.tgz
```

Move the `velero-2.14.7.tgz` file to the `/tmp` directory in the air gap environment. 

### 4. Pull Velero images by running the following commands:

```
docker pull velero/velero:v1.5.3
```

```
docker pull velero/velero-plugin-for-aws:v1.0.0
```

```
docker pull velero/velero-restic-restore-helper:v1.5.3
```

### 5. Export Velero images by running the following commands:

```
docker save velero/velero:v1.5.3 -o velero.tar
```

```
docker save velero/velero-plugin-for-aws:v1.0.0 -o velero-plugin-for-aws.tar
```

```
docker save velero/velero-restic-restore-helper:v1.5.3 -o velero-restic-restore-helper.tar
```

Move all three `*.tar` files to the `/tmp` directory in  the air gap environment. 

### 6. Log in to the air gap environment.

### 7. Go to the `/tmp` directory by running the following command:

```
cd /tmp
```

### 8. Move the following files to the `/tmp` directory in all the worker nodes:
- velero.tar
- velero-plugin-for-aws.tar
- velero-restic-restore-helper.tar

### 9. Import Velero images in each worker node.

  Repeat steps 1,2 and 3 for all the worker nodes.

  1. Log in to worker node with a `root` user.

  2. Go to the `/tmp` directory by running the following command:

     ```
     cd /tmp
     ```
  3. Import Velero images by running the following commands:

     ```
     docker load -i velero.tar
     ```

     ```
     docker load -i velero-plugin-for-aws.tar
     ```   

     ```
     docker load -i velero-restic-restore-helper.tar
     ```

     If `podman` is installed instead of `docker`, then run following commands to import the Velero images:

     ```
     podman load -i velero.tar
     ```

     ```
     podman load -i velero-plugin-for-aws.tar
     ```

     ```
     podman load -i velero-restic-restore-helper.tar
     ```

### 10. Log in again to the air gap environment.

### 11. Go to `/tmp` directory by running the following command:

```
cd /tmp
```

### 12. Unzip the `master.zip` file.

### 13. Move the `velero-2.14.7.tgz` to the <Path to cp4mcm-samples-master>/bcdr/velero/scripts directory by running the following command:

```
cp velero-2.14.7.tgz <Path to cp4mcm-samples-master>/bcdr/velero/scripts/
```

You need to designate `<Path of cp4mcm-samples-master>` with the real path where you unzipped the `master.zip` file.

### 14. Go to the directory `<Path of cp4mcm-samples-master>/bcdr/velero/scripts` by running the following command:

```
cd <Path of cp4mcm-samples-master>/bcdr/velero/scripts
```

You need to designate `<Path of cp4mcm-samples-master>` with the real path where you unzipped the `master.zip` file.

### 15. Update the following parameters in `install-velero-on-airgap-config.json`:

- access_key_id: Access key id to connect to S3 bucket.
- secret_access_key: Secret access key to connect to S3 bucket.
- bucket_name: Name of the S3 bucket where backup data will be stored.
- bucket_url: URL to connect to S3 bucket.
- bucket_region: Region where S3 bucket is deployed.

### 16. Log in to the OpenShift cluster

```
oc login --token=<TOKEN> --server=<URL>
```

Where:
   
 - `<TOKEN>` is the token that you use to log in to the OpenShift cluster.
 - `<URL>` is the OpenShift server URL.

### 17. Install Velero by running the following command:

```
sh install-velero-on-airgap.sh
```

### 18. Check the velero pods status by running the following command:

```
oc get pods -n velero
```

`velero` and `restic` pods should be in a running state.

### 19. Check the status of `backupStorageLocation` by running the following command:

```
oc get backupStorageLocation -n velero
```

`backupStorageLocation` should be in the available phase.