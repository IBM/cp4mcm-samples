# Installing Velero in an online environment

Follow the steps to install Velero in an OpenShift cluster having internet connectivity. Visit [here](https://velero.io/) to know more about the Velero.

## Before you begin
- You need to install the `docker`, `oc`, `jq`, and `Helm` CLIs on a workstation machine, where you can access the internet.
- Provision S3 bucket. It should be S3 compliant object store, such as AWS S3 bucket, IBM Cloud Object Store, minio.

## Procedure

1. Go to the directory `<Path of cp4mcm-samples>/bcdr/install/scripts` by running the following command:

     ```
     cd <Path of cp4mcm-samples>/bcdr/install/scripts
     ```

     You need to designate `<Path of cp4mcm-samples>` with the real path where you put the `cp4mcm-samples` GitHub repository.

2. Update the following parameters in `install-velero-config.json`:

     - access_key_id: Access key id to connect to S3 bucket.
     - secret_access_key: Secret access key to connect to S3 bucket.
     - bucket_name: Name of the S3 bucket where backup data will be stored.
     - bucket_url: URL to connect to S3 bucket.
     - bucket_region: Region where S3 bucket is deployed.

3. Install Velero using the following command:

     ```
     sh install-velero.sh
     ```

4. Check the velero pods status by running the following command:

     ```
     oc get pods -n velero
     ```

     `velero` and `restic` pods should be in a running state.

5. Check the status of `backupStorageLocation` by running the following command:

     ```
     oc get backupStorageLocation -n velero
     ```

     `backupStorageLocation` should be in available phase.
