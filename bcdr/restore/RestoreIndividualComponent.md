# IBM Cloud Pak for Multicloud Management individual components restore in the same(existing) cluster

## Prerequisites

- Install the `watch`, `kubectl`, `oc`, `python`, `velero`, `Helm`, `jq`, `git` and `cloudctl` CLIs on the workstation machine, where you can access the OpenShift cluster, initiate and monitor the restoration of IBM Cloud Pak® for Multicloud Management.
- If your environment has no access to Internet, you need to upload the `Nginx` image to all the worker nodes by following [Uploading the Nginx image in an air gap environment](../install/UploadNginxImageOnAirgap.md). The `Nginx` container is used to restore MongoDB that is running in the `ibm-common-services` namespace.
- All required storage classes must be created prior to the restore and storage classes must have the same name as the backup cluster.

**Notes**
- Common Services restore needs to be performed in a fresh cluster.
- It is highly recommended that the version of Common Services, Red Hat Advanced Cluster Management, and IBM Cloud Pak for Multicloud Management in restored cluster should be the same as the backup cluster.
- Monitoring or Managed Services restore needs to be performed when Common Services and IBM Cloud Pak for Multicloud Management operators are running.
- The backup and restoration of Red Hat Advanced Cluster Management is managed independently of IBM Cloud Pak for Multicloud Management. Refer to [Red Hat Advanced Cluster Management documentation](https://access.redhat.com/documentation/en-us/red_hat_advanced_cluster_management_for_kubernetes) for backing up and restoring Red Hat Advanced Cluster Management observability service. When you install the Red Hat Advanced Cluster Management observability service during restoration, it is recommended to use the same S3 bucket that is used during the installation of observability service in the backup cluster.

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

  - For offline install, you can follow the steps mentioned [here](../install/InstallVeleroOnAirgap.md)
  - For online install, you can follow the steps mentioned [here](../install/VeleroInstallation.md)

4. Change the following values in the file `restore-data.json` based on real values. The file `restore-data.json` is available in the directory `<Path of cp4mcm-samples>/bcdr/restore/scripts`, where `<Path of cp4mcm-samples>` is the real path where you put the `cp4mcm-samples` GitHub repository.

   ```
   "airGap": "<Indicates whether the install is online or offline. Set the value to true to install offline and false to install online>",
       
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
    "airGap":"false",
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
       nohup bash restore.sh -c > cs-restore.log &
       ```
       or 

       ```
       nohup bash restore.sh --cs-restore > cs-restore.log &
       ```

2. Install Common Services and IBM Cloud Pak for Multicloud Management

    1. Install RHACM and enable the `observability` feature.
    2. Create the installer catalog sources. For more information visit [here](https://www-03preprod.ibm.com/support/knowledgecenter/SSFC4F_2.3.0/install/prep_online.html#create_source).
    3. Install Common Services operator.
    4. Install IBM Cloud Pak for Multicloud Management operator and create its CR.
    5. Wait until the IBM Cloud Pak for Multicloud Management installation is complete and all pods of `ibm-common-services` namespace are running.

3. Restore IBM Common Services database.

    1. Change the image value in `mongo-restore-dbdump.yaml` file. The file is available in `<Path of cp4mcm-samples>/bcdr/restore/scripts/cs` folder, where `<Path of cp4mcm-samples>` is the real path where `cp4mcm-samples` GitHub repository is cloned. This image value should be equal to the `mongoDBDumpImage` helm variable value which is used for taking backup. Get the image value by running the following command.

       ```
       kubectl get configmap backup-metadata -n backup -o jsonpath='{.data.mongoDBDumpImage}'
       ```

    2. Run `mongo-restore-dbdump` job for common services database to restore.

       ```
       oc apply -f mongo-restore-dbdump.yaml
       ```
    
       Wait untill the `mongo-restore-dbdump` job is in `Completed` status. You can run the following command to check the `mongo-restore-dbdump` job status.

       ```
       oc get pod -n ibm-common-services | grep -i icp-mongodb-restore
       ``` 

### Restore Monitoring
1. Uninstall Monitoring operator (`ibm-management-monitoring`) by running following command:

   ```
   oc patch installations.orchestrator.management.ibm.com ibm-management -n <namespace in which IBM Cloud Pak for Multicloud Management is installed> --type='json' -p='[{"op": "replace", "path": "/spec/pakModules/1/enabled", "value": false }]'
   ```

2. Delete the secrets and configmaps which were left after uninstall by running the following commands:

    ```
    oc delete secret --all -n management-monitoring
    oc delete cm --all -n management-monitoring
    ```

3. Start the restoration process by running either of the following commands:

    ```
    nohup bash restore.sh -monitoring > monitoring-restore.log &
    ```
    or 
  
    ```
    nohup bash restore.sh --monitoring-restore > monitoring-restore.log &
    ```

4. Delete `platform-auth-idp-credentials` and `monitoring-oidc-client` secrets by running the following command:
  
    ```
    oc delete secret platform-auth-idp-credentials monitoring-oidc-client -n management-monitoring
    ```

5. Install Monitoring operator (`ibm-management-monitoring`) by running following command:

   ```
   oc patch installations.orchestrator.management.ibm.com ibm-management -n <namespace in which IBM Cloud Pak for Multicloud Management is installed> --type='json' -p='[{"op": "replace", "path": "/spec/pakModules/1/enabled", "value": true }]'
   ```


### Restore Managed Services
1. Uninstall Managed Services operator (`ibm-management-cam-install`) by running following command:

   ```
   oc patch installations.orchestrator.management.ibm.com ibm-management -n <namespace in which IBM Cloud Pak for Multicloud Management is installed> --type='json' -p='[{"op": "replace", "path": "/spec/pakModules/0/config/3/enabled", "value": false }]'
   ```

2. Start the restoration process by running either of the following commands:

    ```
    nohup bash restore.sh -mservices > managedservices-restore.log &
    ```
    or 
  
    ```
    nohup bash restore.sh --mservices-restore > managedservices-restore.log &
    ```

3. Install Managed Services operator (`ibm-management-cam-install`) by running following command:

   ```
   oc patch installations.orchestrator.management.ibm.com ibm-management -n <namespace in which IBM Cloud Pak for Multicloud Management is installed> --type='json' -p='[{"op": "replace", "path": "/spec/pakModules/0/config/3/enabled", "value": true }]'
   ```

## Troubleshooting

### 1. LDAP user login is not working after restore.

Perform the following steps for LDAP user to login after restore:

1. Login to the IBM Cloud Pak for Multicloud Management console using default admin credentials.
2. From the navigation menu, select **Administer > Identify and access**.
3. Select the ldap connection and click **Edit connection**.
4. Click **Test connection**.
5. Click **Save** once the connection is success.
You can now retry to login using the ldap credentials.