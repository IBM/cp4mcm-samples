#!/usr/bin/env bash

# Dependencies:
# 1. bash
# 2. oc or kubectl
# 3. an OpenShift cluster on which IBM Cloud Pak for Multicloud Management is installed

# exit on failures
#set -e

# exit on eval of unset variable
#set -u

# trace execution
#set -x

# pipelines return status of value of last command to exit with non-zero status
set -o pipefail

# last execution
CALLER=$_

# begin admin stuff

timestamp=`date +%Y%m%d%H%M`
logs="cp4mcm-enable-ha-logs."
logpath="/tmp/$logs$timestamp.txt"
pathToKubeconfig="$HOME/.kube/config"
ocOrKubectl=""
mcmcoreReplicas=3
defaultReplicas=2

helpFunc() {
    echo "Usage $0"
    echo "Use this script to enable HA for IBM Cloud Pak for Multicloud Management"
    echo
    echo "  *Flags:"
    echo 
    echo "     --kubeconfigPath                 The absolute path to the kubeconfig file to access the cluster"
    echo "     --help                           Print the help information"
    echo
    exit 0
}

parse_args() {
    ARGC=$#
    while [ $ARGC -gt 0 ] ; do
      if [ "$1" == "-n" ] || [ "$1" == "-N" ] ; then
          ARG="-N"
      else
          PRE_FORMAT_ARG=$1
          ARG=`echo $1 | tr .[a-z]. .[A-Z].`
      fi
      case $ARG in
          "--KUBECONFIGPATH")      #
            pathToKubeconfig=$2; shift 2; ARGC=$(($ARGC-2)) ;;
          "--HELP")      #
            helpFunc
            exit 1 ;;
          *)
            echo "Argument \"${PRE_FORMAT_ARG}\" not known. Exiting." | tee -a "$logpath"
            echo "" | tee -a "$logpath"
            helpFunc
            exit 1 ;;
      esac
    done
}

checkKubeconfig() {
    if [[ "${pathToKubeconfig}" == "" || -z "${pathToKubeconfig}" ]]; then
      echo "No path was provided to the --pathToKubeconfig flag, please provide a path"
      exit 1
    elif [[ ! -f "${pathToKubeconfig}" ]]; then
      echo "No file was found at ${pathToKubeconfig}; please use an absolute path to the kubeconfig for the cluster" | tee -a "$logpath"
      exit 1
    fi
    
    $ocOrKubectl get pods --all-namespaces=true --kubeconfig="${pathToKubeconfig}" | grep "openshift" > /dev/null 2>&1
    local result=$?
    if [[ "${result}" -ne 0 ]]; then
      echo "Attempt to access cluster with kubeconfig at ${pathToKubeconfig} has failed" | tee -a "$logpath"
      exit 1
    fi

    echo "Successfully used kubeconfig provided" | tee -a "$logpath"
    echo "" | tee -a "$logpath"
    return 0
}

checkIfocANDORkubectlInstalled() {
    which oc > /dev/null 2>&1
    local result1=$?
    which kubectl > /dev/null 2>&1
    local result2=$?
    if [[ "${result1}" -ne 0 && "${result2}" -ne 0 ]]; then
      echo "Neither oc nor kubectl could be found in the PATH; ensure that these two programs are in the PATH" | tee -a "$logpath"
      echo "" | tee -a "$logpath"
      echo "Current PATH: $PATH" | tee -a "$logpath"
      exit 1
    elif [[ "${result1}" -eq 0 ]]; then
      echo "Found the oc binary; using it to interact with cluster" | tee -a "$logpath"
      echo "" | tee -a "$logpath"
      ocOrKubectl="oc"
      return 0
    else
      echo "Found the kubectl binary; using it to interact with cluster" | tee -a "$logpath"
      echo "" | tee -a "$logpath"
      ocOrKubectl="kubectl"
      return 0
    fi
}

validate(){
    checkIfocANDORkubectlInstalled
    checkKubeconfig
    echo "Validation of parameters and environment complete" | tee -a "$logpath"
    echo "" | tee -a "$logpath"
    return 0
}

# end admin stuff

# begin core stuff

enableHAForMCMCore() {
    local ns="kube-system"

    echo "Attempting to enable HA for ibm-management-mcm" | tee -a "$logpath"

    # Operator
    local csv=$($ocOrKubectl get csv -n $ns -o name | grep ibm-management-mcm)
    [[ -n $csv ]] &&
    $ocOrKubectl patch $csv -n $ns --type='json' -p '[{"op":"replace","path":"/spec/install/spec/deployments/0/spec/replicas","value":'$defaultReplicas'}]' ||
    echo "Cannot find clusterserviceversion for ibm-management-mcm, skip" | tee -a "$logpath"

    # MCM Core
    local cr=$($ocOrKubectl get mcmcores.management.ibm.com -n $ns -o name 2>/dev/null)
    [[ -n $cr ]] &&
    $ocOrKubectl patch $cr -n $ns --type=merge -p '{"spec":{"global":{"replicas":'$mcmcoreReplicas'}}}' ||
    echo "Cannot find custom resource for mcmcores.management.ibm.com, skip" | tee -a "$logpath"

    # KUI
    cr=$($ocOrKubectl get kuis.management.ibm.com -n $ns -o name 2>/dev/null)
    [[ -n $cr ]] &&
    $ocOrKubectl patch $cr -n $ns --type=merge -p '{"spec":{"replicaCount":'$mcmcoreReplicas'}}' ||
    echo "Cannot find custom resource for kuis.management.ibm.com, skip" | tee -a "$logpath"

    echo "" | tee -a "$logpath"
}

enableHAForKong() {
    local ns="kube-system"

    echo "Attempting to enable HA for ibm-management-kong" | tee -a "$logpath"

    # Operator
    local csv=$($ocOrKubectl get csv -n $ns -o name | grep ibm-management-kong)
    [[ -n $csv ]] &&
    $ocOrKubectl patch $csv -n $ns --type='json' -p '[{"op":"replace","path":"/spec/install/spec/deployments/0/spec/replicas","value":'$defaultReplicas'}]' ||
    echo "Cannot find clusterserviceversion for ibm-management-kong, skip" | tee -a "$logpath"

    # Kong
    local cr=$($ocOrKubectl get kongs.management.ibm.com -n $ns -o name 2>/dev/null)
    [[ -n $cr ]] &&
    $ocOrKubectl patch $cr -n $ns --type=merge -p '{"spec":{"replicaCount":'$defaultReplicas'}}' ||
    echo "Cannot find custom resource for kongs.management.ibm.com, skip" | tee -a "$logpath"

    echo "" | tee -a "$logpath"
}

enableHAForServiceLibrary() {
    local ns="management-infrastructure-management"

    echo "Attempting to enable HA for ibm-management-service-library" | tee -a "$logpath"

    # Operator
    local csv=$($ocOrKubectl get csv -n $ns -o name | grep ibm-management-service-library)
    [[ -n $csv ]] &&
    $ocOrKubectl patch $csv -n $ns --type='json' -p '[{"op":"replace","path":"/spec/install/spec/deployments/0/spec/replicas","value":'$defaultReplicas'}]' ||
    echo "Cannot find clusterserviceversion for ibm-management-service-library, skip" | tee -a "$logpath"

    # Service Library UI
    local cr=$($ocOrKubectl get servicelibraryuis.servicelibraryui.management.ibm.com -n $ns -o name 2>/dev/null)
    [[ -n $cr ]] &&
    $ocOrKubectl patch $cr -n $ns --type='json' -p '[{"op":"replace","path":"/spec/deployment/spec/replicas","value":'$defaultReplicas'}]' ||
    echo "Cannot find custom resource for servicelibraryuis.servicelibraryui.management.ibm.com, skip" | tee -a "$logpath"

    # Service Library UI API
    cr=$($ocOrKubectl get servicelibraryuiapis.servicelibraryuiapi.management.ibm.com -n $ns -o name 2>/dev/null)
    [[ -n $cr ]] &&
    $ocOrKubectl patch $cr -n $ns --type='json' -p '[{"op":"replace","path":"/spec/deployment/spec/replicas","value":'$defaultReplicas'}]' ||
    echo "Cannot find custom resource for servicelibraryuiapis.servicelibraryuiapi.management.ibm.com, skip" | tee -a "$logpath"

    echo "" | tee -a "$logpath"
}

enableHAForCAM() {
    local ns="management-infrastructure-management"

    echo "Attempting to enable HA for ibm-management-cam-install" | tee -a "$logpath"

    # Operator
    local csv=$($ocOrKubectl get csv -n $ns -o name | grep ibm-management-cam-install)
    [[ -n $csv ]] &&
    $ocOrKubectl patch $csv -n $ns --type='json' -p '[{"op":"replace","path":"/spec/install/spec/deployments/0/spec/replicas","value":'$defaultReplicas'}]' ||
    echo "Cannot find clusterserviceversion for ibm-management-cam-install, skip" | tee -a "$logpath"

    # Manage Service
    local cr=$($ocOrKubectl get manageservices.cam.management.ibm.com -n $ns -o name 2>/dev/null)
    [[ -n $cr ]] &&
    $ocOrKubectl patch $cr -n $ns --type=merge -p '{"spec":{"camController":{"replicaCount":'$defaultReplicas'}}}' ||
    echo "Cannot find custom resource for manageservices.cam.management.ibm.com, skip" | tee -a "$logpath"

    echo "" | tee -a "$logpath"
}

enableHAForHybrid() {
    local ns="openshift-operators"

    echo "Attempting to enable HA for ibm-management-hybridapp" | tee -a "$logpath"

    # Operator
    local csv=$($ocOrKubectl get csv -n $ns -o name | grep ibm-management-hybridapp)
    [[ -n $csv ]] &&
    $ocOrKubectl patch $csv -n $ns --type='json' -p '[{"op":"replace","path":"/spec/install/spec/deployments/0/spec/replicas","value":'$defaultReplicas'}]' ||
    echo "Cannot find clusterserviceversion for ibm-management-hybridapp, skip" | tee -a "$logpath"

    # Operator(CR)
    local cr=$($ocOrKubectl get operators.deploy.hybridapp.io -n $ns -o name 2>/dev/null)
    [[ -n $cr ]] &&
    $ocOrKubectl patch $cr -n $ns --type='json' -p '[{"op":"replace","path":"/spec/replicas","value":'$defaultReplicas'}]' ||
    echo "Cannot find custom resource for operators.deploy.hybridapp.io, skip" | tee -a "$logpath"

    echo "" | tee -a "$logpath"
}

enableHAForRuntimeManagement() {
    local ns="kube-system"

    echo "Attempting to enable HA for ibm-management-manage-runtime" | tee -a "$logpath"

    # Operator
    local csv=$($ocOrKubectl get csv -n $ns -o name | grep ibm-management-manage-runtime)
    [[ -n $csv ]] &&
    $ocOrKubectl patch $csv -n $ns --type='json' -p '[{"op":"replace","path":"/spec/install/spec/deployments/0/spec/replicas","value":'$defaultReplicas'}]' ||
    echo "Cannot find clusterserviceversion for ibm-management-manage-runtime, skip" | tee -a "$logpath"

    echo "" | tee -a "$logpath"
}

enableHA(){
    echo "Start to enable HA for each component in IBM Cloud Pak for Multicloud Management..." | tee -a "$logpath"
    echo "" | tee -a "$logpath"

    enableHAForMCMCore
    enableHAForKong
    enableHAForServiceLibrary
    enableHAForCAM
    enableHAForHybrid
    enableHAForRuntimeManagement
    
    echo "Successfully enabled HA for all components in IBM Cloud Pak for Multicloud Management that support HA." | tee -a "$logpath"
}

# end core stuff

main(){
    echo "Executing $0; logs available at $logpath"
    validate
    enableHA
}

parse_args "$@"

main
