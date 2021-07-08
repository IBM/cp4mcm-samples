# IBM Cloud Pak for Multicloud Management individual components restore in the same(existing) cluster

## Prerequisites

- Install the `watch`, `kubectl`, `oc`, `python`, `velero`, `Helm`, `jq`, `git` and `cloudctl` CLIs on the workstation machine, where you can access the OpenShift cluster, initiate and monitor the restoration of IBM Cloud Pak® for Multicloud Management.

**Notes**
- Common Services restore needs to be performed in a fresh cluster.
- Monitoring or Managed Services restore needs to be performed when Common Services and IBM Cloud Pak for Multicloud Management operators are running.

## Procedure

1. Clone the GitHub repository by running the following command:

     ```
     git clone https://github.com/IBM/cp4mcm-samples.git
     ```
       
2. Log in to the OpenShift cluster

     ```
     oc login --token=<TOKEN> --server=<URL>
     ```

     Where:
   
     - `<TOKEN>` is the token that you use to log in to the OpenShift cluster.
     - `<URL>` is the OpenShift server URL.

3. Install Velero

  - For offline install, you can follow the steps mentioned [here](../velero/InstallVeleroOnAirgap.md)
  - For online install, you can follow the steps mentioned [here](../velero/VeleroInstallation.md)

4. Change the following values in the file `restore-data.json` based on real values. The file `restore-data.json` is available in the directory `<Path of cp4mcm-samples>/bcdr/restore/scripts`, where `<Path of cp4mcm-samples>` is the real path where you put the `cp4mcm-samples` GitHub repository.

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

### Restore Common Services
1. Restore Common Services.

    1. Go to the directory `<Path of cp4mcm-samples>/bcdr/restore/scripts` by running the following command, where `<Path of cp4mcm-samples>` is the real path where you put the `cp4mcm-samples` GitHub repository.

       ```
       cd <Path of cp4mcm-samples>/bcdr/restore/scripts
       ```

    2. Start the restoration process by running either of the following commands:

       ```
       bash restore.sh -c
       ```
       or 

       ```
       bash restore.sh --cs-restore
       ```

2. Install Common Services and IBM Cloud Pak for Multicloud Management

    1. Install RHCAM and enable the `observability` feature.
    2. Install IBM Cloud Pak for Multicloud Management operator and create its CR.
    3. Wait until the IBM Cloud Pak for Multicloud Management installation is complete and all pods of `ibm-common-services` namespace are running.

3. Restore IBM Common Services database.

    Run `mongo-restore-dbdump` job for common services database to restore. The `mongo-restore-dbdump.yaml` file is available in `<Path of cp4mcm-samples>/bcdr/restore/scripts/cs` folder, where `<Path of cp4mcm-samples>` is the real path where you put the `cp4mcm-samples` GitHub repository.

        ```
        oc apply -f mongo-restore-dbdump.yaml
        ```
    
    Wait untill the `mongo-restore-dbdump` job is in `Completed` status. You can run the following command to check the `mongo-restore-dbdump` job status.

        ```
        oc get pod -n ibm-common-services | grep -i icp-mongodb-restore
        ``` 

### Restore Monitoring
1. Uninstall Monitoring operator (`ibm-management-monitoring`) by updating IBM Cloud Pak for Multicloud Management `Installation` CR.

2. Delete the secrets and configmaps which were left after uninstall by running the following commands:

    ```
    oc delete secret all -n management-monitoring
    oc delete cm all -n management-monitoring
    ```

3. Start the restoration process by running either of the following commands:

    ```
    bash restore.sh -monitoring
    ```
    or 
  
    ```
    bash restore.sh --monitoring-restore
    ```

4. Delete `platform-auth-idp-credentials` and `monitoring-oidc-client` secrets by running the following command:
  
    ```
    oc delete secret platform-auth-idp-credentials monitoring-oidc-client -n management-monitoring
    ```

5. Install Monitoring operator (`ibm-management-monitoring`) by updating IBM Cloud Pak for Multicloud Management `Installation` CR.


### Restore Managed Services
1. Uninstall Managed Services operator (`ibm-management-cam-install`) by updating IBM Cloud Pak for Multicloud Management `Installation` CR.

2. Start the restoration process by running either of the following commands:

    ```
    bash restore.sh -mservices
    ```
    or 
  
    ```
    bash restore.sh --mservices-restore
    ```

3. Install Managed Services operator (`ibm-management-cam-install`) by updating IBM Cloud Pak for Multicloud Management `Installation` CR.
