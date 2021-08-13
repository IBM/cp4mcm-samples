#!/bin/bash  

#--------------------------------------------------------------------------
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corporation 2019.
#
# US Government Users Restricted Rights - Use, duplication or disclosure
# restricted by GSA ADP Schedule Contract with IBM Corporation.
#--------------------------------------------------------------------------

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

# Trigger Backup
TriggerBackup

