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
logs="cp4mcm-ha-utility-logs."
logpath="/tmp/$logs$timestamp.txt"
pathToKubeconfig="$HOME/.kube/config"
ocOrKubectl=""

operate=""
moduleAlias=""

# modules that support HA
modules=(
    'service-library|ServiceLibrary|ibm-management-service-library'
    'cam|CAM|ibm-management-cam-install'
    'hybridapp|HybridApp|ibm-management-hybridapp'
    'manage-runtime|ManageRuntime|ibm-management-manage-runtime'
    'ui|UI|ibm-management-ui'
    'notary|Notary|ibm-management-notary'
    'image-security-enforcement|ImageSecurityEnforcement|ibm-management-image-security-enforcement'
)

helpFunc() {
    echo "Usage $0"
    echo "Use this script to enable or diable HA for IBM Cloud Pak for Multicloud Management"
    echo
    echo "  Flags:"
    echo
    echo "     --kubeconfigPath                 The absolute path to the kubeconfig file to access the cluster. Use default kubeconfig if it is omitted"
    echo "     --list                           List the modules that support HA"
    echo "     --enable                         Enable HA for all modules, or a particular module if --module is specified"
    echo "     --disable                        Disable HA for all modules, or a particular module if --module is specified"
    echo "     --verify                         Verify the results by listing the corresponding Kubernetes resources"
    echo "     --module <module>                Enable, diable, or verify HA for a particular module. Use --list to get all valid module names"
    echo "     --help                           Print the help information"
    echo
    echo "  Usage examples:"
    echo
    echo "     $0 --list                        List the modules that support HA"
    echo "     $0 --enable                      Enable HA for all modules"
    echo "     $0 --disable                     Disable HA for all modules"
    echo "     $0 --verify                      Verify the results for all modules"
    echo "     $0 --module ui --enable          Enable HA for one module"
    echo "     $0 --module ui --disable         Disable HA for one module"
    echo "     $0 --module ui --verify          Verify the results for one module"
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
          "--KUBECONFIGPATH")
            pathToKubeconfig=$2; shift 2; ARGC=$(($ARGC-2)) ;;
          "--LIST")
            listModules; shift; ARGC=$(($ARGC-1))
            exit 0 ;;
          "--MODULE")
            moduleAlias=$(aliasOf $2)
            if [[ -z $moduleAlias ]]; then
                echo "Module \"$2\" not known. Exiting." | tee -a "$logpath"
                echo "Please run $0 --list to get all valid module names." | tee -a "$logpath"
                echo "" | tee -a "$logpath"
                exit 1
            fi
            shift 2; ARGC=$(($ARGC-2)) ;;
          "--ENABLE")
            operate="enable"; shift; ARGC=$(($ARGC-1)) ;;
          "--DISABLE")
            operate="disable"; shift; ARGC=$(($ARGC-1)) ;;
          "--VERIFY")
            operate="verify"; shift; ARGC=$(($ARGC-1)) ;;
          "--HELP")
            helpFunc
            exit 1 ;;
          *)
            echo "Argument \"${PRE_FORMAT_ARG}\" not known. Exiting." | tee -a "$logpath"
            echo "" | tee -a "$logpath"
            helpFunc
            exit 1 ;;
      esac
    done

    [[ -z $operate ]] && helpFunc
}

checkKubeconfig() {
    if [[ "${pathToKubeconfig}" == "" || -z "${pathToKubeconfig}" ]]; then
      echo "No path was provided to the --pathToKubeconfig flag, please provide a path." | tee -a "$logpath"
      exit 1
    elif [[ ! -f "${pathToKubeconfig}" ]]; then
      echo "No file was found at ${pathToKubeconfig}; please use an absolute path to the kubeconfig for the cluster." | tee -a "$logpath"
      exit 1
    fi

    $ocOrKubectl get pods --all-namespaces=true --kubeconfig="${pathToKubeconfig}" | grep "openshift" > /dev/null 2>&1
    local result=$?
    if [[ "${result}" -ne 0 ]]; then
      echo "Attempt to access cluster with kubeconfig at ${pathToKubeconfig} has failed." | tee -a "$logpath"
      exit 1
    fi

    echo "Successfully used kubeconfig provided." | tee -a "$logpath"
    echo "" | tee -a "$logpath"
    return 0
}

checkIfocANDORkubectlInstalled() {
    which oc > /dev/null 2>&1
    local result1=$?
    which kubectl > /dev/null 2>&1
    local result2=$?
    if [[ "${result1}" -ne 0 && "${result2}" -ne 0 ]]; then
      echo "Neither oc nor kubectl could be found in the PATH; ensure that these two programs are in the PATH." | tee -a "$logpath"
      echo "" | tee -a "$logpath"
      echo "Current PATH: $PATH" | tee -a "$logpath"
      exit 1
    elif [[ "${result1}" -eq 0 ]]; then
      echo "Found the oc binary; using it to interact with cluster." | tee -a "$logpath"
      echo "" | tee -a "$logpath"
      ocOrKubectl="oc"
      return 0
    else
      echo "Found the kubectl binary; using it to interact with cluster." | tee -a "$logpath"
      echo "" | tee -a "$logpath"
      ocOrKubectl="kubectl"
      return 0
    fi
}

validate(){
    checkIfocANDORkubectlInstalled
    checkKubeconfig
    echo "Validation of parameters and environment complete." | tee -a "$logpath"
    echo "" | tee -a "$logpath"
    return 0
}

# end admin stuff

# begin core stuff

listModules() {
    echo "Modules that support HA:" | tee -a "$logpath"
    echo "" | tee -a "$logpath"

    for module in ${modules[@]}; do
        echo "  * ${module%%|*}" | tee -a "$logpath"
    done

    echo "" | tee -a "$logpath"
}

aliasOf() {
    local actualModule=$1
    for module in ${modules[@]}; do
        local mName=${module%%|*}
        local mAlias=${module#*|}; mAlias=${mAlias%|*}
        [[ $actualModule == $mName ]] && echo $mAlias && return
    done
}

idOf() {
    local actualModule=$1
    for module in ${modules[@]}; do
        local mName=${module%%|*}
        local mId=${module##*|}
        [[ $actualModule == $mName ]] && echo $mId && return
    done
}

enableHAForServiceLibrary() {
    enableHAFor management-infrastructure-management service-library \
        servicelibraryuis.servicelibraryui.management.ibm.com       '/spec/deployment/spec/replicas' \
        servicelibraryuiapis.servicelibraryuiapi.management.ibm.com '/spec/deployment/spec/replicas'
}

enableHAForCAM() {
    enableHAFor management-infrastructure-management cam \
        manageservices.cam.management.ibm.com '/spec/camAPI/replicaCount'   \
        manageservices.cam.management.ibm.com '/spec/camProxy/replicaCount' \
        manageservices.cam.management.ibm.com '/spec/camUI/replicaCount'    \
        manageservices.cam.management.ibm.com '/spec/camController/replicaCount'
}

enableHAForHybridApp() {
    enableHAFor openshift-operators hybridapp \
        operators.deploy.hybridapp.io '/spec/replicas'
}

enableHAForManageRuntime() {
    enableHAFor kube-system manage-runtime
}

enableHAForUI() {
    enableHAFor kube-system ui \
        consoleuis.consoleui.management.ibm.com         '/spec/replicas' \
        applicationuis.applicationui.management.ibm.com '/spec/replicas' \
        grcuis.grcui.management.ibm.com                 '/spec/replicas' \
        grcuiapis.grcuiapi.management.ibm.com           '/spec/replicas' \
        consoleuiapis.consoleuiapi.management.ibm.com   '/spec/replicas'
}

enableHAForNotary() {
    enableHAFor management-security-services notary \
        notaries.notary.management.ibm.com '/spec/notaryServer/replicaCount' \
        notaries.notary.management.ibm.com '/spec/notarySigner/replicaCount'
}

enableHAForImageSecurityEnforcement() {
    enableHAFor management-security-services image-security-enforcement \
        imagesecurityenforcement '/spec/replicaCount'
}

replicasOf() {
    if [[ $operate == disable ]]; then
        echo 1
    else
        [[ $1 == mcm ]] && echo 3 || echo 2
    fi
}

enableHAFor() {
    local namespace="$1"
    local module="$2"
    local crPaths=(${@:3})
    local crPathNum=${#crPaths[@]}
    local replicas=$(replicasOf $module)

    echo "Attempting to $operate HA for module $module in $namespace namespace ..." | tee -a "$logpath"
    echo "" | tee -a "$logpath"

    echo "* To $operate HA for operator ..." | tee -a "$logpath"

    local csv=$($ocOrKubectl get csv -n $namespace -o name | grep $(idOf $module))
    [[ -n $csv ]] &&
    $ocOrKubectl patch $csv -n $namespace --type='json' -p '[{"op":"replace","path":"/spec/install/spec/deployments/0/spec/replicas","value":'$replicas'}]' ||
    echo "Cannot find clusterserviceversion for $module, skip this step." | tee -a "$logpath"

    [[ $crPathNum != 0 ]] && echo "* To $operate HA for operands ..." | tee -a "$logpath"

    for (( i = 0; i < ${#crPaths[@]}; i += 2 )); do
        local cr=${crPaths[i]}
        local path=${crPaths[i+1]}
        local crResource=$($ocOrKubectl get $cr -n $namespace -o name 2>/dev/null)

        [[ -n $crResource ]] &&
        $ocOrKubectl patch $crResource -n $namespace --type='json' -p '[{"op":"replace","path":"'$path'","value":'$replicas'}]' ||
        echo "Cannot find custom resource for $cr, skip this step." | tee -a "$logpath"
    done

    echo "" | tee -a "$logpath"
    echo "Changes have been applied to $operate HA for $module" | tee -a "$logpath"
    echo "" | tee -a "$logpath"
}

enableHAForAll() {
    echo "Start to $operate HA for IBM Cloud Pak for Multicloud Management ..." | tee -a "$logpath"
    echo "" | tee -a "$logpath"

    enableHAForServiceLibrary
    enableHAForCAM
    enableHAForHybridApp
    enableHAForManageRuntime
    enableHAForUI
    enableHAForNotary
    enableHAForImageSecurityEnforcement

    echo "All changes have been applied to $operate HA for IBM Cloud Pak for Multicloud Management." | tee -a "$logpath"
    echo "" | tee -a "$logpath"
}

DP_HEADLINE="NAME.*READY.*UP-TO-DATE.*AVAILABLE.*AGE"
SS_HEADLINE="NAME.*READY.*AGE"
RS_HEADLINE="NAME.*DESIRED.*CURRENT.*READY.*AGE"

withHeadline() {
    case $1 in
    "deployment")
        echo "$2\|$DP_HEADLINE" ;;
    "statefulset")
        echo "$2\|$SS_HEADLINE" ;;
    "replicaset")
        echo "$2\|$RS_HEADLINE" ;;
    esac
}

verifyHAFor() {
    local include
    local exclude
    local POSITIONAL=()
    while [[ $# -gt 0 ]]; do
      case "$1" in
      --include)
        include=$2; shift 2 ;;
      --exclude)
        exclude=$2; shift 2 ;;
      *)
        POSITIONAL+=("$1"); shift ;;
      esac
    done

    local namespace=${POSITIONAL[0]}
    local module=${POSITIONAL[1]}
    local conditions=(${POSITIONAL[@]:2})

    echo "Attempting to list resources for module $module in $namespace namespace ..." | tee -a "$logpath"
    echo "" | tee -a "$logpath"

    for (( i = 0; i < ${#conditions[@]}; i += 2 )); do
        local resource=${conditions[i]}
        local condition=${conditions[i+1]}
        condition=$(withHeadline $resource $condition)

        echo "* Resource: $resource" | tee -a "$logpath"

        if [[ -n $include ]]; then
            local include=$(withHeadline $resource $include)
            [[ -n $($ocOrKubectl get $resource -n $namespace -o name | grep "$condition" | grep "$include") ]] &&
            $ocOrKubectl get $resource -n $namespace 2>/dev/null | grep "$condition" | grep "$include" | tee -a "$logpath" ||
            echo "No resources found in $namespace namespace." | tee -a "$logpath"
        elif [[ -n $exclude ]]; then
            [[ -n $($ocOrKubectl get $resource -n $namespace -o name | grep "$condition" | grep -v "$exclude") ]] &&
            $ocOrKubectl get $resource -n $namespace 2>/dev/null | grep "$condition" | grep -v "$exclude" | tee -a "$logpath" ||
            echo "No resources found in $namespace namespace." | tee -a "$logpath"
        else
            [[ -n $($ocOrKubectl get $resource -n $namespace -o name | grep "$condition" | tee -a "$logpath") ]] &&
            $ocOrKubectl get $resource -n $namespace 2>/dev/null | grep "$condition" | tee -a "$logpath" ||
            echo "No resources found in $namespace namespace." | tee -a "$logpath"
        fi
    done

    echo "" | tee -a "$logpath"
}

verifyHAForIMVM() {
    verifyHAFor management-infrastructure-management infrastructure-management-vm deployment 'infra-management-vm-operator'
}

verifyHAForIMGRC() {
    verifyHAFor management-infrastructure-management infrastructure-management-grc deployment 'infra-management-grc-operator'
}

verifyHAForServiceLibrary() {
    verifyHAFor management-infrastructure-management service-library deployment 'service-library'
}

verifyHAForCAM() {
    verifyHAFor management-infrastructure-management cam deployment 'cam' statefulset 'cam'
}

verifyHAForHybridApp() {
    verifyHAFor openshift-operators hybridapp deployment 'ibm.*hybridapp' replicaset 'cp4mcm-hybridapp'
}

verifyHAForManageRuntime() {
    verifyHAFor kube-system manage-runtime deployment 'manage-runtime'
}

verifyHAForUI() {
    verifyHAFor kube-system ui deployment 'multicluster\|mcm-ui-operator' --include 'ui'
}

verifyHAForNotary() {
    verifyHAFor management-security-services notary deployment 'notary'
}

verifyHAForImageSecurityEnforcement() {
    verifyHAFor management-security-services image-security-enforcement deployment 'image.*enforcement'
}

verifyHAForAll() {
    echo "Start to $operate HA for IBM Cloud Pak for Multicloud Management ..." | tee -a "$logpath"
    echo "" | tee -a "$logpath"

    verifyHAForServiceLibrary
    verifyHAForCAM
    verifyHAForHybridApp
    verifyHAForManageRuntime
    verifyHAForUI
    verifyHAForNotary
    verifyHAForImageSecurityEnforcement
}

# end core stuff

main(){
    echo "Executing $0; logs available at $logpath"

    validate

    if [[ 'enable or disable' =~ $operate ]]; then
        [[ -z $moduleAlias ]] && enableHAForAll || enableHAFor${moduleAlias}
    elif [[ 'verify' == $operate ]]; then
        [[ -z $moduleAlias ]] && verifyHAForAll || verifyHAFor${moduleAlias}
    fi
}

parse_args "$@"

main
