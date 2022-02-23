#!/bin/bash

BASEDIR=$(dirname "$0")

# Deleting old monitoring-rc-data.json data file if it's there
rm -f $BASEDIR/monitoring-rc-data.json

# Tagging all required monitoring resources
oc label crd slobundles.declarativemonitoring.management.ibm.com appbackup=monitoring backup=cp4mcm --overwrite=true
oc label crd syntheticbundles.declarativemonitoring.management.ibm.com appbackup=monitoring backup=cp4mcm --overwrite=true


oc label pvc data-monitoring-cassandra-0  appbackup=monitoring backup=cp4mcm --overwrite=true -n management-monitoring
oc label pvc data-monitoring-couchdb-0  appbackup=monitoring backup=cp4mcm --overwrite=true -n management-monitoring
oc label pvc jobs-monitoring-ibm-cem-datalayer-0  appbackup=monitoring backup=cp4mcm --overwrite=true -n management-monitoring
oc label pvc data-monitoring-kafka-0   appbackup=monitoring backup=cp4mcm --overwrite=true -n management-monitoring
oc label pvc data-monitoring-zookeeper-0  appbackup=monitoring backup=cp4mcm --overwrite=true -n management-monitoring
 
 
oc label cm monitoring-couchdb-configmap appbackup=monitoring backup=cp4mcm --overwrite=true -n management-monitoring
oc label cm monitoring-kafka appbackup=monitoring backup=cp4mcm --overwrite=true -n management-monitoring
oc label cm monitoring-zookeeper appbackup=monitoring backup=cp4mcm --overwrite=true -n management-monitoring

oc label svc monitoring-kafka appbackup=monitoring backup=cp4mcm --overwrite=true -n management-monitoring

oc label secret --all appbackup=monitoring backup=cp4mcm --overwrite=true -n management-monitoring
oc label secret observability-server-ca-certs appbackup- backup- --overwrite=true -n management-monitoring
oc label secret rhacm-observability-read-cert appbackup- backup- --overwrite=true -n management-monitoring
oc label secret rhacm-observability-tenant-id appbackup- backup- --overwrite=true -n management-monitoring
oc label secret rhacm-observability-write-cert appbackup- backup- --overwrite=true -n management-monitoring


#Getting the replica count before scaling down the required pods
M_LAYOUT_RC=$(kubectl get deployments monitoring-layout -n management-monitoring -o=jsonpath='{.spec.replicas}')
M_UIAPI_RC=$(kubectl get  deployments monitoring-ui-api -n management-monitoring -o=jsonpath='{.spec.replicas}')
M_TOPOLOGY_RC=$(kubectl get  deployments monitoring-topology -n management-monitoring -o=jsonpath='{.spec.replicas}')
M_ELASTICS_RC=$(kubectl get sts  monitoring-elasticsearch -n management-monitoring -o=jsonpath='{.spec.replicas}')

echo Before scaling down monitoring-layout deployment replica count is $M_LAYOUT_RC
echo Before scaling down monitoring-ui-api deployment replica count is $M_UIAPI_RC
echo Before scaling down monitoring-topology deployment replica count is $M_TOPOLOGY_RC
echo Before scaling down monitoring-elasticsearch statefulset replica count is $M_ELASTICS_RC

#Saving the replica count values to a json file as it's required for monitoring-post-backup-task script
JSON='{"monitoring-layout": '"$M_LAYOUT_RC"', "monitoring-ui-api": '"$M_UIAPI_RC"', "monitoring-topology": '"$M_TOPOLOGY_RC"', "monitoring-elasticsearch": '"$M_ELASTICS_RC"' }'
echo $JSON > $BASEDIR/monitoring-rc-data.json

#Scaling down the required pods
kubectl scale deploy monitoring-layout --replicas=0 -n management-monitoring
kubectl scale deploy monitoring-ui-api --replicas=0 -n management-monitoring
kubectl scale deploy monitoring-topology --replicas=0 -n management-monitoring
kubectl scale sts monitoring-elasticsearch --replicas=0 -n management-monitoring

