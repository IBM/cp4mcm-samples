# Backing up IBM Cloud Pak® for Multicloud Management

Follow the steps to back up IBM Cloud Pak® for Multicloud Management.

## Before you begin
You need to install the `kubectl`, `oc`, `velero`, and `Helm` CLI on the workstation machine. From the workstation machine, you have to initialize and monitor the backup of IBM Cloud Pak® for Multicloud Management.

## Procedure

### 1. Clone the GitHub repository

```
git clone https://github.com/IBM/cp4mcm-samples.git
```

### 2. Log in to the OpenShift cluster

```
oc login --token=<TOKEN> --server=<URL>
```

Where:
   
 - `<TOKEN>` is the token that you use to log in to the OpenShift cluster.
 - `<URL>` is the OpenShift server URL.

### 3. Install Velero

  1. Deploy S3 bucket in the cloud where IBM Cloud Pak® for Multicloud Management is running. It should be S3 compliant object store such as AWS S3 bucket, IBM Cloud Object Store, minio.

  2. Go to the directory `<Path of cp4mcm-samples>/bcdr/backup/scripts` by running the following command:

     ```
     cd <Path of cp4mcm-samples>/bcdr/backup/scripts
     ```

     You need to designate `<Path of cp4mcm-samples>` with the real path where you put the `cp4mcm-samples` GitHub repository.

   3. Update the following parameters in `install-velero-config.json`:

      - access_key_id: Access key id to connect to S3 bucket.
      - secret_access_key: Secret access key to connect to S3 bucket.
      - bucket_name: Name of the S3 bucket where backup data will be stored.
      - bucket_url: URL to connect to S3 bucket.
      - bucket_region: Region where S3 bucket is deployed.

   4. Install Velero using the following command:

      ```
      sh install-velero.sh
      ```

   5. Check the velero pods status by running the following command:

      ```
      oc get pods -n velero
      ```

      `velero` and `restic` pods should be in a running state.

   6. Check the status of `backupStorageLocation` by running the following command:

      ```
      oc get backupStorageLocation -n velero
      ```

      `backupStorageLocation` should be in available phase.

### 4. Build the Docker image

  1. Go to the directory `<Path of cp4mcm-samples>/bcdr/backup` by running the following command:

     ```
     cd <Path of cp4mcm-samples>/bcdr/backup
     ```

  2. Build the `cp4mcm-bcdr` docker image by running following command:

      ```
      docker build -t cp4mcm-bcdr:latest .
      ```

### 5. Tag and push the Docker image to the image registry

```
docker tag cp4mcm-bcdr:latest <Image Registry Server URL>/<Repository>/cp4mcm-bcdr:latest
```

```
docker login <Image Registry Server URL> -u <USERNAME>
```

```
docker push <Image Registry Server URL>/<Repository>/cp4mcm-bcdr:latest
```

Where:

   - `<Image Registry Server URL>` is the image registry server URL.
   - `<Repository>` is the repository where you put the image.
   - `<USERNAME>` is the username to log in to the image registry server.

### 6. Create an image pull secret by running the following command:

   ```
   oc create secret docker-registry backup-secret -n velero --docker-server=<Image Registry Server URL> --docker-username=<USERNAME> --docker-password=<PASSWORD> --docker-email=<EMAIL>
   ```

   Where:

   - `<Image Registry Server URL>` is the image registry server URL.
   - `<USERNAME>` is the username to log in to the image registry server.
   - `<PASSWORD>` is the password to log in to the image registry server.
   - `<EMAIL>` is the email for image registry server. 

### 7. Package the Helm Chart

  1. Go to the directory `<Path of cp4mcm-samples>/bcdr/backup` by running the following command:

     ```
     cd <Path of cp4mcm-samples>/bcdr/backup
     ```

  2. Update the following parameters in `values.yaml`, `values.yaml` is located in `./helm`:

     - repository: Name of the image for example `xy.abc.io/cp4mcm/cp4mcm-bcdr`. Here `xy.abc.io` is the image registry server URL, `cp4mcm` is the name of the repository and `cp4mcm-bcdr` is the name of the Docker image.
     - pullPolicy: Policy to determine when to pull the image from the image registry server. For example, To force pull the image use the `Always` policy. 
     - tag: Tag of the Docker image for example `latest`.
     - pullSecret: Name of the image pull secret. Refer to the value from step 5.
     - schedule: Cron expression for automated backup. For example, To take backup once a day use the `0 0 * * *` Cron expression.
     - storageClassName: Default storage class on the OpenShift cluster. For example `gp2`.  Use the `oc get sc` command to get the list of available Storage Classes on the OpenShift cluster.

  3. Update the `backup-config.yaml`, which is located in `./helm/templates` If you want to take the backup of additional PVs. For example, To take backup of MySQL add a new JSON entry in the `details` array of element `pod-annotation-details.json` as follows: 

     ```
     {
        "namespace": "demo",
        "pod": "mysql-0",
        "volume": "mysql-volume"
     }
     ```

     Here `mysql-0` pod is running in the `demo` namespace and referring PVC through volume `mysql-volume`.

   4. Package the Helm Chart.

      ```
      helm package ./helm
      ```

### 8. Trigger automated backup

  1. Go to the directory `<Path of cp4mcm-samples>/bcdr/backup` by running the following command:

     ```
     cd <Path of cp4mcm-samples>/bcdr/backup
     ```

  2. Deploy the backup job by running the following command:

     ```
     helm install backup-job clusterbackup-0.1.0.tgz
     ```

### 9. Monitor the backup Job

  1. Check the backup pods status by running the following command:

     ```
     oc get pods -n velero
     ```

  2. Check the backup job logs by running the following command:

     ```
     oc logs -f <backup-job-***>
     ```

   3. Check the backup status by running the following command:
 
      ```
      velero get backup <BACKUP_NAME>
      ```

      Where:

      - `<BACKUP_NAME>` is the name of the Backup.

### 10. Trigger on-demand backup

  1. Deploy the on-demand backup job by running the following command: 
    
     ```
     kubectl create job --from=cronjob/backup-job on-demand-backup-job -n velero
      ```
     - This step is optional. Use only when you don't want to wait till the execution of the next scheduled backup job.
     - Deployment of an automated backup job is a prerequisite for the on-demand job. 

  2. Check the on-demand backup pods status by running the following command:

     ```
     oc get pods -n velero
     ```

  3. Check the on-demand backup job logs by running the following command:

     ```
     oc logs -f <on-demand-backup-job-***>
     ```

  4. Check the backup status by running the following command:

     ```
     velero get backup <BACKUP_NAME>
     ```

     Where:

      - `<BACKUP_NAME>` is the name of the Backup.

## Notes

- All the Kubernetes resources from all the namespaces except the following namespaces will be backed up:

   - openshift
   - openshift-apiserver
   - openshift-apiserver-operator
   - openshift-authentication
   - openshift-authentication-operator
   - openshift-cloud-credential-operator
   - openshift-cluster-machine-approver 
   - openshift-cluster-node-tuning-operator
   - openshift-cluster-samples-operator
   - openshift-cluster-storage-operator
   - openshift-cluster-version  
   - openshift-config 
   - openshift-config-managed
   - openshift-console
   - openshift-console-operator
   - openshift-controller-manager 
   - openshift-controller-manager-operator
   - openshift-dns
   - openshift-dns-operator
   - openshift-etcd
   - openshift-image-registry
   - openshift-infra
   - openshift-ingress 
   - openshift-ingress-operator
   - openshift-insights
   - openshift-kni-infra
   - openshift-kube-apiserver
   - openshift-kube-apiserver-operator
   - openshift-kube-controller-manager
   - openshift-kube-controller-manager-operator
   - openshift-kube-proxy
   - openshift-kube-scheduler 
   - openshift-kube-scheduler-operator
   - openshift-machine-api
   - openshift-machine-config-operator
   - openshift-marketplace
   - openshift-monitoring
   - openshift-multus
   - openshift-network-operator
   - openshift-node
   - openshift-openstack-infra
   - openshift-operator-lifecycle-manager
   - openshift-operators
   - openshift-ovirt-infra
   - openshift-service-ca
   - openshift-service-ca-operator
   - openshift-service-catalog-apiserver-operator
   - openshift-service-catalog-controller-manager-operator 
   - openshift-user-workload-monitoring
   - velero

- The following list of databases for each different application will be backed up:

   - Vulnerability Advisor
      - Zookeeper
      - Kafka
      - Elasticsearch

   - Monitoring
      - Zookeeper
      - Kafka
      - CouchDB
      - Cassandra

   - Infrastructure Management
      - PostgreSQL

   - Manage Services
      - MongoDB

   - SRE
      - Redis Graph
      - PostgreSQL

   - IBM Common Services
      - MongoDB
      - Prometheus 

## Troubleshooting

### 1. Command `sh install-velero.sh` failed with the following error:

```
Error: admission webhook "trust.hooks.securityenforcement.admission.cloud.ibm.com" denied the request:
Deny "docker.io/velero/velero:v1.5.3", no matching repositories in ClusterImagePolicy and no ImagePolicies in the "velero" namespace
```

As a fix perform the following steps:

   1. Uninstall `Velero` by running the following command:

      ```
      helm uninstall velero -n velero
      ```

   2. Create a file `velero-policy.yaml` and add the following content to it:
   
      ```
      apiVersion: securityenforcement.admission.cloud.ibm.com/v1beta1
      kind: ClusterImagePolicy
      metadata:
        name: velero-cluster-image-policy
      spec:
       repositories:
        - name: "http://docker.io/velero/*"
          policy:
      ```
   
   3. Apply the policy by running the following command:
   
      ```
      oc apply -f velero-policy.yaml
      ```

   4. Install Velero by running the following command:

      ```
      sh install-velero.sh
      ```

### 2. Command `helm install backup-job clusterbackup-0.1.0.tgz` failed with the following error:

```
Error: admission webhook "trust.hooks.securityenforcement.admission.cloud.ibm.com" denied the request:
Deny "<Image Registry Server URL>/<Repository>/cp4mcm-bcdr:latest", no matching repositories in ClusterImagePolicy and no ImagePolicies in the "velero" namespace
```

Where:

   - `<Image Registry Server URL>` is the image registry server URL.
   - `<Repository>` is the repository where you put the image.

As a fix perform the following steps:
   
   1. Uninstall `backup-job` by running the following command:

      ```
      helm uninstall backup-job -n velero
      ```

   2. Create a file `backup-image-policy.yaml` and add the following content to it:
   
      ```
      apiVersion: securityenforcement.admission.cloud.ibm.com/v1beta1
      kind: ClusterImagePolicy
      metadata:
        name: backup-image-policy
      spec:
       repositories:
        - name: "http://<Image Registry Server URL>/<Repository>/cp4mcm-bcdr:latest"
          policy:
      ```
   
   3. Apply the policy by running the following command:
   
      ```
      oc apply -f backup-image-policy.yaml
      ```

   4. Deploy the backup job by running the following command:

      ```
      helm install backup-job clusterbackup-0.1.0.tgz
      ```