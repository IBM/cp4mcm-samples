# IBM Cloud Pak for Multicloud Management Restore

## Prerequisites
- Install `watch`, `kubectl`, `oc`, `python`, `velero`, `Helm` , and `cloudctl` CLI.

## Notes:
- The restore cluster should be in the same zone as backup cluster.
- When any velero restore is partially failing with errors then perform the same restore again with the same command.
- It is recommended to have the same OpenShift version in both the backed up and restored cluster.
- If Monitoring needs to be restored, then we need to keep backup and restore cluster domain name same otherwise after restore monitoring agents will not be able to connect to MCM.

## Disaster recovery steps

### Restore Common Services, Monitoring, GRC, VA\MA, and Managed Services by running `restore.sh` file

#### Step 1

Change the following values in `restore-data.json` file based on your values.

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

##### For Example:

```
        "backupName":"cp4mcm-backup-373383393",
        
        "ingressSubdomain":"apps.cp4mcm-restore.multicloud-apps.io",
        
        "grcCrNamespace":"default",
        
        "imRestoreLabelKey":"imbackup",
        "imRestoreLabelValue":"test",

        "monitoringRestoreLabelKey":"appbackup",
        "monitoringRestoreLabelValue":"monitoring"
```


#### Step 2

In the restored cluster perform the following command:

```
oc login
```

#### Step 3

Restore Common Services, Monitoring, GRC, VA\MA, and Managed Services by running the script `restore.sh` using the following command. The script is available in `scripts` folder.

```
bash restore.sh -a` or `bash restore.sh --all-restore
```

#### Step 4

Delete all the installed operators from `management-infrastructure-management` namespace.

### Install Common Services and IBM Cloud Pak for Multicloud Management

- Install RHCAM and enable `observability` feature.
- Install Common Services operator and make the `mongodb` pod count as 1 in Common Services installation instance as shown here: 

  ```
  apiVersion: operator.ibm.com/v3
  kind: CommonService
  metadata:
    name: common-service
    namespace: ibm-common-services
  spec:
    size: as-is
    services:
    - name: ibm-mongodb-operator
      spec:
        mongoDB:
          replicas: 1
  ```

- Install IBM Cloud Pak for Multicloud Management operator and create its CR by enabling different components for example: Infrastructure Management, Managed Services, Service Library, GRC, and VA\MA except Monitoring.
- Wait until the IBM Cloud Pak for Multicloud Management installation is complete.
- In case if some pods of `ibm-common-services` namespace are not coming up due to secret not found or ConfigMap not found issue then run the following shell script:

   ```
   https://github.com/IBM/cp4mcm-samples/blob/master/scripts/cp4mcm-rhacm21-cp-issuer-secret.sh
   ```

- If `auth-idp`, `common-web-ui`, `iam-onboarding`,  , and `security-onboarding` pods are not coming up and `nginx-ingress-controller` pod is crashing again and again claiming `unable update proxy address` then we need to perform the following steps:

   ```
   oc get NginxIngress  default -o yaml > default-nginx.yaml
   ```

   ```
   oc delete NginxIngress default
   ```

   ```
   oc get csv | grep nginx
   ```

   ```
   oc get csv ibm-ingress-nginx-operator.v1.3.1 -o yaml
   ```

   Copy JSON data starting from { "apiVersion": "operator.ibm.com/v1alpha1" & save in `data.json` file.

   ```
   oc apply -f data.json
   ```

   ```
   oc delete po ibm-ingress-nginx-operator
   ```

   Once the operator is UP, check `ibmcloud-cluster-info` configMap, it should have updated proxy-address.

- After performing these steps wait until all pods of `ibm-common-services` namespace come UP.

### Restore IBM Common Services DB

- Run `mongo-restore-dbdump` job for common services db restore, job definition file is available in `CP4MCM-BCDR/restore/scripts/cs` folder.

  ```
  oc apply -f mongo-restore-dbdump.yaml
  ```

- After restoring IBM common services database set the mongo db cluster count to `default` by modifying common services installation yaml.
- Enable Monitoring by updating IBM Cloud Pak for Multicloud Management `Installation` CR.

### Create Managed Services CR using existing claim name

- Delete the Managed Services CR, which is created through installation and create a new CR using the existing claim name. CR deletion can be done from OpenShift web console or using the following command:

  ```
  oc delete ManageService cam -n management-infrastructure-management
  ```

- After installation, if you are not able to access the Managed Services from IBM Cloud Pak for Multicloud Management console and getting error like `Unable to get access token` then we need to do oidc registration by using the following steps.

#### Steps for Managed Services oidc registration

- Delete `cam-oauth-client-secret`.

   ```
   oc delete secret cam-oauth-client-secret -n management-infrastructure-management
   ```

- Copy `cam-oidc-client` in a separate yaml, for example: `cam-oidc-client.yaml`.

  ```
  oc get client cam-oidc-client -n management-infrastructure-management -o yaml > cam-oidc-client.yaml
  ```

- Delete the `clientId` property from `cam-oidc-client.yaml` file and then apply the changes.

  ```
  oc apply -f cam-oidc-client.yaml
  ```

- Delete the `oidcclient-watcher` pod from `ibm-common-services` namespace.

- Delete `cam-ui-basic` and `cam-portal-ui` pods and then CAM should be accessible from IBM Cloud Pak for Multicloud Management console.

### Restore Infrastructure Management

#### Note: As Infrastructure Management restore requires its CRD to be present before restore hence we need to perform Infrastructure Management restore after Common Services and IBM Cloud Pak for Multicloud Management installation.

- Do LDAP configuration if not done and LDAP group name should be same as defined in backed up Infrastructure Management CR.

- Restore Infrastructure Management by running `restore.sh` file with `-im` or `--im-restore` option.

  ```
  bash restore.sh -im` or `bash restore.sh --im-restore
  ```

### Restore Managed Cluster and Application

- Delete the klusterlet from managed cluster to break the connection between managed and old hub(backed up) cluster, for this you need to execute the following shell script in a managed cluster:

  ```
  https://github.com/open-cluster-management/deploy/blob/master/hack/cleanup-managed-cluster.sh
  ```

- Reimport the managed cluster in the new hub(restore) cluster, after klusterlet deletion is done.
- Restore all the required resources after Reimport is completed.

   ```
   velero restore create <MANAGED_CLUSTER_RESTORE> \
   --from-backup <BACKUP_NAME> \
   --include-namespaces open-cluster-management,<MANAGED_CLUSTER_NAMESPACE>,<DEPLOYED_APPLICATION_NAMESPACE>
   ```

   #### Note: This restore should be performed after RHCAM and IBM Cloud Pak for Multicloud Management installation.
