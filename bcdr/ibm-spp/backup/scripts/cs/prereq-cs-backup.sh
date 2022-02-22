#!/bin/bash

BASEDIR=$(dirname "$0")

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

# Wait till deletion of resource
waitTillDeletionComplete(){
   namespace=$1
   resourceLabel=$2
   retryCount=$3
   resourceType=$4
   counter=0

   resourceCount=$(oc get $resourceType -l $resourceLabel -n $namespace --no-headers | wc -l)
   echo Resource count: $resourceCount

   while [ $resourceCount -ne 0 ]; do
      wait "5"
      echo "Waiting for resource to be Deleted"

      resourceCount=$(oc get $resourceType -l $resourceLabel -n $namespace --no-headers | wc -l)
      echo Resource count: $resourceCount

      counter=$((counter+1))
      echo Counter: $counter, RetryCount: $retryCount

      if [ $counter -eq $retryCount ]; then
         echo "Exiting from waitTillDeletionComplete function as retryCount threshold achieved"
         break
      fi
   done

}

# Applying Cluster Image Policy for MongoDB & Nginx
kubectl apply -f $BASEDIR/mongo-image-policy.yaml

# Deleting old mongo dump related resources
kubectl delete -f $BASEDIR/mongodb-dump.yaml
waitTillDeletionComplete "ibm-common-services" "name=my-mongodump" "4" "pvc"
pvcCount=$(oc get pvc -l name=my-mongodump -n ibm-common-services --no-headers | wc -l)
if [ $pvcCount -ne 0 ]; then
   oc delete pvc -l name=my-mongodump -n ibm-common-services --force
   waitTillDeletionComplete "ibm-common-services" "name=my-mongodump" "4" "pvc"
fi

# Creating new mongo dump
kubectl apply -f $BASEDIR/mongodb-dump.yaml
checkResourceReadyness "ibm-common-services" "job-name=icp-mongodb-backup" "30" "job"

# Tagging all required common services resources
oc label pvc my-mongodump  appbackup=cs backup=cp4mcm  --overwrite=true -n ibm-common-services
oc label pvc alertmanager-ibm-monitoring-alertmanager-db-alertmanager-ibm-monitoring-alertmanager-0 appbackup=cs backup=cp4mcm  --overwrite=true -n ibm-common-services
oc label pvc prometheus-ibm-monitoring-prometheus-db-prometheus-ibm-monitoring-prometheus-0  appbackup=cs backup=cp4mcm  --overwrite=true -n ibm-common-services


oc label secret icp-mongodb-admin  appbackup=cs backup=cp4mcm  --overwrite=true -n ibm-common-services
oc label secret icp-serviceid-apikey-secret appbackup=cs backup=cp4mcm --overwrite=true -n ibm-common-services

