#!/bin/bash

#--------------------------------------------------------------------------
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corporation 2019.
#
# US Government Users Restricted Rights - Use, duplication or disclosure
# restricted by GSA ADP Schedule Contract with IBM Corporation.
#--------------------------------------------------------------------------

backupName=$(grep -w name /workdir/backup.yaml | cut -d " " -f 4)

# Function to wait for a specific time, it requires one positional argument i.e timeout
wait(){
   timeout=$1
   i=0
   while [ $i -ne $timeout ]; do
     printf "."
     sleep 1
     i=$((i+1))
   done
}

# This function is to check the backup status periodically till it's completion, it accepts one positional argument i.e backupName
waitTillBackupCompletion(){
   backupName=$1
   echo Waiting for backup $backupName to complete
   wait "10"
   backupStatus=$(velero describe backup $backupName --details | grep Phase | cut -d " " -f 3)
   echo Backup $backupName status is $backupStatus
   
   while [ "$backupStatus" == "InProgress" ] || [ "$backupStatus" == "New" ]
   do
     echo "Wating for 1 min"
     wait "60"
     backupStatus=$(velero describe backup $backupName --details | grep Phase | cut -d " " -f 3)
     echo Velero Backup status is: $backupStatus
   done
}

waitTillBackupCompletion "$backupName"

M_LAYOUT_RC=$(cat /workdir/monitoring-rc-data.json | jq '.M_LAYOUT_RC')
echo Scaling up replica count of deployment monitoring-layout to $M_LAYOUT_RC
M_UIAPI_RC=$(cat /workdir/monitoring-rc-data.json | jq '.M_UIAPI_RC')
echo Scaling up replica count of deployment monitoring-ui-api to $M_UIAPI_RC
M_TOPOLOGY_RC=$(cat /workdir/monitoring-rc-data.json | jq '.M_TOPOLOGY_RC')
echo Scaling up replica count of deployment monitoring-topology to $M_TOPOLOGY_RC
M_ELASTICS_RC=$(cat /workdir/monitoring-rc-data.json | jq '.M_ELASTICS_RC')
echo Scaling up replica count of statefulset monitoring-elasticsearch to $M_ELASTICS_RC

kubectl scale deploy monitoring-layout --replicas=$M_LAYOUT_RC -n management-monitoring
kubectl scale deploy monitoring-ui-api --replicas=$M_UIAPI_RC -n management-monitoring
kubectl scale deploy monitoring-topology --replicas=$M_TOPOLOGY_RC -n management-monitoring
kubectl scale sts monitoring-elasticsearch --replicas=$M_ELASTICS_RC -n management-monitoring

$(rm -f /workdir/monitoring-rc-data.json)