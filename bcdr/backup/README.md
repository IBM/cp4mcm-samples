# Backing up IBM Cloud Pak® for Multicloud Management

Follow the steps to back up IBM Cloud Pak® for Multicloud Management.

## Before you begin
- You need to install the `kubectl`, `oc`, `velero`, `jq`, `git`, `docker` and `Helm` CLIs on a workstation machine, where you can access the OpenShift cluster, initiate and monitor the backup of IBM Cloud Pak® for Multicloud Management.
- Workstation machine must have Linux base operating system and access to the internet.
- If your environment has no access to Internet, you need to upload the `Ubuntu` image to all the worker nodes by following [Uploading the Ubuntu image in an air gap environment](../install/UploadUbuntuImageOnAirgap.md). The `Ubuntu` container is used to back up MongoDB that is running in the `ibm-common-services` namespace. 

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

  - For offline install, you can follow the steps mentioned [here](../install/InstallVeleroOnAirgap.md)
  - For online install, you can follow the steps mentioned [here](../install/VeleroInstallation.md)

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

     - `repository`: Name of the image for example `xy.abc.io/cp4mcm/cp4mcm-bcdr`. Here `xy.abc.io` is the image registry server URL, `cp4mcm` is the name of the repository and `cp4mcm-bcdr` is the name of the Docker image.
     - `pullPolicy`: Policy to determine when to pull the image from the image registry server. For example, To force pull the image, use the `Always` policy. 
     - `tag`: Tag of the Docker image for example `latest`.
     - `pullSecret`: Name of the image pull secret. Refer to the value from step 6.
     - `schedule`: Cron expression for automated backup. For example, To take backup once a day, use the `0 0 * * *` Cron expression.
     - `storageClassName`: Default storage class on the OpenShift cluster. For example `gp2`.  Use the `oc get sc` command to get the list of available Storage Classes on the OpenShift cluster.
     - `ttl`: Time to live for backup. Backup will be deleted automatically after TTL is reached.
     - `mongoDBDumpImage`: Name of the image for the MongoDB backup job. The MongoDB backup job is responsible for taking the backup of MongoDB that is running in the `ibm-common-services` namespace. Its value should be equal to the image that is used in `icp-mongodb` statefulset for `icp-mongodb` container. Use the command `oc get sts icp-mongodb -o jsonpath='{.spec.template.spec.containers[?(@.name == "icp-mongodb")].image}' -n ibm-common-services` to get the current name of the image. 
     - `airGap`: Indicates whether the install is online or offline. Set the value to `true` to install offline and `false` to install online.
     - `enabledNamespaces`: Lists the namespaces that are associated for installed components. For example, the `ibm-common-services` namespace represents the `IBM Common Services` component. You can delete the unused namespaces from the list to reduce the time taken for back up. You can update the list as shown if you have installed only two components, i.e. `IBM Common Services` and `Monitoring`
     
       ```
       enabledNamespaces:
       - '"management-infrastructure-management"'
       - '"management-monitoring"'
       ``` 

       The following table lists the components and namespaces:

       | Components    | Namespaces |
       | ------------- |-------------|
       | IBM Common Services      | ibm-common-services |
       | GRC      | kube-system      |
       | Monitoring | management-monitoring      |
       | VA\MA | management-security-services      |
       | Managed Services & Infrastructure Management | management-infrastructure-management | 

  3. Update the `backup-config.yaml`, which is located in `./helm/templates` If you want to take the backup of additional PVs. For example, To take backup of MySQL, add a new JSON entry in the `details` array of element `pod-annotation-details.json` as follows: 

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

### 8. Trigger an automated backup

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

      - `<BACKUP_NAME>` is the name of the Backup. You can see the backup name after the backup job is complete. For example, you might see the backup name `cp4mcm-backup-1622193915` in the backup job log as follows:
        
        ```
        Waiting for backup cp4mcm-backup-1622193915 to complete
        ```

### 10. Trigger an on-demand backup

  1. Deploy the on-demand backup job by running the following command: 
    
     ```
     kubectl create job --from=cronjob/backup-job on-demand-backup-job -n velero
      ```
     - This step is optional. Use only when you don't want to wait till the execution of the next scheduled backup job.
     - Deployment of an automated backup job is a prerequisite for the on-demand job. Only after you initiate an automated backup job, then you can trigger an on-demand backup. 

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

      - `<BACKUP_NAME>` is the name of the Backup. You can see the backup name after the on-demand backup job is complete. For example, you might see the backup name `cp4mcm-backup-1622193915` in the on-demand backup job log as follows:
        
        ```
        Waiting for backup cp4mcm-backup-1622193915 to complete
        ```

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

### 1. Velero installation in an online environment failed with the following error:

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
        - name: "docker.io/velero/*"
          policy:
      ```
   
   3. Apply the policy by running the following command:
   
      ```
      oc apply -f velero-policy.yaml
      ```

   4. Install Velero by running the following command:

      ```
      nohup sh install-velero.sh > install-velero.log &
      ```

   5. Check the logs by running the following command:

      ```
      tail -f install-velero.log
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
        - name: "<Image Registry Server URL>/<Repository>/cp4mcm-bcdr:latest"
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

### 3. Command `sh install-velero.sh` failed with the following error:

```
-bash: ./install-velero.sh: Permission denied
```

Complete the following steps to fix the problem:

   1. Give executable permission to the file `install-velero.sh` by running the following command:

      ```
      chmod 755 install-velero.sh
      ```

   2. Install Velero by running the following command:

      ```
      nohup ./install-velero.sh > install-velero.log &
      ```

   3. Check the logs by running the following command:

      ```
      tail -f install-velero.log
      ```   

### 4. Command `sh install-velero-on-airgap.sh` failed with the following error:

```
-bash: ./install-velero-on-airgap.sh: Permission denied
```

Complete the following steps to fix the problem:

   1. Give executable permission to the file `install-velero-on-airgap.sh` by running the following command:

      ```
      chmod 755 install-velero-on-airgap.sh
      ```

   2. Install Velero by running the following command:

      ```
      nohup ./install-velero-on-airgap.sh > install-velero-on-airgap.log &
      ```

   3. Check the logs by running the following command:

      ```
      tail -f install-velero-on-airgap.log
      ```   