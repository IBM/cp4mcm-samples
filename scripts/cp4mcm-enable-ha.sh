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

enableHA(){
  echo "Start to enable HA for each component in IBM Cloud Pak for Multicloud Management..." | tee -a "$logpath"
  echo "" | tee -a "$logpath"
}

# end core stuff

main(){
    echo "Executing $0; logs available at $logpath"
    validate
    enableHA
}

parse_args "$@"

main