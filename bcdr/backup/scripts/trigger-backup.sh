#!/bin/bash  

#--------------------------------------------------------------------------
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corporation 2019.
#
# US Government Users Restricted Rights - Use, duplication or disclosure
# restricted by GSA ADP Schedule Contract with IBM Corporation.
#--------------------------------------------------------------------------

source utils.sh

V_FALSE=FALSE

RemoveAnnotationFromPVC() {
  # Defining variables  
  mappings=$(cat config.json)  
  length=$(echo $mappings | jq '. | length') 
  index=0

  # Iterating over JSON
  while [ $index -lt $length ]
  do
    # Computing Namespace & PersistentVolumeClaim
    namespace=$(echo $mappings | jq -r --arg index $index '.[$index | tonumber].namespace')
    persistentVolumeClaims=$(echo $mappings | jq -r --arg index $index '.[$index | tonumber].persistantVolumeClaims' | jq -r .[])

    # Check if namespace is enabled or not
    isNamespaceEnabled=$(IsNamespaceEnabled $namespace)
    if [ "$isNamespaceEnabled" = "$V_FALSE" ]; then
      # Incrementing Index
      index=$((index+1))
      
      echo Namespace [$namespace] is not enabled, hence skipping removing annotation from Persistent Volume Claims $persistentVolumeClaims
      continue
    else
      echo Namespace [$namespace] is enabled, hence proceeding further for removing annotation from Persistent Volume Claims $persistentVolumeClaims    
    fi

    # Logging Index & Namespace 
    echo "Looping over index: $index"
    echo "Namespace: $namespace"

    for pvc in $persistentVolumeClaims
    do
      # Logging PersistentVolumeClaim 
      echo "PersistentVolumeClaim: $pvc"
      command="kubectl -n $namespace annotate pvc $pvc ibm.io/provisioning-status- --overwrite=true"
      echo $command
      
      # Execute command
      { 
        # TRY
        $(echo $command)
      } || {
        # CATCH
        echo "Error occured, Hence retrying once"
        $(echo $command)
      }

      # Sleep for some time
      sleep 1s
    done
 
  # Incrementing Index
  index=$((index+1))
  done
}

TriggerBackup() {
  # Copy and Rename backup file
  cp backup_original.yaml /workdir/backup.yaml

  # Generate unique name
  BACKUP_NAME=$(echo "cp4mcm-backup-$(date +%s)")

  # Replace BACKUP-NAME with unique name
  sed -i 's/BACKUP-NAME/'$(echo $BACKUP_NAME)'/' /workdir/backup.yaml
  
  # Execute command
  kubectl apply -f /workdir/backup.yaml
}

# Step 1 - Remove annotation from PVC
RemoveAnnotationFromPVC

# Step 2 - Trigger Backup
TriggerBackup

