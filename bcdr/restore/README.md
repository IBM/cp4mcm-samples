# IBM Cloud Pak for Multicloud Management Restore

## Prerequisites

- Install `watch`, `kubectl`, `oc`, `python`, `velero`, `Helm` , and `cloudctl` CLI on the workstation machine. From the workstation machine, you have to initialize and monitor the restore of IBM Cloud Pak® for Multicloud Management.

**Notes**
- The restore cluster should be in the same region as backup cluster.
- It is recommended to have the same OpenShift version in both the backed up and restored cluster.
- If Monitoring needs to be restored, then we need to keep backup and restore cluster domain name same otherwise after restore monitoring agents will not be able to connect to MCM.
- The following outlined steps are to restore IBM Cloud Pak for Multicloud Management in a new cluster.
- Current backup also backs up keys and certificates from the previous clusters. This is required to ensure restored data is accessible in the new deployment. This restore flow works in conjunction with backup flow detailed in the backup section. It cannot run independently.
- Do the following restore procedure and it is important to have data restored first and then deploy cluster. Otherwise, things will not work as expected.


## Disaster recovery steps

### 1. Restore Common Services, Monitoring, GRC, VA\MA, and Managed Services by running `restore.sh` file

1. Clone the GitHub repository.

     ```
     git clone https://github.com/IBM/cp4mcm-samples.git
     ```
       
2. Change the following values in `restore-data.json` file based on your values, `restore-data.json` file is available in `<Path of cp4mcm-samples>/bcdr/restore/scripts` folder. You need to designate `<Path of cp4mcm-samples>` with the real path where you put the `cp4mcm-samples` GitHub repository

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

 3. In the restored cluster perform the following command:

    ```
    oc login --token=<TOKEN> --server=<URL>
    ```

     Where:

     - `<TOKEN>` is the token that you use to log in to the OpenShift cluster.
     -  `<URL>` is the OpenShift server URL.

 4. Restore Common Services, Monitoring, GRC, VA\MA, and Managed Services by running `restore.sh` script. When you execute this script with the following option, it installs velero first in restore cluster and then it performs all the other restore operations.

    1. Go to the directory `<Path of cp4mcm-samples>/bcdr/restore/scripts` by running the following command, You need to designate    `<Path of cp4mcm-samples>` with the real path where you put the `cp4mcm-samples` GitHub repository

       ```
       cd <Path of cp4mcm-samples>/bcdr/backup/scripts
       ```

    2. Execute following command to start the restore process

       ```
       bash restore.sh -a 
       ```
       or 

       ```
       bash restore.sh --all-restore
       ```

## 2. Install Common Services and IBM Cloud Pak for Multicloud Management

  1. Install RHCAM and enable `observability` feature.
  2. Install Common Services operator and make the `mongodb` pod count as 1 in Common Services installation instance as shown here: 

     ```
      apiVersion: operator.ibm.com/v3
      kind: CommonService
      metadata:
       name: common-service
       namespace: ibm-common-services
      spec:
       size: medium
       services:
       - name: ibm-mongodb-operator
         spec:
          mongoDB:
            replicas: 1
     ```

   3. Install IBM Cloud Pak for Multicloud Management operator and create its CR by enabling different components for example: Infrastructure Management, Managed Services, Service Library, GRC, and VA\MA except Monitoring. Also for Managed Services specify the existing claim name details as given below.

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

   4. Wait until the IBM Cloud Pak for Multicloud Management installation is complete and all pods of `ibm-common-services` namespace come UP.

### 3. Restore IBM Common Services DB

1. Run `mongo-restore-dbdump` job for common services db restore, `mongo-restore-dbdump.yaml` file is available in `<Path of cp4mcm-samples>/bcdr/restore/scripts/cs` folder. You need to designate `<Path of cp4mcm-samples>` with the real path where you put the `cp4mcm-samples` GitHub repository

   ```
   oc apply -f mongo-restore-dbdump.yaml
   ```

2. After restoring IBM common services database set the mongo db cluster count to `default` by modifying common services installation yaml.
3. Enable Monitoring by updating IBM Cloud Pak for Multicloud Management `Installation` CR.

### 4. Restore Infrastructure Management

 **Notes**: As Infrastructure Management restore requires its CRD to be present before restore hence we need to perform Infrastructure Management restore after Common Services and IBM Cloud Pak for Multicloud Management installation.

1. Do LDAP configuration if not done and LDAP group name should be same as defined in backed up Infrastructure Management CR.

2. Restore Infrastructure Management by running `restore.sh` file with `-im` or `--im-restore` option.

   ```
   bash restore.sh -im
   
   or 
   
   bash restore.sh --im-restore
   ```

### 5. Restore Managed Cluster and Application

1. Delete the klusterlet from managed cluster to break the connection between managed and old hub(backed up) cluster, for this you need to execute the following shell script in a managed cluster:
 
   ```
   https://github.com/open-cluster-management/deploy/blob/master/hack/cleanup-managed-cluster.sh
   ```

2. Reimport the managed cluster in the new hub(restore) cluster, after klusterlet deletion is done.
3. Restore all the required resources after Reimport is completed.

   ```
   velero restore create <MANAGED_CLUSTER_RESTORE> \
   --from-backup <BACKUP_NAME> \
   --include-namespaces open-cluster-management,<MANAGED_CLUSTER_NAMESPACE>,<DEPLOYED_APPLICATION_NAMESPACE>
   ```

  **Notes**

- This restore should be performed after RHCAM and IBM Cloud Pak for Multicloud Management installation.
- When any velero restore is partially failing with errors then perform the same restore again with the same command.