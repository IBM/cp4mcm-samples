#!/bin/bash

#--------------------------------------------------------------------------
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corporation 2019.
#
# US Government Users Restricted Rights - Use, duplication or disclosure
# restricted by GSA ADP Schedule Contract with IBM Corporation.
#--------------------------------------------------------------------------

#!/bin/bash

#Reading S3 Bucket configuration details
ACCESS_KEY_ID=$(cat install-velero-config.json | jq -r '.access_key_id')
SECRET_ACCESS_KEY=$(cat install-velero-config.json | jq -r '.secret_access_key') 
BUCKET_NAME=$(cat install-velero-config.json | jq -r '.bucket_name') 
BUCKET_URL=$(cat install-velero-config.json | jq -r '.bucket_url') 
BUCKET_REGION=$(cat install-velero-config.json | jq -r '.bucket_region')
VELERO_HELM_CHART_URL=$(cat install-velero-config.json | jq -r '.velero_helm_chart_url')
VELERO_HELM_CHART_VERSION=$(cat install-velero-config.json | jq -r '.velero_helm_chart_version')

# Waits for a specific time, Requires one positional argument "timeout"
wait(){
   timeout=$1
   i=0
   while [ $i -ne $timeout ]; do
     printf "."
     sleep 1
     i=$((i+1))
   done
}

# Checks pod readyness using pod label, Requires 3 positional arguments "namespace", "podLabel" and "retryCount" 
checkPodReadyness(){
   namespace=$1
   podLabel=$2
   retryCount=$3
   counter=0
   pods=$(oc -n $namespace get pods -l $podLabel --no-headers | grep -F "1/1" -v)

   while [ "${pods}" ]; do
     wait "5"
     echo "Waiting for Pods to be READY"
     pods=$(oc -n $namespace get pods -l $podLabel --no-headers | grep -F "1/1" -v)
     ((counter++))
     if [[ $counter -eq $retryCount ]]; then
        echo "Pods in $namespace namespace are not READY hence terminating the restore process" | tee -a "$log_file"
        exit 1
     fi
   done
}


# Installs Velero on OpenShift/Kubernetes cluster
installVelero() {

   # Preparing the bucket credential file
   rm -f bucket-creds
   echo "[default]" >> bucket-creds
   echo "aws_access_key_id="$ACCESS_KEY_ID >> bucket-creds
   echo "aws_secret_access_key="$SECRET_ACCESS_KEY >> bucket-creds

   # Adding velero helm repo
   helm repo add vmware-tanzu $VELERO_HELM_CHART_URL

   # Creating velero project
   oc new-project velero

   # Installing velero
   helm install velero --namespace velero --version $VELERO_HELM_CHART_VERSION \
   --set configuration.provider=aws \
   --set-file credentials.secretContents.cloud=./bucket-creds \
   --set use-volume-snapshots=false \
   --set deployRestic=true \
   --set restic.privileged=true \
   --set backupsEnabled=true \
   --set snapshotsEnabled=false \
   --set configuration.backupStorageLocation.name=default \
   --set configuration.backupStorageLocation.bucket=$BUCKET_NAME \
   --set configuration.backupStorageLocation.config.region=$BUCKET_REGION \
   --set configuration.backupStorageLocation.config.s3ForcePathStyle=true \
   --set configuration.backupStorageLocation.config.s3Url=$BUCKET_URL \
   --set image.repository=velero/velero \
   --set image.pullPolicy=IfNotPresent \
   --set initContainers[0].name=velero-plugin-for-aws \
   --set initContainers[0].image=velero/velero-plugin-for-aws:v1.0.0 \
   --set initContainers[0].volumeMounts[0].mountPath=/target \
   --set initContainers[0].volumeMounts[0].name=plugins \
   vmware-tanzu/velero

   rm -f bucket-creds

   checkPodReadyness "velero" "app.kubernetes.io/name=velero" "25"
}

installVelero