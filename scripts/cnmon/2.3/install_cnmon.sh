#!/bin/bash

gitrepo=https://raw.githubusercontent.com/IBM/cp4mcm-samples/master/scripts/cnmon/2.3

wget $gitrepo/operator.yaml
wget $gitrepo/role.yaml
wget $gitrepo/role_binding.yaml
wget $gitrepo/service_account.yaml
wget $gitrepo/crds/monitoring.management.ibm.com_agentdeploys_crd.yaml
wget $gitrepo/crds/monitoring.management.ibm.com_remoteagentdeploys_crd.yaml
wget $gitrepo/crds/monitoring.management.ibm.com_uapluginrepo_crd.yaml
wget $gitrepo/crds/monitoring.management.ibm.com_agentdeploys_crd_v1beta1.yaml
wget $gitrepo/crds/monitoring.management.ibm.com_remoteagentdeploys_crd_v1beta1.yaml
wget $gitrepo/crds/monitoring.management.ibm.com_uapluginrepo_crd_v1beta1.yaml

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
cp operator.yaml operator_cnmon.yaml
BETA1=`kubectl api-versions | grep "apiextensions.k8s.io/v1beta1"`
if [ -n "${BETA1}"  ]
then
  kubectl create -f monitoring.management.ibm.com_agentdeploys_crd_v1beta1.yaml
  kubectl create -f monitoring.management.ibm.com_remoteagentdeploys_crd_v1beta1.yaml
  kubectl create -f monitoring.management.ibm.com_uapluginrepo_crd_v1beta1.yaml
else
  sed -i 's/beta\.kubernetes\.io/kubernetes\.io/g' operator_cnmon.yaml
  kubectl create -f monitoring.management.ibm.com_agentdeploys_crd.yaml
  kubectl create -f monitoring.management.ibm.com_remoteagentdeploys_crd.yaml
  kubectl create -f monitoring.management.ibm.com_uapluginrepo_crd.yaml
fi
kubectl create -f operator_cnmon.yaml -n $namespace
