#!/bin/bash

#--------------------------------------------------------------------------
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corporation 2019.
#
# US Government Users Restricted Rights - Use, duplication or disclosure
# restricted by GSA ADP Schedule Contract with IBM Corporation.
#--------------------------------------------------------------------------

#Reading S3 Bucket configuration details
ACCESS_KEY_ID=$(cat install-velero-on-airgap-config.json | jq -r '.access_key_id')
SECRET_ACCESS_KEY=$(cat install-velero-on-airgap-config.json | jq -r '.secret_access_key') 
BUCKET_NAME=$(cat install-velero-on-airgap-config.json | jq -r '.bucket_name') 
BUCKET_URL=$(cat install-velero-on-airgap-config.json | jq -r '.bucket_url') 
BUCKET_REGION=$(cat install-velero-on-airgap-config.json | jq -r '.bucket_region')

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
     wait "10"
     echo "Waiting for Pods to be READY"
     pods=$(oc -n $namespace get pods -l $podLabel --no-headers | grep -F "1/1" -v)
     counter=$((counter+1))
     if [ $counter -eq $retryCount ]; then
        echo "Pods in $namespace namespace are not READY hence terminating the restore process"
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

   # Creating velero project
   oc new-project velero

   # Installing velero
   helm install velero --namespace velero \
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
   --set image.repository=localhost/velero/velero \
   --set image.pullPolicy=Never \
   --set initContainers[0].name=velero-plugin-for-aws \
   --set initContainers[0].image=localhost/velero/velero-plugin-for-aws:v1.0.0 \
   --set initContainers[0].volumeMounts[0].mountPath=/target \
   --set initContainers[0].volumeMounts[0].name=plugins \
   --set initContainers[0].imagePullPolicy=Never \
   --set configMaps.restic-restore-action-config.data.image=localhost/velero/velero-restic-restore-helper:v1.5.3 \
   velero-2.14.7.tgz

   checkPodReadyness "velero" "app.kubernetes.io/name=velero" "30"

   echo "Velero installed successfully."
   
   # Deleting credential file
   rm -f bucket-creds

   # Adding required label to velero-restic-restore-action-config ConfigMap
   oc label cm velero-restic-restore-action-config -n velero velero.io/plugin-config=""
   oc label cm velero-restic-restore-action-config -n velero velero.io/restic=RestoreItemAction
}

installVelero