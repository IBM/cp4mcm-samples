#!/bin/bash

#--------------------------------------------------------------------------
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corporation 2019.
#
# US Government Users Restricted Rights - Use, duplication or disclosure
# restricted by GSA ADP Schedule Contract with IBM Corporation.
#--------------------------------------------------------------------------

CURRENT=`pwd`
log_file="$CURRENT/restore.log"

echo "============================================="  | tee -a "$log_file"

# Reading airGap info from config file
airGap=$(cat restore-data.json | jq -r '.airGap')

#Reading backup name from config file
backupName=$(cat restore-data.json | jq -r '.backupName')

#Reading velero helm chart name from config file
veleroHelmchart=$(cat restore-data.json | jq -r '.veleroHelmchart')
veleroHelmchartVersion=$(cat restore-data.json | jq -r '.veleroHelmchartVersion')

#Reading cluster subdomain value from config file
ingressSubdomain=$(cat restore-data.json | jq -r '.ingressSubdomain')

#Reading cs restore info from config file
csRestoreNamePrefix=$(cat restore-data.json | jq -r '.csRestoreNamePrefix')

#Reading va\ma restore info from config file
vaMaRestoreNamePrefix=$(cat restore-data.json | jq -r '.vaMaRestoreNamePrefix')

#Reading grc restore info from config file
grcRestoreNamePrefix=$(cat restore-data.json | jq -r '.grcRestoreNamePrefix')
grcCrRestoreNamePrefix=$(cat restore-data.json | jq -r '.grcCrRestoreNamePrefix')
grcCrNamespace=$(cat restore-data.json | jq -r '.grcCrNamespace')

#Reading openldap restore info from config file
openldapRestoreNamePrefix=$(cat restore-data.json | jq -r '.openldapRestoreNamePrefix')
openldapInstalledNamespace=$(cat restore-data.json | jq -r '.openldapInstalledNamespace')

#Reading IM restore info from config file
imRestoreNamePrefix=$(cat restore-data.json | jq -r '.imRestoreNamePrefix')
imRestoreLabelKey=$(cat restore-data.json | jq -r '.imRestoreLabelKey')
imRestoreLabelValue=$(cat restore-data.json | jq -r '.imRestoreLabelValue')

#Reading CAM restore info from config file
camRestoreNamePrefix=$(cat restore-data.json | jq -r '.camRestoreNamePrefix')
camRestoreLabelKey=$(cat restore-data.json | jq -r '.camRestoreLabelKey')
camRestoreLabelValue=$(cat restore-data.json | jq -r '.camRestoreLabelValue')

#Reading Monitoring restore info from config file
sloAndSythenticCrdRestoreNamePrefix=$(cat restore-data.json | jq -r '.sloAndSythenticCrdRestoreNamePrefix')
monitoringSecretRestoreNamePrefix=$(cat restore-data.json | jq -r '.monitoringSecretRestoreNamePrefix')
monitoringRestoreNamePrefix=$(cat restore-data.json | jq -r '.monitoringRestoreNamePrefix')
monitoringRestoreLabelKey=$(cat restore-data.json | jq -r '.monitoringRestoreLabelKey')
monitoringRestoreLabelValue=$(cat restore-data.json | jq -r '.monitoringRestoreLabelValue')

# Function to wait for a specific time, it requires one positional argument i.e timeout
wait(){
   timeout=$1
   i=0
   while [ $i -ne $timeout ]; do
     printf "."
     sleep 1
     ((i++))
   done
}

# This functio is to print restore status message 
printRestoreStatus(){
   if [[ "$restoreStatus" == 'PartiallyFailed' ]]; then
      echo "Restore is PartiallyFailed hence retrying the restore again"
   elif [[ "$restoreStatus" == 'Completed' ]]; then
      echo "Restore is Completed"
   elif [[ "$restoreStatus" == '' ]]; then
      echo ""
   else
      echo "Restore status is: $restoreStatus"
   fi
}

# Function to check pod readyness using pod label, it requires 3 positional arguments such as namespace, podLabel, retryCount 
checkPodReadyness(){
   namespace=$1
   podLabel=$2
   retryCount=$3
   counter=0
   pods=$(kubectl -n $namespace get pods -l $podLabel --no-headers | grep -F "1/1" -v)

   while [ "${pods}" ]; do
     wait "5"
     echo "Waiting for Pods to be READY"  | tee -a "$log_file"
     pods=$(kubectl -n $namespace get pods -l $podLabel --no-headers | grep -F "1/1" -v)
     ((counter++))
     if [[ $counter -eq $retryCount ]]; then
        echo "Pods in $namespace namespace are not READY hence terminating the restore process" | tee -a "$log_file"
        exit 1
     fi
   done
}

installVelero() {

   # Preparing the bucket credential file
   rm -f bucket-creds
   echo "[default]" >> bucket-creds
   echo "aws_access_key_id="$accessKeyId >> bucket-creds
   echo "aws_secret_access_key="$secretAccessKey >> bucket-creds

   # Adding velero helm repo
   helm repo add vmware-tanzu $veleroHelmchart

   # Creating velero project
   oc new-project velero

   # Installing velero
   helm install velero --namespace velero --version $veleroHelmchartVersion \
   --set configuration.provider=aws \
   --set-file credentials.secretContents.cloud=./bucket-creds \
   --set use-volume-snapshots=false \
   --set deployRestic=true \
   --set restic.privileged=true \
   --set backupsEnabled=true \
   --set snapshotsEnabled=false \
   --set configuration.backupStorageLocation.name=default \
   --set configuration.backupStorageLocation.bucket=$bucketName \
   --set configuration.backupStorageLocation.config.region=$bucketRegion \
   --set configuration.backupStorageLocation.config.s3ForcePathStyle=true \
   --set configuration.backupStorageLocation.config.s3Url=$bucketUrl \
   --set image.repository=velero/velero \
   --set image.pullPolicy=IfNotPresent \
   --set initContainers[0].name=velero-plugin-for-aws \
   --set initContainers[0].image=velero/velero-plugin-for-aws:v1.0.0 \
   --set initContainers[0].volumeMounts[0].mountPath=/target \
   --set initContainers[0].volumeMounts[0].name=plugins \
   vmware-tanzu/velero

   rm -f bucket-creds

   checkPodReadyness "velero" "app.kubernetes.io/name=velero" "60"
}

# This function is to check whether backup exists or not, it accepts one positional argument i.e backupName
checkBackup(){
   wait "60"
   velero get backup $backupName
   if [ $? -eq 0 ]; then
    echo "Backup exists" | tee -a "$log_file"
   else
    echo "Backup not found hence terminating restore process" | tee -a "$log_file"
    exit 1
fi
}

# This function is to check the restore status periodically till it completes, it accepts one positional argument i.e restoreName
waitTillRestoreCompletion(){
   restoreName=$1
   echo Restore name passed to func waitTillRestoreCompletion is: $restoreName | tee -a "$log_file"
   wait "10"
   restoreStatus=$(velero describe restore $restoreName --details | grep Phase | cut -d " " -f 3)
   echo Initial velero restore status is: $restoreStatus | tee -a "$log_file"
   
   while [ "$restoreStatus" == "InProgress" ] || [ "$restoreStatus" == "New" ]
   do
     echo "Wating for 1 min" | tee -a "$log_file"
     wait "60"
     restoreStatus=$(velero describe restore $restoreName --details | grep Phase | cut -d " " -f 3)
     echo Velero restore status is: $restoreStatus | tee -a "$log_file"
   done
}

# This function is to perform ibm common services restore
csRestore() {
   # Restore ibm-common-services namespace
   for i in {0..1}
   do
    csRestoreNamePrefix=$csRestoreNamePrefix-$(date '+%Y%m%d%H%M%S')
    if [ "$i" == "0" ] || [[ "$restoreStatus" == 'PartiallyFailed' ]]; then
    printRestoreStatus
    csRestoreCommand="velero restore create $csRestoreNamePrefix --include-resources PersistentVolume,PersistentVolumeClaim,Pod,Secret,ConfigMap,ServiceAccount --from-backup $backupName --include-namespaces ibm-common-services --include-cluster-resources=true"
    $(echo $csRestoreCommand)
    # Wait for restore completion
    waitTillRestoreCompletion "$csRestoreNamePrefix"
    fi
   done
   
   # Delete all pods
   oc delete pods --all -n ibm-common-services

   # Delete all configmaps
   oc delete cm --all -n ibm-common-services

   # Except "icp-mongodb-admin" and "icp-serviceid-apikey-secret" secret delete all other secrets
   # Need to test this command through script execution
   kubectl get secrets -n ibm-common-services --no-headers=true | awk '/nginx-ingress-serviceaccount-token|^identity|^alertmanager-ibm-monitoring|^builder|^default|^deployer|^ibm-monitoring|^icp-management-ingress-tls|^icp-metering-api|^icp-mongodb-client|^icp-mongodb-keyfile|^icp-mongodb-metrics|^logging|^mongodb-root|^prometheus|^management-ingress-token|^oauth-client-secret|^my-secret|^prometheus-k8s-token|^rudder-secret|^prometheus-operator-token|^route-tls-secret|^metering-|^auth-|^ibm-monitoring-scrape-targets|^ibm-commonui|^ibm-monitoring-mcm-ctl-token|^ibm-monitoring-exporter-certs|^ibm-monitoring-exporter-token-|^audit|^wed-mcm-custom|^sh.helm|^secretshare|^ibm-common-service-webhook|^iam|^builder|^ibm-auditlogging-op|^cert-manager|^cs|^default|^deployer|^grav|^logging-elk-values|^logging-elk-router-scripts|^logging-elk-filebeat-ds-input-config|^logging-elk-kibana|^logging-elk-logstash|^common|^logging-elk-filebeat-ds-config|^logging-elk-elasticsearch-curator-config|^elasticsearch|^grafana|^helm|^ibm-auditlogging|^ibm-catalog-ui|^ibm-cert-manager|^ibm-elastic-|^ibm-helm|^ibm-i|^ibm-l|^ibm-management|^ibm-metering|^-operator|^ibm-monitoring-exporters|^ibm-monitoring-grafana|^ibm-monitoring-prometheus-operator-ext-lock|^ibm-monitoring-router|^ibm-platform-api-operator-lock|^ibmcloud|^icp-oidcclient-watcher-lock|^ingress-controller|^kms-|^management-ingress-|^mgmtrepo-json|^monitoring-json|^nginx-ingress|^oauth-client-map|^onboard-script|^platform-|^registration-|^secretshare-lock|^system-healthcheck-service-config|logging-elk-elasticsearch-pki-secret|^tiller/{print $1}'| xargs  kubectl delete secrets -n ibm-common-services

   # Delete all serviceaccounts
   oc delete sa --all -n ibm-common-services

   # Delete mongo pvc's
   oc delete pvc mongodbdir-icp-mongodb-0 mongodbdir-icp-mongodb-1 mongodbdir-icp-mongodb-2 -n ibm-common-services

   # Creating dummy mongo db pod to delete .velero folder from dump
   echo Air Gap environment is $airGap
   if [ "$airGap" = "true" ]; then
      oc apply -f cs/dummy-db-airgap.yaml
      checkPodReadyness "ibm-common-services" "app=dummy-db" "60"
      oc delete -f cs/dummy-db-airgap.yaml
   else
      oc apply -f cs/dummy-db.yaml
      checkPodReadyness "ibm-common-services" "app=dummy-db" "60"
      oc delete -f cs/dummy-db.yaml
   fi
}

# This function is to perform va\ma restore
vaMaRestore() {
   # Restore VA\MA
   for i in {0..1}
   do
    vaMaRestoreNamePrefix=$vaMaRestoreNamePrefix-$(date '+%Y%m%d%H%M%S')
    if [ "$i" == "0" ] || [[ "$restoreStatus" == 'PartiallyFailed' ]]; then
    printRestoreStatus
    vaMaRestoreCommand="velero restore create $vaMaRestoreNamePrefix --from-backup $backupName --include-resources PersistentVolume,PersistentVolumeClaim,Pod,ServiceAccount,CustomResourceDefinition,annotators.vulnerabilityadvisor.management.ibm.com,controlplanes.vulnerabilityadvisor.management.ibm.com,crawlers.vulnerabilityadvisor.management.ibm.com,datapipelines.vulnerabilityadvisor.management.ibm.com,indexers.vulnerabilityadvisor.management.ibm.com,advisors.mutationadvisor.management.ibm.com,ConfigMap,Secret --include-namespaces management-security-services --include-cluster-resources=true"
    $(echo $vaMaRestoreCommand)
    # Wait for restore completion
    waitTillRestoreCompletion "$vaMaRestoreNamePrefix"
    fi
   done
   
   # Delete lock configmaps
   kubectl delete cm ibm-mutation-advisor-operator-lock ibm-vulnerability-advisor-operator-lock ibm-management-notary-lock image-security-enforcement-operator-lock -n management-security-services

}

# This function is to perform GRC restore
grcRestore(){
   # Restoring GRC components from kube-system namespace
   for i in {0..1}
   do
    grcRestoreNamePrefix=$grcRestoreNamePrefix-$(date '+%Y%m%d%H%M%S')
    if [ "$i" == "0" ] || [[ "$restoreStatus" == 'PartiallyFailed' ]]; then
    printRestoreStatus
    grcRestoreCommand="velero create restore $grcRestoreNamePrefix --include-resources PersistentVolume,PersistentVolumeClaim,Pod,CustomResourceDefinition,ServiceAccount,StatefulSet,ConfigMap,Secret --from-backup $backupName --include-namespaces kube-system"
    $(echo $grcRestoreCommand)
    # Wait for restore completion
    waitTillRestoreCompletion "$grcRestoreNamePrefix"
    fi
   done

   # Restoring GRC cr's
   for i in {0..1}
   do
    grcCrRestoreNamePrefix=$grcCrRestoreNamePrefix-$(date '+%Y%m%d%H%M%S')
    if [ "$i" == "0" ] || [[ "$restoreStatus" == 'PartiallyFailed' ]]; then
    printRestoreStatus
    # Need to include more grc policies in restore command, currently vm resource policy and vm policy are included
    grcCrRestoreCommand="velero create restore $grcCrRestoreNamePrefix --include-resources CustomResourceDefinition,policies.policy.mcm.ibm.com,policycontrollers.multicloud.ibm.com,vmpolicies.vmpolicy.management.ibm.com,vmresourcepolicies.vmpolicy.management.ibm.com,vmpolicy.management.ibm.com/v1alpha1/VMResourcePolicy,awsproviderpolicies.awspolicy.management.ibm.com,certificatepolicies.policy.open-cluster-management.io,certpolicycontrollers.agent.open-cluster-management.io,configurationpolicies.policy.open-cluster-management.io,iampolicies.policy.open-cluster-management.io,iampolicycontrollers.agent.open-cluster-management.io,placementbindings.policy.open-cluster-management.io,policies.policy.open-cluster-management.io,policycontrollers.agent.open-cluster-management.io,policycontrollers.operator.ibm.com,policydecisions.operator.ibm.com,policypropagators.hybridgrc.management.ibm.com --from-backup $backupName --include-namespaces $grcCrNamespace,management-grc-policies --include-cluster-resources=true"
    $(echo $grcCrRestoreCommand)
    # Wait for restore completion
    waitTillRestoreCompletion "$grcCrRestoreNamePrefix"
    fi
   done

   # Delete Roles, RoleBinding, ConfigMap & ServiceAccount related to gateway-kong app/pod
   oc delete cm gateway-kong-default-custom-server-blocks gateway-kong-hook-resources-cm gateway-kong-post-install-script gateway-kong-pre-delete-script -n kube-system
   oc delete sa gateway-kong gateway-kong-hook-serviceaccount -n kube-system

   # Restart Kong operator pod
   kongOperatorPod=$(oc get pod -n kube-system | grep ibm-kong-operator | cut -d " " -f1)
   oc delete pod $kongOperatorPod -n kube-system

   # Delete all the configmaps from kube-system namespace which are having lock keyword
   oc delete cm bastion-backend-compete-lock hybrid-grc-car-operator-lock ibm-kong-operator-lock ibm-license-advisor-operator-lock ibm-license-advisor-sender-operator-lock ibm-management-mcm-operator-lock ibm-management-vmpolicy-ansible-lock ibm-sre-bastion-operator-lock ibm-sre-inventory-operator-lock mcm-ui-operator-lock multicloud-operators-deployable-lock multicloud-operators-subscription-lock -n kube-system
}

# This function is to perform IM restore
imRestore(){
      # Restore management-infrastructure-management namespace which contains IM and CAM
   for i in {0..1}
   do
    imRestoreNamePrefix=$imRestoreNamePrefix-$(date '+%Y%m%d%H%M%S')
    if [ "$i" == "0" ] || [[ "$restoreStatus" == 'PartiallyFailed' ]]; then
    printRestoreStatus
    imRestoreCommand="velero restore create $imRestoreNamePrefix --from-backup $backupName --include-namespaces management-infrastructure-management -l $imRestoreLabelKey=$imRestoreLabelValue"
    $(echo $imRestoreCommand)
    # Wait for restore completion
    waitTillRestoreCompletion "$imRestoreNamePrefix"
    fi
   done

   #After restore change the cluster ingress subdomain in IM cr
   applicationDomain="inframgmtinstall".$ingressSubdomain
   oc patch IMInstall im-iminstall -n management-infrastructure-management -p "{\"spec\": {\"applicationDomain\": \"$applicationDomain\"}}" --type=merge
}

# This function is to perform cam restore
camRestore(){
   
   # Restore all Secret and ServiceAccount first
   for i in {0..1}
   do
    camSaSecretRestoreName="cam-sa-secret-restore"-$(date '+%Y%m%d%H%M%S')
    if [ "$i" == "0" ] || [[ "$restoreStatus" == 'PartiallyFailed' ]]; then
    printRestoreStatus
    camSaSecretRestoreCommand="velero restore create $camSaSecretRestoreName --from-backup $backupName --include-resources Secret,ServiceAccount --include-namespaces management-infrastructure-management"
    $(echo $camSaSecretRestoreCommand)
    # Wait for restore completion
    waitTillRestoreCompletion "$camSaSecretRestoreName"
    fi
   done

   # Restore CAM Pod, PV and PVC
   for i in {0..1}
   do
    camRestoreNamePrefix=$camRestoreNamePrefix-$(date '+%Y%m%d%H%M%S')
    if [ "$i" == "0" ] || [[ "$restoreStatus" == 'PartiallyFailed' ]]; then
    printRestoreStatus
    camRestoreCommand="velero restore create $camRestoreNamePrefix --from-backup $backupName --include-resources PersistentVolume,PersistentVolumeClaim,Pod --include-namespaces management-infrastructure-management -l $camRestoreLabelKey=$camRestoreLabelValue"
    $(echo $camRestoreCommand)
    # Wait for restore completion
    waitTillRestoreCompletion "$camRestoreNamePrefix"
    fi
   done

   # Delete all restored cam pods
   kubectl delete pods --all -n management-infrastructure-management

   # Delete all restored serviceaccounts
   kubectl delete sa --all -n management-infrastructure-management

   # Delete all restored secrets
   kubectl delete secret --all -n management-infrastructure-management

   # Delete IM postgresql PVC. Although postgresql PVC won't be present but just for the safer side we are deleting this. If it is not present then the command will fail but that should be OK.
   kubectl delete pvc postgresql -n management-infrastructure-management
}

# This function is to perform openldap restore
openLdapRestore(){
   # Restore openldap namespace
   oc new-project openldap
   oc adm policy add-scc-to-user anyuid -z default -n openldap

   for i in {0..1}
   do
    openldapRestoreNamePrefix=$openldapRestoreNamePrefix-$(date '+%Y%m%d%H%M%S')
    if [ "$i" == "0" ] || [[ "$restoreStatus" == 'PartiallyFailed' ]]; then
    printRestoreStatus
    openldapRestoreCommand="velero create restore $openldapRestoreNamePrefix --from-backup $backupName --include-namespaces openldap"
    $(echo $openldapRestoreCommand)
    # Wait for restore completion
    waitTillRestoreCompletion "$openldapRestoreNamePrefix"
    fi
   done

   # Changing ldap-admin route host
   ldapAdminRouteHost="$openldapInstalledNamespace-admin-openldap".$ingressSubdomain
   oc patch route ldap-admin -p "{\"spec\":{\"host\":\"$ldapAdminRouteHost\"}}" -n openldap
}


# This function is to perform monitoring restore
monitoringRestore(){

   # Restore CustomResourceDefinitions for "SloBundle" and "SyntheticBundle" cr
   for i in {0..1}
   do
    sloAndSythenticCrdRestoreNamePrefix=$sloAndSythenticCrdRestoreNamePrefix-$(date '+%Y%m%d%H%M%S')
    if [ "$i" == "0" ] || [[ "$restoreStatus" == 'PartiallyFailed' ]]; then
    printRestoreStatus
    sloAndSythenticCrdRestoreCommand="velero restore create $sloAndSythenticCrdRestoreNamePrefix --from-backup $backupName --include-resources CustomResourceDefinition --include-cluster-resources=true -l $monitoringRestoreLabelKey=$monitoringRestoreLabelValue"
    $(echo $sloAndSythenticCrdRestoreCommand)
    # Wait for restore completion
    waitTillRestoreCompletion "$sloAndSythenticCrdRestoreNamePrefix"
    fi
   done

   # Restore the required monitoring secret
   for i in {0..1}
   do
    monitoringSecretRestoreNamePrefix=$monitoringSecretRestoreNamePrefix-$(date '+%Y%m%d%H%M%S')
    if [ "$i" == "0" ] || [[ "$restoreStatus" == 'PartiallyFailed' ]]; then
    printRestoreStatus
    monitoringSecretRestoreCommand="velero restore create $monitoringSecretRestoreNamePrefix --from-backup $backupName --include-resources Secret --include-namespaces management-monitoring"
    $(echo $monitoringSecretRestoreCommand)
    # Wait for restore completion
    waitTillRestoreCompletion "$monitoringSecretRestoreNamePrefix"
    fi
   done

   # Deleteing the unwanted secrets
   oc delete secret observability-server-ca-certs rhacm-observability-read-cert rhacm-observability-tenant-id rhacm-observability-write-cert -n management-monitoring

   # Restore other required monitoring resources
   for i in {0..1}
   do
    monitoringRestoreNamePrefix=$monitoringRestoreNamePrefix-$(date '+%Y%m%d%H%M%S')
    if [ "$i" == "0" ] || [[ "$restoreStatus" == 'PartiallyFailed' ]]; then
    printRestoreStatus
    monitoringRestoreCommand="velero restore create $monitoringRestoreNamePrefix --from-backup $backupName --include-namespaces management-monitoring,bookinfo-project-think -l $monitoringRestoreLabelKey=$monitoringRestoreLabelValue"
    $(echo $monitoringRestoreCommand)
    # Wait for restore completion
    waitTillRestoreCompletion "$monitoringRestoreNamePrefix"
    fi
   done

   # Deleting all Monitoring Pods
   kubectl delete pod --all -n management-monitoring
}

case "$1" in
    -h|--help)
      echo "options:"
      echo "-h, --help                show brief help"
      echo "-c, --cs-restore          option to restore IBM Common Services"
      echo "-g, --grc-restore         option to restore GRC"
      echo "-vama, --vama-restore     option to restore IBM Management Mutation Advisor and IBM Management Vulnerability Advisor"
      echo "-im, --im-restore         option to restore Infrastructure Management"
      echo "-mservices, --mservices-restore   option to restore MangedServices"
      echo "-o, --openldap-restore    option to restore Openldap"
      echo "-monitoring, --monitoring-restore    option to restore Monitoring"
      echo "-a, --all-restore         option to restore all components"
      exit 0
      ;;
    -c | --cs-restore) echo "Starting cs restore" | tee -a "$log_file"
    csRestore
    ;;
    -g | --grc-restore) echo "Starting GRC restore" | tee -a "$log_file"
    grcRestore
    ;;
    -vama | --vama-restore) echo "Starting VA&MA restore" | tee -a "$log_file"
    vaMaRestore
    ;;
    -im | --im-restore) echo "Starting IM restore" | tee -a "$log_file"
    imRestore
    ;;
    -mservices | --mservices-restore) echo "Starting CAM restore" | tee -a "$log_file"
    camRestore
    ;;
    -o | --openldap-restore) echo "Starting openldap restore" | tee -a "$log_file"
    openLdapRestore
    ;;
    -monitoring | --monitoring-restore) echo "Starting monitoring restore" | tee -a "$log_file"
    monitoringRestore
    ;;
    -a | --all-restore) echo "Starting CS, GRC, VA\MA and CAM restore" | tee -a "$log_file"

    echo "Checking backup exists or not" | tee -a "$log_file"
    checkBackup "$backupName"

    echo "Starting cs restore" | tee -a "$log_file"
    csRestore

    echo "Starting Monitoring restore" | tee -a "$log_file"
    monitoringRestore

    echo "Starting GRC restore" | tee -a "$log_file"
    grcRestore

    echo "Starting VA&MA restore" | tee -a "$log_file"
    vaMaRestore

    echo "Starting CAM restore" | tee -a "$log_file"
    camRestore
    ;;
    *) echo "Run the script with valid option, to get the list of available options run the script with -h option" | tee -a "$log_file"
      break
      ;;
  esac