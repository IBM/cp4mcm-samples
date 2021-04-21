#!/bin/bash

gitrepo=https://raw.githubusercontent.com/IBM/cp4mcm-samples/master/scripts/cnmon/2.3

wget $gitrepo/operator.yaml
wget $gitrepo/role.yaml
wget $gitrepo/role_binding.yaml
wget $gitrepo/service_account.yaml
wget $gitrepo/crds/monitoring.management.ibm.com_agentdeploys_crd.yaml
wget $gitrepo/crds/monitoring.management.ibm.com_remoteagentdeploys_crd.yaml
wget $gitrepo/crds/monitoring.management.ibm.com_uapluginrepo_crd.yaml

namespace=cp4mcm-cloud-native-monitoring
if [ ! -z $1 ]
then
  namespace=$1
fi

nscnt=$(kubectl get ns $namespace --no-headers=true --ignore-not-found=true | wc -l)
if [ $nscnt -eq 0 ]
then
  kubectl create namespace $namespace
fi

kubectl create -f service_account.yaml -n $namespace
kubectl create -f role.yaml
cp role_binding.yaml role_binding_cnmon.yaml
sed -i 's/REPLACE_NAMESPACE/'"$namespace"'/g' role_binding_cnmon.yaml
kubectl create -f role_binding_cnmon.yaml
kubectl create -f monitoring.management.ibm.com_agentdeploys_crd.yaml
kubectl create -f monitoring.management.ibm.com_remoteagentdeploys_crd.yaml
kubectl create -f monitoring.management.ibm.com_uapluginrepo_crd.yaml
cp operator.yaml operator_cnmon.yaml
sed -i 's/cp.icr.io\/cp/'"$LOCAL_DOCKER_REGISTRY"'/g' operator_cnmon.yaml
kubectl create -f operator_cnmon.yaml -n $namespace
