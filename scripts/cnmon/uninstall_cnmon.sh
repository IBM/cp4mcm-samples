#!/bin/sh

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
    secret_name=search-hub-kubeconfig
    helmrelgrp=apps.open-cluster-management.io
  fi
  server_url=$(kubectl get secret $secret_name --ignore-not-found=true -n $mcm_ns -o yaml | grep '  kubeconfig' | awk '{ print $2 }' | base64 -d | grep '    server' | awk '{ print $2 }')
fi

echo ""
echo "Uninstall Cloud Native Monitoring from namespace $namespace..."
echo ""
echo "Ensure that you have changed the label to ibm.com/cloud-native-monitoring: \"disabled\""
echo "at IBM Cloud Pak® for Multicloud Management hub cluster $server_url"
echo "for this managed cluster"

echo "Do you want to continue [ y or n; \"n\" is default ]?"
read REPLY
case $REPLY in
  y*|Y*) ;;

  *) exit 0
  ;;
esac

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

function search_delete_helmrel(){
  helmrelgrp=$1
  helmresource=$(kubectl api-resources --api-group=$helmrelgrp --no-headers=true | grep helmreleases)
  if [ ! -z "$helmresource" ]
    then
    helmrel=$(kubectl get helmrelease.$helmrelgrp -n $namespace --no-headers=true --ignore-not-found=true | awk '{print $1}' | grep $cnmonprefix)
    if [ -z "$helmrel" ]
    then
      echo "No helmrelease.$helmrelgrp found."
    else
      kubectl patch helmrelease.$helmrelgrp $helmrel -p '{"metadata":{"finalizers":[]}}' --type merge -n $namespace
      helmrel1=$(kubectl get helmrelease.$helmrelgrp -n $namespace --no-headers=true --ignore-not-found=true | awk '{print $1}' | grep $cnmonprefix)
      if [ ! -z "$helmrel1" ]
      then
        kubectl patch helmrelease.$helmrelgrp $helmrel -p '{"metadata":{"finalizers":[]}}' --type merge -n $namespace
      fi
      helmrel2=$(kubectl get helmrelease.$helmrelgrp -n $namespace --no-headers=true --ignore-not-found=true | awk '{print $1}' | grep $cnmonprefix)
      if [ ! -z "$helmrel2" ]
      then
        kubectl delete helmrelease.$helmrelgrp $helmrel -n $namespace
      fi
    fi
  fi
}

echo ""
echo "Deleting namespaced resources..."

nscnt=$(kubectl get ns $namespace --no-headers=true --ignore-not-found=true | wc -l)
if [ $nscnt -eq 0 ]
then
  echo "No namespace $namespace"
else
  cnmonprefix=ibm-cp4mcm-cloud-native
  
  echo "Search and delete helmrelease..."
  search_delete_helmrel app.ibm.com
  search_delete_helmrel apps.open-cluster-management.io
  
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
  
  echo "Search and delete config map..."
  uacm=$(kubectl get configmap ualk-icam-leader -n $namespace --no-headers=true --ignore-not-found=true | awk '{print $1}')
  if [ -z "$uacm" ]
  then
    echo "No related configmap found."
  else
    kubectl delete configmap $uacm -n $namespace
  fi
  
  echo "Search and delete secret..."
  sec=$(kubectl get secret dc-secret ibm-agent-https-secret icam-server-secret ua-secrets -n $namespace --no-headers=true --ignore-not-found=true | awk '{print $1}')
  if [ -z "$sec" ]
  then
    echo "No related secret found."
  else
    kubectl delete secret $sec -n $namespace
  fi
  
  echo "Search and delete k8sdc secret..."
  k8sdcsec=$(kubectl get secret -l name=k8sdc-cr -n $namespace --no-headers=true --ignore-not-found=true | awk '{print $1}')
  if [ -z "$k8sdcsec" ]
  then
    echo "No k8sdc secret found."
  else
    kubectl delete secret $k8sdcsec -n $namespace
  fi
  
  echo "Search and delete cnmon secret..."
  cnmonsec=$(kubectl get secret -n $namespace --no-headers=true --ignore-not-found=true | awk '{print $1}' | grep $cnmonprefix)
  if [ -z "$cnmonsec" ]
  then
    echo "No cnmon secret found."
  else
    kubectl delete secret $cnmonsec -n $namespace
  fi
fi

echo ""
echo "Deleting related non-namespaced resources..."

echo "Search and deleting k8sdcs crd..."
crd=$(kubectl get crd k8sdcs.ibmcloudappmgmt.com --no-headers=true --ignore-not-found=true | awk '{print $1}')
if [ -z "$crd" ]
then
  echo "No k8sdcs crd found."
else
  kubectl delete crd $crd
fi

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
  reloader-role-binding
  ibm-dc-autoconfig-operator
  agentoperator
)

for i in "${clusterrolebinding[@]}"; do
  kubectl get clusterrolebinding ${i} > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    continue
  fi
  echo "Deleting clusterrolebinding ${i}"
  kubectl delete clusterrolebinding $i
done

clusterrole=(
  k8sdc-cr-k8monitor
  ua-operator
  reloader-role
)
for i in "${clusterrole[@]}"; do
  kubectl get clusterrole ${i} > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    continue
  fi
  echo "Deleting clusterrole ${i}"
  kubectl delete clusterrole $i
done

echo "Search and deleting podsecuritypolicy..."
podsecuritypolicy=$(kubectl get podsecuritypolicy ua-operator --no-headers=true --ignore-not-found=true | awk '{print $1}')
if [ -z "$podsecuritypolicy" ]
then
  echo "No related podsecuritypolicy found."
else
  kubectl delete podsecuritypolicy $podsecuritypolicy
fi

echo ""
if [ ! $nscnt -eq 0 -a $keep_uacr = false ]
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