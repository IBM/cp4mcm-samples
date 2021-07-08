# IBM Cloud Pak for Multicloud Management Restore

## Prerequisites

- Install the `watch`, `kubectl`, `oc`, `python`, `velero`, `Helm`, `jq`, `git` and `cloudctl` CLIs on the workstation machine, where you can access the OpenShift cluster, initiate and monitor the restoration of IBM Cloud Pak® for Multicloud Management.

**Notes**

- The restored cluster needs to be in the same region as the backed-up cluster.
- It is recommended to have the same OpenShift version in both the backed-up and restored cluster.
- If Monitoring needs to be restored, you need to keep the backed-up and restored cluster domain name same. Otherwise, Monitoring agents might not be able to connect to IBM Cloud Pak for Multicloud Management after restoration.
- The following steps in the Procedure section are to restore IBM Cloud Pak for Multicloud Management in a new cluster.
- The backup also backs up keys and certificates from the previous clusters. Ensure that the restored data is accessible in the new deployment. This restoration procedure works with the backup procedure in Backing up IBM Cloud Pak for Multicloud Management. Without backup, you can't run the restoration independently.
- It is important to restore the backed-up data first for different components like Common Services, Monitoring, GRC, Vulnerability Advisor (VA), Mutation Advisor (MA), and Managed Services, and then deploy Common Services and IBM Cloud Pak for Multicloud Management operators. Otherwise, the restoration might not work.


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

  - For offline install, you can follow the steps mentioned [here](../velero/InstallVeleroOnAirgap.md)
  - For online install, you can follow the steps mentioned [here](../velero/VeleroInstallation.md)

### 4. Restore Common Services, Monitoring, GRC, Vulnerability Advisor (VA), Mutation Advisor (MA), and Managed Services
      
1. Change the following values in the file `restore-data.json` based on real values. The file `restore-data.json` is available in the directory `<Path of cp4mcm-samples>/bcdr/restore/scripts`, where `<Path of cp4mcm-samples>` is the real path where you put the `cp4mcm-samples` GitHub repository.

   ```
   "accessKeyId":"<bucket access key id>",
   "secretAccessKey":"<bucket secret access key>",
   "bucketName":"<bucket name>",
   "bucketUrl":"<bucket url>",
   "bucketRegion":"<bucket region>",
       
   "backupName":"<backup name>",
        
   "ingressSubdomain":"<ingress subdomain of cluster>",
        
   "grcCrNamespace":"<namespace name where all the grc policies are created>",
        
   "imRestoreLabelKey":"<label key which is added for Infrastructure Management backup and restore>",
   "imRestoreLabelValue":"<label value which is added for Infrastructure Management backup and restore>",

   "monitoringRestoreLabelKey":"<label key which is added for Monitoring backup and restore>",
   "monitoringRestoreLabelValue":"<label value which is added for Monitoring backup and restore>" 
   ```

   For Example:

    ```
    "backupName":"cp4mcm-backup-373383393",

    "ingressSubdomain":"apps.cp4mcm-restore.multicloud-apps.io",

    "grcCrNamespace":"default",

    "imRestoreLabelKey":"imbackup",
    "imRestoreLabelValue":"test",

    "monitoringRestoreLabelKey":"appbackup",
    "monitoringRestoreLabelValue":"monitoring"
    ```

 2. Restore Common Services, Monitoring, GRC, VA/MA, and Managed Services.

    1. Go to the directory `<Path of cp4mcm-samples>/bcdr/restore/scripts` by running the following command, where `<Path of cp4mcm-samples>` is the real path where you put the `cp4mcm-samples` GitHub repository.

       ```
       cd <Path of cp4mcm-samples>/bcdr/restore/scripts
       ```

    2. Start the restoration process by running either of the following commands:

       ```
       bash restore.sh -a 
       ```
       or 

       ```
       bash restore.sh --all-restore
       ```

       After you run the command, it installs Velero first in the restored cluster, and then performs all the other restoration operations.

### 5. Install Common Services and IBM Cloud Pak for Multicloud Management

  1. Install RHCAM and enable the `observability` feature.
  2. Install IBM Cloud Pak for Multicloud Management operator and create its CR by enabling different components. For example, enable Infrastructure Management, Managed Services, Service Library, GRC, Vulnerability Advisor (VA), Mutation Advisor (MA), and don't enable Monitoring. For Managed Services, specify the existing claim name details as follows:

      ```
        - enabled: true
          name: ibm-management-cam-install
          spec:
            manageservice:
              camLogsPV:
               name: cam-logs-pv
               persistence:
                 accessMode: ReadWriteMany
                 enabled: true
                 existingClaimName: "cam-logs-pv"
                 existingDynamicVolume: false
                 size: 10Gi
                 storageClassName: "<your stotage class name>"
                 useDynamicProvisioning: true
              camMongoPV:
                name: cam-mongo-pv
                persistence:
                  accessMode: ReadWriteMany
                  enabled: true
                  existingClaimName: "cam-mongo-pv"
                  existingDynamicVolume: false
                  size: 15Gi
                  useDynamicProvisioning: true
                  storageClassName: "<your stotage class name>"
              camTerraformPV:
                name: cam-terraform-pv
                persistence:
                  accessMode: ReadWriteMany
                  enabled: true
                  existingClaimName: "cam-terraform-pv"
                  existingDynamicVolume: false
                  size: 15Gi
                  storageClassName: "<your stotage class name>"
                  useDynamicProvisioning: true
      ```

   3. Wait until the IBM Cloud Pak for Multicloud Management installation is complete and all pods of `ibm-common-services` namespace are running.

### 6. Restore IBM Common Services database

1. Run `mongo-restore-dbdump` job for common services database to restore. The `mongo-restore-dbdump.yaml` file is available in `<Path of cp4mcm-samples>/bcdr/restore/scripts/cs` folder, where `<Path of cp4mcm-samples>` is the real path where you put the `cp4mcm-samples` GitHub repository.

   ```
   oc apply -f mongo-restore-dbdump.yaml
   ```

   Wait untill the `mongo-restore-dbdump` job is in `Completed` status. You can run the following command to check the `mongo-restore-dbdump` job status.

        ```
        oc get pod -n ibm-common-services | grep -i icp-mongodb-restore
        ``` 

2. Enable the Monitoring operator (`ibm-management-monitoring`) by updating IBM Cloud Pak for Multicloud Management `Installation` CR.

### 7. Restore Infrastructure Management

 **Notes**: Because Infrastructure Management restoration requires its CRD to be present before restoration, you need to perform Infrastructure Management restoration  after Common Services and IBM Cloud Pak for Multicloud Management installation.

1. Configure LDAP, and ensure that LDAP group name is the same as the one that is defined in the backed-up Infrastructure Management CR.

2. Restore Infrastructure Management by running either of the following commands:

   ```
   bash restore.sh -im
   
   or 
   
   bash restore.sh --im-restore
   ```

### 8. Restore Managed Clusters and applications
This step needs to be done after RHCAM and IBM Cloud Pak for Multicloud Management installation.

1. To break the connection between managed and the old Hub Cluster that you backed up, delete the klusterlet from managed clusters by running the following shell script in the managed cluster:
 
   ```
   https://github.com/open-cluster-management/deploy/blob/master/hack/cleanup-managed-cluster.sh
   ```

2. Reimport the managed cluster in the new restored Hub Cluster after the klusterlet deletion is completed.
3. After the reimport is completed, restore all the required resources by running the following command:

   ```
   velero restore create <MANAGED_CLUSTER_RESTORE> \
   --from-backup <BACKUP_NAME> \
   --include-namespaces open-cluster-management,<MANAGED_CLUSTER_NAMESPACE>,<DEPLOYED_APPLICATION_NAMESPACE>
   ```

  **Notes**

- If the restoration command fails with errors, run the same command again.
- You need to designate <MANAGED_CLUSTER_NAMESPACE> with the namespace where the managed cluster is imported. If there are multiple managed cluster namespaces, add each namespace and separate them by commas. For example, `managed-cluster1-ns,managed-cluster2-ns,managed-cluster3-ns`.
- You need to designate <DEPLOYED_APPLICATION_NAMESPACE> with the namespace where managed cluster application is deployed. If there are multiple application deployed namespaces, add each namespace and separate them by commas. For example, `app1-ns,app2-ns,app3-ns`.