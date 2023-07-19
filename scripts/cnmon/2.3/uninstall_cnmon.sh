#!/bin/bash

namespace=cp4mcm-cloud-native-monitoring
if [ ! -z $1 ]
then
  namespace=$1
fi

kubectl cluster-info
if [ ! $? -eq 0 ]
then
  echo "Log in to the cluster and rerun the script."
  exit 1
fi

mcmcore_ns=multicluster-endpoint
rhacm_ns=open-cluster-management-agent-addon

mcmnscnt=$(kubectl get ns $mcmcore_ns --no-headers=true --ignore-not-found=true | wc -l)
rhacmnscnt=$(kubectl get ns $rhacm_ns --no-headers=true --ignore-not-found=true | wc -l)

if [ $mcmnscnt -eq 0 -a $rhacmnscnt -eq 0 ]
then
  echo "This cluster is not currently managed by IBM Cloud Pak® for Multicloud Management hub cluster."
  echo "Do you want to continue [ y or n; \"n\" is default ]?"
  read REPLY
  case $REPLY in
    y*|Y*) ;;

    *) exit 0
    ;;
  esac
fi

if [ $mcmnscnt -gt 0 -o $rhacmnscnt -gt 0 ]
then
  if [ $mcmnscnt -gt 0 ]
  then
    mcm_ns=$mcmcore_ns
    secret_name=klusterlet-bootstrap
    helmrelgrp=app.ibm.com
  else
    mcm_ns=$rhacm_ns
    secret_name=workmgr-hub-kubeconfig
    helmrelgrp=apps.open-cluster-management.io
  fi
  server_url=$(kubectl get secret $secret_name --ignore-not-found=true -n $mcm_ns -o yaml | grep '  kubeconfig' | awk '{ print $2 }' | base64 -d | grep '    server' | awk '{ print $2 }')
fi

echo ""
echo "Uninstall Cloud Native Monitoring from namespace $namespace..."
echo ""
if [ $mcmnscnt -gt 0 -o $rhacmnscnt -gt 0 ]
then
  echo "If you deployed Cloud Native Monitoring using remote agent deployment feature,"
  echo "ensure that you have changed the label to ibm.com/cloud-native-monitoring: \"disabled\""
  echo "at IBM Cloud Pak® for Multicloud Management hub cluster $server_url"
  echo "for this managed cluster"

  echo "Do you want to continue [ y or n; \"n\" is default ]?"
  read REPLY
  case $REPLY in
    y*|Y*) ;;

    *) exit 0
    ;;
  esac
fi

echo ""
echo "Do you want to delete UA custom resources [ y or n; \"n\" is default ]?"
read REPLY
case $REPLY in
  y*|Y*) 
    keep_uacr=false
    ;;

  *) 
    keep_uacr=true
    ;;
esac

echo ""
echo "Deleting namespaced resources..."

nscnt=$(kubectl get ns $namespace --no-headers=true --ignore-not-found=true | wc -l)
if [ $nscnt -eq 0 ]
then
  echo "No namespace $namespace"
else
  if [ $keep_uacr = false ]
  then
    echo "Search and delete ua..."
    uascrd=$(kubectl api-resources --api-group='ua.ibm.com' --no-headers=true | grep uas)
    if [ ! -z "$uascrd" ]
    then
      ua=$(kubectl get uas.ua.ibm.com -n $namespace --no-headers=true --ignore-not-found=true | grep "ua-" | awk '{print $1}')
      if [ -z "$ua" ]
      then
        echo "No ua found."
      else
        kubectl delete uas.ua.ibm.com -n $namespace $ua
      fi
    fi
  else
    echo "Search and delete ua-mgmt..."
    uascrd=$(kubectl api-resources --api-group='ua.ibm.com' --no-headers=true | grep uas)
    if [ ! -z "$uascrd" ]
    then
      uamgmt=$(kubectl get uas.ua.ibm.com ua-mgmt -n $namespace --no-headers=true --ignore-not-found=true | grep "ua-" | awk '{print $1}')
      if [ -z "$uamgmt" ]
      then
        echo "No ua-mgmt found."
      else
        kubectl delete uas.ua.ibm.com -n $namespace $uamgmt
      fi
    fi
  fi
  
  echo "Search and delete k8sdc..."
  k8sdccr=$(kubectl api-resources --api-group='ibmcloudappmgmt.com' --no-headers=true | grep k8sdcs)
  if [ ! -z "$k8sdccr" ]
  then
    k8sdc=$(kubectl get K8sDC -n $namespace --no-headers=true --ignore-not-found=true | awk '{print $1}')
    if [ -z "$k8sdc" ]
    then
      echo "No k8sdc found."
    else
      kubectl patch K8sDC k8sdc-cr -p '{"metadata":{"finalizers":[]}}' --type merge -n $namespace
      k8sdc1=$(kubectl get K8sDC -n $namespace --no-headers=true --ignore-not-found=true | awk '{print $1}')
      if [ ! -z "$k8sdc1" ]
      then
        kubectl delete k8sDC k8sdc-cr -n $namespace
      fi
    fi
  fi

  echo "Search and delete agentdeploy..."
  adcr=$(kubectl api-resources --api-group='monitoring.management.ibm.com' --no-headers=true | grep agentdeploys)
  if [ ! -z "$adcr" ]
  then
    ad=$(kubectl get AgentDeploy -n $namespace --no-headers=true --ignore-not-found=true | awk '{print $1}')
    if [ -z "$ad" ]
    then
      echo "No agentdeploy found."
    else
      kubectl patch AgentDeploy $ad -p '{"metadata":{"finalizers":[]}}' --type merge -n $namespace
      ad1=$(kubectl get AgentDeploy -n $namespace --no-headers=true --ignore-not-found=true | awk '{print $1}')
      if [ ! -z "$ad1" ]
      then
        kubectl delete AgentDeploy $ad1 -n $namespace
      fi
    fi
  fi

  echo "Search and delete remoteagentdeploy..."
  radcr=$(kubectl api-resources --api-group='monitoring.management.ibm.com' --no-headers=true | grep remoteagentdeploys)
  if [ ! -z "$radcr" ]
  then
    rad=$(kubectl get RemoteAgentDeploy -n $namespace --no-headers=true --ignore-not-found=true | awk '{print $1}')
    if [ -z "$rad" ]
    then
      echo "No remoteagentdeploy found."
    else
      kubectl patch RemoteAgentDeploy $rad -p '{"metadata":{"finalizers":[]}}' --type merge -n $namespace
      rad1=$(kubectl get RemoteAgentDeploy -n $namespace --no-headers=true --ignore-not-found=true | awk '{print $1}')
      if [ ! -z "$rad1" ]
      then
        kubectl delete RemoteAgentDeploy $rad1 -n $namespace
      fi
    fi
  fi

  echo "Search and delete uapluginrepo..."
  uarepocr=$(kubectl api-resources --api-group='monitoring.management.ibm.com' --no-headers=true | grep uapluginrepos)
  if [ ! -z "$uarepocr" ]
  then
    uarepo=$(kubectl get uapluginrepo -n $namespace --no-headers=true --ignore-not-found=true | awk '{print $1}')
    if [ -z "$uarepo" ]
    then
      echo "No uapluginrepo found."
    else
      kubectl patch uapluginrepo $uarepo -p '{"metadata":{"finalizers":[]}}' --type merge -n $namespace
      uarepo1=$(kubectl get uapluginrepo -n $namespace --no-headers=true --ignore-not-found=true | awk '{print $1}')
      if [ ! -z "$uarepo1" ]
      then
        kubectl delete uapluginrepo $uarepo1 -n $namespace
      fi
    fi
  fi

  echo "Deleting ibm-monitoring-dataprovider-mgmt-operator resources"
  kubectl delete deploy ibm-monitoring-dataprovider-mgmt-operator --ignore-not-found=true -n $namespace
  kubectl delete sa ibm-monitoring-dataprovider-mgmt-operator --ignore-not-found=true -n $namespace

  echo "Deleting ibm-dc-autoconfig-operator resources"
  kubectl delete deploy,sa,job,role,rolebinding -l app=ibm-dc-autoconfig-operator -n $namespace

  echo "Deleting reloader resources"
  kubectl delete deploy,sa -l app=reloader -n $namespace

  echo "Deleting k8s resources"
  kubectl delete deploy,sa,role,rolebinding -l app=k8sdc-operator -n $namespace

  echo "Deleting ua resources"
  kubectl delete deploy,sa,service,job,role,rolebinding -l app=ua-operator -n $namespace
  
  echo "Search and delete config map..."
  uacm=$(kubectl get configmap ualk-icam-leader -n $namespace --no-headers=true --ignore-not-found=true | awk '{print $1}')
  if [ -z "$uacm" ]
  then
    echo "No related configmap found."
  else
    kubectl delete configmap $uacm -n $namespace
  fi
  
  echo "Search and delete secret..."
  secrets=(
    dc-secret
    ibm-agent-https-secret
    icam-server-secret
    ua-secrets
  )
  for i in "${secrets[@]}"; do
    kubectl get secret ${i} > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      continue
    fi
    echo "Deleting secret ${i}"
    kubectl delete secret $i -n $namespace
  done
  
  echo "Search and delete k8sdc secret..."
  k8sdcsec=$(kubectl get secret -l name=k8sdc-cr -n $namespace --no-headers=true --ignore-not-found=true | awk '{print $1}')
  if [ -z "$k8sdcsec" ]
  then
    echo "No k8sdc secret found."
  else
    kubectl delete secret $k8sdcsec -n $namespace
  fi
fi

echo ""
echo "Deleting related non-namespaced resources..."

echo "Search and deleting crd..."
crds=(
  k8sdcs.ibmcloudappmgmt.com
  agentdeploys.monitoring.management.ibm.com
  remoteagentdeploys.monitoring.management.ibm.com
  uapluginrepos.monitoring.management.ibm.com
)
for i in "${crds[@]}"; do
  kubectl get crd ${i} > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    continue
  fi
  echo "Deleting crd ${i}"
  kubectl delete crd $i
done

if [ $keep_uacr = false ]
then
  echo ""
  echo "Search and deleting uas crd..."
  crd=$(kubectl get crd uas.ua.ibm.com --no-headers=true --ignore-not-found=true | awk '{print $1}')
  if [ -z "$crd" ]
  then
    echo "No uas crd found."
  else
    kubectl delete crd $crd
  fi
fi

echo "Search and deleting clusterrolebinding..."
clusterrolebinding=(
  node-k8sdc-cr-k8monitor
  view-k8sdc-cr-k8monitor
  ua-operator
  k8sdc-operator
  reloader
  ibm-dc-autoconfig-operator
  ibm-monitoring-dataprovider-mgmt-operator
)
for i in "${clusterrolebinding[@]}"; do
  kubectl get clusterrolebinding ${i} > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    continue
  fi
  echo "Deleting clusterrolebinding ${i}"
  kubectl delete clusterrolebinding $i
done

echo "Search and deleting clusterrole..."
clusterrole=(
  k8sdc-cr-k8monitor
  k8sdc-operator
  ua-operator
  reloader
  ibm-dc-autoconfig-operator
  ibm-monitoring-dataprovider-mgmt-operator
)
for i in "${clusterrole[@]}"; do
  kubectl get clusterrole ${i} > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    continue
  fi
  echo "Deleting clusterrole ${i}"
  kubectl delete clusterrole $i
done

echo ""
if [ ! $nscnt -eq 0 -a $keep_uacr = false -a "$namespace" != "management-monitoring" ]
then
  echo "Deleting namespace $namespace..."
  echo "Running pods in namespace $namespace"
  kubectl get pods -n $namespace
  echo ""

  echo "If you have deployments other than Cloud Native Monitoring installed in namespace $namespace, you must uninstall all of the other deployments before run this script to delete this namespace."
  echo "***** NOTE THAT ALL RESOURCES IN NAMESPACE $namespace WILL BE DELETED!!! *****"
  echo "Do you want to continue [ y or n; \"n\" is default ]?"
  read REPLY
  case $REPLY in
    y*|Y*) ;;

    *) exit 0
    ;;
  esac

  echo "Make sure pods are terminated..."
  i=0
  podcnt=$(kubectl get pods -n $namespace --no-headers=true --ignore-not-found=true | wc -l)
  while [ $podcnt -gt 0 -a $i -lt 18 ]
  do
    echo "Waiting 10 seconds..."
    sleep 10
    podcnt=$(kubectl get pods -n $namespace --no-headers=true --ignore-not-found=true | wc -l)
    i=$((i+1))
  done

  if [ $podcnt -gt 0 ]
  then
    kubectl get pods -n $namespace
    echo "There are running pods. If you have other deployments installed in namespace $namespace, check and uninstall all deployments before rerun this script to delete namespace $namespace."
    exit 1
  else
    echo "Pods are terminated"
  fi

  echo "Deleting all namespaced resources..."
  kubectl delete "$(kubectl api-resources --namespaced=true --verbs=delete -o name | tr "\n" "," | sed -e 's/,$//')" --all -n $namespace

  echo "Deleting namespace..."
  kubectl delete ns $namespace
fi
echo "Uninstall completed."
