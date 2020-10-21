#!/bin/sh

namespace=cp4mcm-cloud-native-monitoring
if [ ! -z $1 ]
then
  namespace=$1
fi
echo "Uninstall Cloud Native Monitoring from namespace $namespace..."

echo "Ensure that you have changed the label to ibm.com/cloud-native-monitoring: \"disabled\" at IBM Cloud Pak® for Multicloud Management hub cluster for this managed cluster"

echo "Do you want to continue [ y or n; \"n\" is default ]?"
read REPLY
case $REPLY in
  y*|Y*) ;;

  *) exit 0
  ;;
esac

kubectl cluster-info
if [ ! $? -eq 0 ]
then
  echo "Log in to the cluster and rerun the script."
  exit 1
fi

echo ""
echo "Deleting namespaced resources..."


nscnt=$(kubectl get ns $namespace --no-headers=true --ignore-not-found=true | wc -l)
if [ $nscnt -eq 0 ]
then
  echo "No namespace $namespace"
else
  cnmonprefix=ibm-cp4mcm-cloud-native
  
  echo "Search and delete helmrelease..."
  helmrelgrp=app.ibm.com
  helmrelcrd=$(kubectl api-resources --api-group='app.ibm.com' --no-headers=true | grep helmreleases)
  if [ -z "$helmrelcrd" ]
  then
    helmrelgrp=apps.open-cluster-management.io
  fi

  helmrel=$(kubectl get helmrelease.$helmrelgrp -n $namespace --no-headers=true --ignore-not-found=true | awk '{print $1}' | grep $cnmonprefix)
  if [ -z "$helmrel" ]
  then
    echo "No helmrelease found."
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

echo "Search and deleting crd..."
crd=$(kubectl get crd k8sdcs.ibmcloudappmgmt.com uas.ua.ibm.com --no-headers=true --ignore-not-found=true | awk '{print $1}')
if [ -z "$crd" ]
then
  echo "No related crd found."
else
  kubectl delete crd $crd
fi

echo "Search and deleting clusterrolebinding..."
clusterrolebinding=$(kubectl get clusterrolebinding node-k8sdc-cr-k8monitor view-k8sdc-cr-k8monitor agentoperator ua-operator reloader-role-binding k8sdc-operator --no-headers=true --ignore-not-found=true | awk '{print $1}')
if [ -z "$clusterrolebinding" ]
then
  echo "No related clusterrolebinding found."
else
  kubectl delete clusterrolebinding $clusterrolebinding
fi

echo "Search and deleting clusterrole..."
clusterrole=$(kubectl get clusterrole k8sdc-cr-k8monitor ua-operator reloader-role --no-headers=true --ignore-not-found=true | awk '{print $1}')
if [ -z "$clusterrole" ]
then
  echo "No related clusterrole found."
else
  kubectl delete clusterrole $clusterrole
fi

echo "Search and deleting podsecuritypolicy..."
podsecuritypolicy=$(kubectl get podsecuritypolicy ua-operator --no-headers=true --ignore-not-found=true | awk '{print $1}')
if [ -z "$podsecuritypolicy" ]
then
  echo "No related podsecuritypolicy found."
else
  kubectl delete podsecuritypolicy $podsecuritypolicy
fi

echo ""
if [ ! $nscnt -eq 0 ]
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
  while [ $podcnt -gt 0 ] && [ $i -lt 18 ]
  do
    echo "Waiting 10 seconds..."
    sleep 10
    podcnt=$(kubectl get pods -n $namespace --no-headers=true --ignore-not-found=true | wc -l)
    i=$((i+1))
  done

  if [ $podcnt -gt 0 ]
  then
    kubectl get pods -n $namespace
    echo "There are running pods, you might have other deployments installed in namespace $namespace, please check and uninstall all deployments before rerun this script to delete namespace $namespace."
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