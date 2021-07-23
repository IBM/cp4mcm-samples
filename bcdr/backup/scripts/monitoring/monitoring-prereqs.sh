#!/bin/bash

#--------------------------------------------------------------------------
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corporation 2019.
#
# US Government Users Restricted Rights - Use, duplication or disclosure
# restricted by GSA ADP Schedule Contract with IBM Corporation.
#--------------------------------------------------------------------------

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
JSON='{"M_LAYOUT_RC": '"$M_LAYOUT_RC"', "M_UIAPI_RC": '"$M_UIAPI_RC"', "M_TOPOLOGY_RC": '"$M_TOPOLOGY_RC"', "M_ELASTICS_RC": '"$M_ELASTICS_RC"' }'
echo $JSON > /workdir/monitoring-rc-data.json

#Scaling down the required pods
kubectl scale deploy monitoring-layout --replicas=0 -n management-monitoring
kubectl scale deploy monitoring-ui-api --replicas=0 -n management-monitoring
kubectl scale deploy monitoring-topology --replicas=0 -n management-monitoring
kubectl scale sts monitoring-elasticsearch --replicas=0 -n management-monitoring






