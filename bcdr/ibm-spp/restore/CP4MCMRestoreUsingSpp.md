# IBM Cloud Pak® for Multicloud Management Restore using IBM SPP

## Prerequisites
- Create an Openshift cluster with required configuration.
	- Recommended to have the same OpenShift version in both backed up and restored cluster.
- Create required storage and volume snapshot classess.
	- Ensure to have the same storage and snapshot classes as defined in the origin cluster.
- Register the cluster with required SPP server. IBM SPP has three components: IBM SPP server, BAAS Agent, and vSnap Server. Ensure to install these components and register the cluster with SPP server before you start the restore operation. Visit [here](https://www.ibm.com/docs/en/spp/) for more information about installation and cluster registration.

**Notes**
- If Monitoring needs to be restored, you need to keep the backed up and restored cluster domain name same. Otherwise, Monitoring agents might not be able to connect to IBM Cloud Pak® for Multicloud Management after restoration.
- The following steps in the Procedure section are to restore IBM Cloud Pak® for Multicloud Management in a new cluster.
- The back up also backs up keys and certificates from the previous clusters. Ensure that the restored data is accessible in the new deployment. This restoration procedure works with the back up procedure in Backing up IBM Cloud Pak® for Multicloud Management. Without backup, you can't run the restoration independently.
- It is important to restore the backed up data first for different components such as Common Services, Monitoring and Managed Services, and then deploy Common Services and IBM Cloud Pak® for Multicloud Management operators. Otherwise, the restoration might not work.
- It is highly recommended that the version of Common Services, Red Hat Advanced Cluster Management, and IBM Cloud Pak® for Multicloud Management in restored cluster should be the same as the back up cluster.
- The back up and restoration of Red Hat Advanced Cluster Management is managed independently of IBM Cloud Pak® for Multicloud Management. Refer to [Red Hat Advanced Cluster Management documentation](https://access.redhat.com/documentation/en-us/red_hat_advanced_cluster_management_for_kubernetes) for backing up and restoring Red Hat Advanced Cluster Management observability service. When you install the Red Hat Advanced Cluster Management observability service during restoration, it is recommended to use the same S3 bucket that is used during the installation of observability service in the back up cluster.


## Procedure

### 1. Restore required IBM Cloud Pak® for Multicloud Management components except IM
Please follow the SPP [documentation](https://www.ibm.com/docs/en/spp/10.1.9?topic=data-restoring-openshift-cluster-scoped-namespace-scoped-resources) for restore steps and **use respective component label** to restore sequentially.
  
  
  1. **Restoring Common Services:** In the Select source page, browse the table and expand the cluster to see the resources that are available for the restore operation. Toggle to label views by clicking the options in the View menu. Search `appbackup=cs` label and perform restoration.
  2. **Restoring Managed Services:** Once restoration for common services is complete, then follow the same steps to restore Managed Services. Search `appbackup=cam` label and perform restoration.
  3. **Restoring Monitoring:** Once restoration for managed services is complete, then follow the same steps to restore Monitoring. Search `appbackup=monitoring` label and perform restoration.


### 2. Install Common Services and IBM Cloud Pak® for Multicloud Management
     
  1. Install Red Hat® Advanced Cluster Management and enable the `observability` feature if enabled in origin cluster.
  2. Create the installer catalog sources. For more information, see [here](https://www-03preprod.ibm.com/support/knowledgecenter/SSFC4F_2.3.0/install/prep_online.html#create_source).
  3. Install Common Services operator
  4. Install IBM Cloud Pak® for Multicloud Management operator and create its CR by enabling different components. For example, enable Infrastructure Management, Managed Services, Service Library, GRC, Vulnerability Advisor (VA), Mutation Advisor (MA), and don't enable Monitoring. For Managed Services, specify the existing claim name details as follows:
			    
	    ```
			 - enabled: true
                  name: ibm-management-cam-install
                  spec:
                   manageservice:
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
	    ```
  5. Wait until the IBM Cloud Pak® for Multicloud Management installation is complete and all pods of `ibm-common-services` namespace are running.

### 3. Restore IBM Common Services database

  1. Clone the GitHub repository

     ```
      git clone https://github.com/IBM/cp4mcm-samples.git
     ```

  2. Go to the directory `<Path of cp4mcm-samples>/bcdr/ibm-spp/restore/scripts/cs` by running the following command, where `<Path of cp4mcm-samples>` is the real path where you put the `cp4mcm-samples` GitHub repository.

     ```
      cd <Path of cp4mcm-samples>/bcdr/ibm-spp/restore/scripts/cs
     ```
     
  3. Change the image value in `mongo-restore-dbdump.yaml` file. The file is available in `<Path of cp4mcm-samples>/bcdr/ibm-spp/restore/scripts/cs` folder, where `<Path of cp4mcm-samples>` is the real path where `cp4mcm-samples` GitHub repository is cloned. This image value should be same as the image which is used for creating mongo dump during back up process.


  4. Run `mongo-restore-dbdump` job for common services database to restore.

     ```
     oc apply -f mongo-restore-dbdump.yaml
     ```

     Wait untill the `mongo-restore-dbdump` job is in `Completed` status. You can run the following command to check the `mongo-restore-dbdump` job status.

     ```
     oc get pod -n ibm-common-services | grep -i icp-mongodb-restore
     ``` 

  5. Enable the Monitoring operator (`ibm-management-monitoring`) by running the following command:

     ```
     oc patch installations.orchestrator.management.ibm.com ibm-management -n <namespace in which IBM Cloud Pak® for Multicloud Management is installed> --type='json' -p='[{"op": "replace", "path": "/spec/pakModules/1/enabled", "value": true }]'
     ```

### 4. Restore Infrastructure Management

  **Notes**: Infrastructure Management restoration requires its CRD before restoration. Ensure to perform Infrastructure Management restoration after Common Services and IBM Cloud Pak® for Multicloud Management installation.

  1. Configure LDAP, and ensure that LDAP group name is same as defined in the backed up Infrastructure Management CR.

  2. Please follow the SPP [documentation](https://www.ibm.com/docs/en/spp/10.1.9?topic=data-restoring-openshift-cluster-scoped-namespace-scoped-resources) for restore steps. In the Select source page, browse the table and expand the cluster to see the resources that are available for the restore operation. Toggle to label views by clicking the options in the View menu. Search `imbackup=t` label and perform restoration.

## Troubleshooting

### 1. LDAP user login is not working after restore.

Perform the following steps for LDAP user to login after restore:

1. Login to the IBM Cloud Pak® for Multicloud Management console using default admin credentials.
2. From the navigation menu, select **Administer > Identify and access**.
3. Select the ldap connection and click **Edit connection**.
4. Click **Test connection**.
5. Click **Save** once the connection is success.
