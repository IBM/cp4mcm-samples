#!/bin/bash

#--------------------------------------------------------------------------
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corporation 2019.
#
# US Government Users Restricted Rights - Use, duplication or disclosure
# restricted by GSA ADP Schedule Contract with IBM Corporation.
#--------------------------------------------------------------------------

BASEDIR=$(dirname "$0")
DUMMY_DB_FILE_PATH=$BASEDIR/dummy-db.yaml

# Function to wait for a specific time, it requires one positional argument i.e timeout
wait() {
   timeout=$1
   i=0
   while [ $i -ne $timeout ]; do
      printf "."
      sleep 1
      i=$((i+1))
   done
}

# Function to check resource readyness, it requires 4 positional arguments such as namespace, jobLabel, retryCount and resourceType
checkResourceReadyness() {
   namespace=$1
   resourceLabel=$2
   retryCount=$3
   resourceType=$4
   counter=0
   resources=$(kubectl -n $namespace get $resourceType -l $resourceLabel --no-headers | grep -F "1/1" -v)
   echo Resources: $resources

   while [ "${resources}" ]; do
      wait "5"
      echo "Waiting for resource to be READY"

      resources=$(kubectl -n $namespace get $resourceType -l $resourceLabel --no-headers | grep -F "1/1" -v)
      echo Resources: $resources

      counter=$((counter+1))
      echo Counter: $counter, RetryCount: $retryCount

      if [ $counter -eq $retryCount ]; then
         echo "$resources are not ready"
         break
      fi
   done
}

# Updates the DUMMY_DB_FILE_PATH only if environment is air gap
updateDummyDBFilePath() {
   if [ "$AIR_GAP" = "true" ]; then
      DUMMY_DB_FILE_PATH=$BASEDIR/dummy-db-airgap.yaml
      echo "Updated dummy db file path to $DUMMY_DB_FILE_PATH as value of env variable AIR_GAP is $AIR_GAP"
   else
      echo "Not updating dummy db file path $DUMMY_DB_FILE_PATH as value of env variable AIR_GAP is $AIR_GAP"
   fi
}

# Wait till deletion of resource
waitTillDeletionComplete(){
   namespace=$1
   resourceLabel=$2
   retryCount=$3
   resourceType=$4
   counter=0

   resourceCount=$(kubectl get $resourceType -l $resourceLabel -n $namespace --no-headers | wc -l)
   echo Resource count: $resourceCount, Resource type: $resourceType, Resource label: $resourceLabel

   while [ $resourceCount -ne 0 ]; do
      wait "5"
      echo "Waiting for resource to be Deleted"

      resourceCount=$(kubectl get $resourceType -l $resourceLabel -n $namespace --no-headers | wc -l)
      echo Resource count: $resourceCount

      counter=$((counter+1))
      echo Counter: $counter, RetryCount: $retryCount

      if [ $counter -eq $retryCount ]; then
         echo "Exiting from waitTillDeletionComplete function as retryCount threshold achieved"
         break
      fi
   done

}

# Check and update the dummy db file path
updateDummyDBFilePath

# Applying Cluster Image Policy for MongoDB & Nginx
kubectl apply -f $BASEDIR/mongo-image-policy.yaml
kubectl apply -f $BASEDIR/nginx-image-policy.yaml

kubectl delete -f $DUMMY_DB_FILE_PATH
waitTillDeletionComplete "ibm-common-services" "app=dummy-db" "4" "pod"
kubectl delete -f $BASEDIR/mongodb-dump.yaml
waitTillDeletionComplete "ibm-common-services" "name=my-mongodump" "4" "pvc"
pvcCount=$(kubectl get pvc -l name=my-mongodump -n ibm-common-services --no-headers | wc -l)
if [ $pvcCount -ne 0 ]; then
   kubectl delete pvc -l name=my-mongodump -n ibm-common-services --force
   waitTillDeletionComplete "ibm-common-services" "name=my-mongodump" "4" "pvc"
fi
kubectl apply -f $BASEDIR/mongodb-dump.yaml
checkResourceReadyness "ibm-common-services" "job-name=icp-mongodb-backup" "30" "job"

kubectl apply -f $DUMMY_DB_FILE_PATH
checkResourceReadyness "ibm-common-services" "app=dummy-db" "20" "pod"