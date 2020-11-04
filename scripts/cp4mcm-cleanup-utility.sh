#!/usr/bin/env bash

# The following script has two main modes:


# Dependencies:
# 1. bash
# 2. oc or kubectl
# 3. an openshift cluster on which cp4mcm is currently installed, or was recently uninstalled

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
logs="cp4mcm-uninstall-logs."
logpath="/tmp/$logs$timestamp.txt"
ocOrKubectl=""
preUninstall="false"
postUninstall="false"

helpFunc() {
       echo "Usage $0"
       echo "Use this script to remove orphaned resources for the CloudPak for Multicloud Management"
       echo
       echo "  *Primary flags:"
       echo 
       echo "     --kubeconfigPath                 The absolute path to the kubeconfig file to access the cluster"
       echo "     --mode                           The mode the script should use. The available modes are:"
       echo
       echo "                                          preUninstallCleanup"
       echo "                                          postUninstallCleanup"
       echo "                                          customResourceCleanup"
       echo "                                          secretConfigmapCleanup"
       echo "                                          anyResourceCleanup"
       echo
       echo "  *Modes and usage:"
       echo
       echo "     preUninstallCleanup              Description: Remove Custom Resources for all manually installed CP4MCM suboperators, i.e. Chatops, InfraVM, InfraGRC, IMInstall, and VMPolicyAnsible."
       echo "                                      Usage: $0 --kubeconfigPath /path/to/kubeconfig --mode preUninstallCleanup"
       echo
       echo
       echo "     postUninstallCleanup             Description: Remove all orphaned secrets and miscellaneous resources left behind after CP4MCM is removed"
       echo "                                      Usage: $0 --kubeconfigPath /path/to/kubeconfig --mode postUninstallCleanup"
       echo
       echo
       echo "     customResourceCleanup            Description: Remove a particular operators Custom Resources. Available operators are Chatops, InfraVM, InfraGRC, IMInstall, and VMPolicyAnsible"
       echo "                                      Usage: $0 --kubeconfigPath /path/to/kubeconfig --mode customResourceCleanup --Chatops"
       echo "                                      Usage: $0 --kubeconfigPath /path/to/kubeconfig --mode customResourceCleanup --InfraVM"
       echo "                                      Usage: $0 --kubeconfigPath /path/to/kubeconfig --mode customResourceCleanup --InfraGRC"
       echo "                                      Usage: $0 --kubeconfigPath /path/to/kubeconfig --mode customResourceCleanup --IMInstall"
       echo "                                      Usage: $0 --kubeconfigPath /path/to/kubeconfig --mode customResourceCleanup --VMPolicyAnsible"
       echo
       echo
       echo "     anyResourceCleanup               Description: Remove an arbitrary kubernetes resource by specifying its Kind, Name, and Namespace; removes all finalizers"
       echo "                                      Usage: $0 --kubeconfigPath /path/to/kubeconfig --mode anyResourceCleanup --resourceKind deployment --resourceName mydply --resourceNamespace myNS"
       exit 0
}

parse_args() {
    ARGC=$#
    if [ $ARGC == 0 ] ; then
	helpFunc
        exit
    fi
    while [ $ARGC != 0 ] ; do
	if [ "$1" == "-n" ] || [ "$1" == "-N" ] ; then
	    ARG="-N"
	else
	    PRE_FORMAT_ARG=$1
	    ARG=`echo $1 | tr .[a-z]. .[A-Z].`
	fi
	case $ARG in
	    "--KUBECONFIGPATH")	#
		pathToKubeconfig=$2; shift 2; ARGC=$(($ARGC-2)) ;;
	    "--MODE")
		mode=$2; shift 2; ARGC=$(($ARGC-2)); ;;
	    "--CHATOPS")
		operator="chatops"; shift 1; ARGC=$(($ARGC-1)); ;;
	    "--INFRAGRC")
		operator="infraGRC"; shift 1; ARGC=$(($ARGC-1)); ;;
	    "--IMINSTALL")
		operator="imInstall"; shift 1; ARGC=$(($ARGC-1)); ;;
	    "--VMPOLICYANSIBLE")
		operator="vmPolicyAnsible"; shift 1; ARGC=$(($ARGC-1)); ;;
	    "--INFRAVM")
		operator="infraVM"; shift 1; ARGC=$(($ARGC-1)); ;;
	    "--RESOURCEKIND")	#
		resKind=$2; shift 2; ARGC=$(($ARGC-2)) ;;
	    "--RESOURCENAME")	#
		resName=$2; shift 2; ARGC=$(($ARGC-2)) ;;
	    "--RESOURCENAMESPACE")	#
		resNamespace=$2; shift 2; ARGC=$(($ARGC-2)) ;;
	    "--HELP")	#
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

checkOptions() {
    if [[ "${mode}" == "preUninstallCleanup" ]]; then
	echo "Mode: preUninstallCleanup"
    elif [[ "${mode}" == "postUninstallCleanup" ]]; then
	echo "Mode: postUninstallCleanup"
    elif [[ "${mode}" == "secretConfigmapCleanup" ]]; then
	echo "Mode: secretConfigmapCleanup"
    elif [[ "${mode}" == "customResourceCleanup" ]]; then
	echo "Mode: customResourceCleanup"
	echo "Operator: $operator"
	if [[ ! "${operator}" =~ ^(chatops|infraVM|infraGRC|imInstall|vmPolicyAnsible)$ ]]; then
	    echo "No operator was chosen for custom resource cleanup." | tee -a "$logpath"
	    echo "The available operators are:"
	    echo
	    echo "Chatops"
	    echo "E.g.: $0 --kubeconfigPath /path/to/kubeconfig --mode customResourceCleanup --Chatops"
	    echo
	    echo "InfraVM"
	    echo "E.g.: $0 --kubeconfigPath /path/to/kubeconfig --mode customResourceCleanup --InfraVM"
	    echo
	    echo "InfraGRC"
	    echo "E.g.: $0 --kubeconfigPath /path/to/kubeconfig --mode customResourceCleanup --InfraGRC"
	    echo
	    echo "IMInstall"
	    echo "E.g.: $0 --kubeconfigPath /path/to/kubeconfig --mode customResourceCleanup --IMInstall"
	    echo
	    echo "VMPolicyAnsible"
	    echo "E.g.: $0 --kubeconfigPath /path/to/kubeconfig --mode customResourceCleanup --VMPolicyAnsible"
	    exit 1
	fi
    elif [[ "${mode}" == "anyResourceCleanup" ]]; then
	echo "Mode: anyResourceCleanup"
	if [[ -z "${resKind}" || -z "${resName}" || -z "${resNamespace}" ]]; then
	    echo "When using anyResourceCleanup mode, a resource kind, name, and namespace must be provided" | tee -a "$logpath"
	    echo "E.g.: $0 --kubeconfigPath /path/to/kubeconfig --mode anyResourceCleanup --resourceKind deployment --resourceName mydply --resourceNamespace myNS"
	    exit 1
	fi
    else
	echo "Mode unrecognized: $mode"
	echo "Available modes are:"
	echo
	echo "preUninstallCleanup"
	echo "E.g.: $0 --kubeconfigPath /path/to/kubeconfig --mode preUninstallCleanup"
	echo
	echo "postUninstallCleanup"
	echo "E.g.: $0 --kubeconfigPath /path/to/kubeconfig --mode postUninstallCleanup"
	echo
	echo "postUninstallCleanup"
	echo "E.g.: $0 --kubeconfigPath /path/to/kubeconfig --mode secretConfigmapCleanup"
	echo 
	echo "customResourceCleanup"
	echo "E.g.: $0 --kubeconfigPath /path/to/kubeconfig --mode customResourceCleanup --Chatops"
	echo	
	echo "anyResourceCleanup"
	echo "E.g.: $0 --kubeconfigPath /path/to/kubeconfig --mode anyResourceCleanup --resourceKind deployment --resourceName mydply --resourceNamespace myNS"
	exit 1
    fi
    return 0
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
    checkOptions
    checkIfocANDORkubectlInstalled
    checkKubeconfig
    echo "validation of parameters and environment complete" | tee -a "$logpath"
    echo "" | tee -a "$logpath"
    return 0
}

# end admin stuff

# begin core stuff

waitUntilDeleted() {
    resourceType=$1
    namespace=$2
    resourceName=$3
    
    stillThere=0
    counter=0
    while [[ "${stillThere}" -eq 0 && "${counter}" -lt 60 ]] # 60 * 5s = 5m
    do
	sleep 5s
	$ocOrKubectl get "${resourceType}" -n "${namespace}" --kubeconfig="${pathToKubeconfig}" | grep "${resourceName}" > /dev/null 2>&1
	local result=$?
	if [[ "${result}" -ne 0 ]]; then
	    stillThere=1
	    echo "Successfully deleted:" | tee -a "$logpath"
	    echo "resourceType: $resourceType" | tee -a "$logpath"
	    echo "resourceName: $resourceName" | tee -a "$logpath"
	    echo "namespace: $namespace" | tee -a "$logpath"
	    echo "" | tee -a "$logpath"
	    return 0
	else
	    ((counter=counter+1))
	    echo "Awaiting deletion:" | tee -a "$logpath"
	    echo "resourceType: $resourceType" | tee -a "$logpath"
	    echo "resourceName: $resourceName" | tee -a "$logpath"
	    echo "namespace: $namespace" | tee -a "$logpath"
	    echo "Attempt: $counter of 60" | tee -a "$logpath"
	    echo "" | tee -a "$logpath"
	fi
    done

    if [[ "${result}" -eq 0 ]]; then
	echo "Failed to delete ${resourceType} ${resourceName} in namespace ${namespace}" | tee -a "$logpath"
	echo "Please contact your kubernetes administrator to manually delete this resource" | tee -a "$logpath"
	sleep 3s
	return 1
    fi
}

deleteResource() {
    resourceType=$1
    namespace=$2
    resourceName=$3

    if [[ "${resourceName}" == "" ]]; then
	echo "The resourceName argument was null" >> $logpath
	return 0
    fi

    $ocOrKubectl get "${resourceType}" "${resourceName}" -n "${namespace}" --kubeconfig="${pathToKubeconfig}" > /dev/null 2>&1
    local result=$?
    if [[ "${result}" -ne 0 ]]; then
	echo "${resourceType}: ${resourceName} in namespace: ${namespace} does not exist; skipping deletion attempt" | tee -a "$logpath"
	echo "" | tee -a "$logpath"
	return 0
    fi

    echo "Deleting ${resourceType}: ${resourceName} in namespace: ${namespace}" | tee -a "$logpath"
    echo "" | tee -a "$logpath"
    
    $ocOrKubectl delete "${resourceType}" "${resourceName}" -n "${namespace}" --force --grace-period=0 --kubeconfig="${pathToKubeconfig}" & >> $logpath
    local result=$?
    if [[ "${result}" -ne 0 ]]; then
	return 1
    fi

    echo "" | tee -a "$logpath"

    sleep 3s

    $ocOrKubectl get "${resourceType}" "${resourceName}" -n "${namespace}" --kubeconfig="${pathToKubeconfig}" > /dev/null 2>&1
    local result=$?
    if [[ "${result}" -ne 1 ]]; then
	echo "Resource still exists; attempting to remove finalizers from resource" | tee -a "$logpath"
	echo "" | tee -a "$logpath"
	patchString='{"metadata":{"finalizers": []}}'
	$ocOrKubectl patch "${resourceType}" "${resourceName}" -n "${namespace}" -p "$patchString" --type=merge --kubeconfig="${pathToKubeconfig}" >> $logpath
	local result=$?
	if [[ "${result}" -ne 0 ]]; then
	    return 1
	fi
    fi

    echo "Waiting for resource to be deleted" | tee -a "$logpath"
    echo "" | tee -a "$logpath"
    waitUntilDeleted "${resourceType}" "${namespace}" "${resourceName}"
    local result=$?
    if [[ "${result}" -ne 0 ]]; then
	return 1
    fi
    return 0
}


deleteKind() {
    local kind=$1
    echo "Deleting all resources of kind: $kind" | tee -a "$logpath"
    echo "" | tee -a "$logpath"
    if [[ "${kind}" == "" ]]; then
	return 1
    fi
    
    local crs=`$ocOrKubectl get ${kind} --all-namespaces=true --kubeconfig="${pathToKubeconfig}" | sed -n '1!p'`
    if [[ "${crs}" == "" ]]; then
	echo "No resources of kind: $kind found" >> "$logpath"
	return 0
    fi

    local result=0

    for crNsLine in "$crs"; do
	if [[ "$crNsLine" != "" ]]; then
            local cr=`echo "$crNsLine" | awk '{ print $2 }'`
            local ns=`echo "$crNsLine" | awk '{ print $1 }'`
	    deleteResource "${kind}" "${ns}" "${cr}"
	    local result=$(( result + $? ))
	fi
    done
    return $result
}

# end core stuff

# pre-uninstall stuff follows

removeChatOps() {
    local ns="management-operations"
    echo "Attempting to delete all resources associated with ibm-management-sre-chatops" | tee -a "$logpath"
    deleteKind "Chatops"
    local result=$?
    deleteResource configmap "${ns}" chatops-st2-pack-configs
    result=$(( result + $? ))
    deleteResource secret "${ns}" chatops-st2chatops
    result=$(( result + $? ))
    if [[ "${result}" -ne 0 ]]; then
	echo "$result ibm-management-sre-chatops resources may remain" | tee -a "$logpath"
	return $result
    else
	echo "Successfully deleted all resources associated with ibm-management-sre-chatops" | tee -a "$logpath"
	return 0
    fi
}

removeImInstall() {
    local ns="management-infrastructure-management"
    echo "Attempting to delete all resources associated with ibm-management-im-install" | tee -a "$logpath"
    deleteKind "IMInstall"
    local result=$?
    if [[ "${result}" -ne 0 ]]; then
	echo "$result ibm-management-im-install resources may remain" | tee -a "$logpath"
	return $result
    else
	echo "Successfully deleted all resources associated with ibm-management-im-install" | tee -a "$logpath"
	return 0
    fi
}

removeInfraGRC() {
    local ns="management-infrastructure-management"
    echo "Attempting to delete all resources associated with ibm-management-infra-grc" | tee -a "$logpath"
    deleteKind "VMResourcePolicy"
    local result=$?
    deleteKind "Connection"
    result=$(( result + $? ))
    
    if [[ "${result}" -ne 0 ]]; then
	echo "$result ibm-management-infra-grc resources may remain" | tee -a "$logpath"
	return $result
    else
	echo "Successfully deleted all resources associated with ibm-management-infra-grc" | tee -a "$logpath"
	return 0
    fi

}

removeInfraVM() {
    local ns="management-infrastructure-management"
    echo "Attempting to delete all resources associated with ibm-management-infra-vm" | tee -a "$logpath"

    deleteKind "Connection"
    local result=$?
    deleteKind "TagLabelMap"
    result=$(( result + $? ))
    deleteKind "VirtualMachineDiscover"
    result=$(( result + $? ))
    deleteKind "VirtualMachine"
    result=$(( result + $? ))
    
    if [[ "${result}" -ne 0 ]]; then
	echo "$result ibm-management-infra-vm resources may remain" | tee -a "$logpath"
	return $result
    else
	echo "Successfully deleted all resources associated with ibm-management-infra-vm" | tee -a "$logpath"
	return 0
    fi
}

removeVMPolicyAnsible() {
    local ns="kube-system"
    echo "Attempting to delete all resources associated with ibm-management-vmpolicy-ansible" | tee -a "$logpath"
    deleteKind "VMPolicy"
    local result=$?
    if [[ "${result}" -ne 0 ]]; then
	echo "$result ibm-management-vmpolicy-ansible resources may remain" | tee -a "$logpath"
	return $result
    else
	echo "Successfully deleted all resources associated with ibm-management-vmpolicy-ansible" | tee -a "$logpath"
	return 0
    fi
}

preUninstallFunc() {
    removeChatOps
    local result=$?
    removeImInstall
    result=$(( result + $? ))
    removeInfraGRC
    result=$(( result + $? ))
    removeInfraVM
    result=$(( result + $? ))
    removeVMPolicyAnsible
    result=$(( result + $? ))
    if [[ "${result}" -ne 0 ]]; then
	echo "Could not successfully delete all manually installed operands and their associated resources for IBM Cloud Pak for Multicloud Management" | tee -a "$logpath"
	echo "Number of resources that may have not been successfully removed: $result"
	return 1
    else
	echo "Successfully deleted all manually installed operands and their associated resources for IBM Cloud Pak for Multicloud Management" | tee -a "$logpath"
	return 0
    fi
}

# end pre-uninstall stuff

# begin particular removal stuff

removeParticularCR() {
    echo $1
    case $1 in
	"chatops")
	removeChatOps; return $?;;
	"infraGRC")
	removeInfraGRC; return $?;;
	"imInstall")
	removeImInstall; return $?;;
	"vmPolicyAnsible")
	removeVMPolicyAnsible; return $?;;
	"infraVM")
	removeInfraVM; return $?;;
	*)
	    echo "Validation should have checked ${operator} to prevent this. Error!"
    esac
}

# end particular Removal stuff

# post uninstall stuff follows

checkIfInstallationInstanceExists(){

    installation=`$ocOrKubectl get installations -A --kubeconfig="${pathToKubeconfig}" | awk '{ print $2 }'`
    if [[ "${installation}" -ne "" ]]; then
	echo "The CP4MCM installation instance still exists; it must be deleted before the postInstallCleanup steps can be performed" | tee -a "$logpath"
	exit 1
    else
	echo "No CP4MCM installation instance exists; proceeding"
	return 0
    fi
}

deleteCRDs() {
    declare -a listOfCRDs=(
	# manage-runtime
	"manageruntimes.manageruntimes.management.ibm.com"
	"runtimes.runtimes.management.ibm.com"
	# service library
	"servicelibraryuiapis.servicelibraryuiapi.management.ibm.com"
	"servicelibraryuis.servicelibraryui.management.ibm.com"
	# cam-install
	"manageservices.cam.management.ibm.com"
	# monitoring
	"monitoringdeploys.monitoring.management.ibm.com"
	# hybrid-app
	"operators.deploy.hybridapp.io"
	"clusters.clusterregistry.k8s.io"
	# notary
	"notaries.notary.management.ibm.com"
	# image-security-enforcement
	"clusterimagepolicies.securityenforcement.admission.cloud.ibm.com"
	"imagepolicies.securityenforcement.admission.cloud.ibm.com"
	"imagesecurityenforcements.ibm-management-image-security-enforcement.cp4mcm.ibm.com"
	# sre-bastion
	"bastions.sretooling.management.ibm.com"
	# chatops
	"chatops.sretooling.management.ibm.com"
	# hybrid-grc-vm
	"vmpolicies.vmpolicy.management.ibm.com"
	# hybrid-grc-car
	"complianceapis.hybridgrc.management.ibm.com"
	"grcrisks.hybridgrc.management.ibm.com"
	# license-advisor-sender
	"licenseadvisorsenders.licenseadvisor.management.ibm.com"
	# license-advisor
	"licenseadvisor.licenseadvisor.management.ibm.com"
	# cp4mcm-ui
	"applicationuis.applicationui.management.ibm.com"
	"consoleuiapis.consoleuiapi.management.ibm.com"
	"consoleuis.consoleui.management.ibm.com"
	"grcuiapis.grcuiapi.management.ibm.com"
	"grcuis.grcui.management.ibm.com"
	# mutation-advisor
	"advisors.mutationadvisor.management.ibm.com"
	# vulnerability-advisor
	"annotators.vulnerabilityadvisor.management.ibm.com"
	"controlplanes.vulnerabilityadvisor.management.ibm.com"
	"crawlers.vulnerabilityadvisor.management.ibm.com"
	"datapipelines.vulnerabilityadvisor.management.ibm.com"
	"indexers.vulnerabilityadvisor.management.ibm.com"
	# sre-inventory
	"inventories.sretooling.management.ibm.com"
	# kong
	"kongs.management.ibm.com"
	# infra-grc
	"vmresourcepolicies.vmpolicy.management.ibm.com"
	"connections.infra.management.ibm.com"
	# infra-vm
	"connections.infra.management.ibm.com"
	"taglabelmaps.infra.management.ibm.com"
	"virtualmachinediscovers.infra.management.ibm.com"
	"virtualmachines.infra.management.ibm.com"
	# infra-management-install
	"iminstalls.infra.management.ibm.com"
	# mcm-core-helm
	"kuis.management.ibm.com"
	"mcmcores.management.ibm.com"
	"mcmsearches.management.ibm.com"
	# odlm
	#"operandrequests.operator.ibm.com"
	#"operandconfigs.operator.ibm.com"
	#"operandbindinfos.operator.ibm.com"
	#"operandregistries.operator.ibm.com
    )

    local result=0
    
    for element in ${listOfCRDs[@]}
    do
	deleteResource "crd" "kube-system" "${element}"
	result=$(( result + $? ))
    done
    
    if [[ "${result}" -ne 0 ]]; then
	echo "Not all CP4MCM CRDs could be successfully deleted." | tee -a "$logpath"
	echo "Number of secrets that may remain: $result" | tee -a "$logpath"
	return $result
    else
	echo "Successfully deleted all CP4MCM CRDs" | tee -a "$logpath"
	return 0
    fi
}

deleteSecrets() {
    echo "Deleting secrets left after uninstall" | tee -a "$logpath"
    declare -a secret_array=(
	"compliance-api-ca-cert-secrets"
	"cs-ca-certificate-secret"
	"grc-risk-ca-cert-secrets"
	"hybridgrc-postgresql-secrets"
	"ibm-license-advisor-token"
	"ibm-licensing-bindinfo-ibm-licensing-upload-token"
	"ibm-licensing-token"
	"ibm-management-pull-secret"
	"icp-management-ingress-tls-secret"
	"icp-metering-api-secret"
	"icp-metering-receiver-proxy-secret"
	"license-advisor-db-config"
	"multicluster-hub-cluster-api-provider-apiserver-ca-cert-sdk"
	"multicluster-hub-console-uiapi-secrets"
	"multicluster-hub-core-apiserver-secrets"
	"multicluster-hub-core-klusterlet-secrets"
	"multicluster-hub-core-webhook-secrets"
	"multicluster-hub-etcd-secrets"
	"multicluster-hub-findingsapi-certificates-credentials"
	"multicluster-hub-findingsapi-proxy-secret"
	"multicluster-hub-grafeas-certificates-credentials"
	"multicluster-hub-grafeas-secret"
	"multicluster-hub-grc-secrets"
	"multicluster-hub-legato-certificates-credentials"
	"multicluster-hub-topology-secrets"
	"platform-oidc-credentials"
	"sa-iam-secrets"
	"search-redisgraph-secrets"
	"search-redisgraph-user-secrets"
	"search-search-api-secrets"
	"search-search-secrets"
	"search-tiller-client-certs"
	"sh.helm.release.v1.gateway.v1"
	"sh.helm.release.v1.multicluster-hub.v1"
	"sh.helm.release.v1.sre-bastion.v1"
	"sh.helm.release.v1.sre-inventory.v1"
	"sre-bastion-bastion-secret"
	"sre-bastion-postgresql"
	"sre-inventory-aggregator-secrets"
	"sre-inventory-inventory-rhacm-redisgraph-secrets"
	"sre-inventory-inventory-rhacm-redisgraph-user-secrets"
	"sre-inventory-redisgraph-secrets"
	"sre-inventory-redisgraph-user-secrets"
	"sre-inventory-search-api-secrets"
	"sre-postgresql-bastion-secret"
	"sre-postgresql-vault-secret"
	"sre-vault-config"
	"teleport-credential"
	"vault-credential"
    )

    local result=0
    
    for element in ${secret_array[@]}
    do
	deleteResource "secret" "kube-system" "${element}"
	result=$(( result + $? ))
    done
    
    if [[ "${result}" -ne 0 ]]; then
	echo "Not all CP4MCM secrets in the kube-system namespace could be successfully deleted." | tee -a "$logpath"
	echo "Number of secrets that may remain: $result" | tee -a "$logpath"
    else
	echo "Successfully deleted all CP4MCM secrets" | tee -a "$logpath"
    fi
    return $result
}

removeMisc() {
    echo "Removing miscellaneous resources"
    deleteResource "pvc" "kube-system" "data-sre-bastion-postgresql-0" "false" 300
    result=$(( result + $? ))
    deleteResource "pvc" "kube-system" "etcd-data-multicluster-hub-etcd-0" "false" 300
    result=$(( result + $? ))
    deleteResource "pvc" "kube-system" "data-sre-inventory-inventory-redisgraph-0" "false" 300
    result=$(( result + $? ))
    deleteResource "pvc" "kube-system" "hybridgrc-db-pvc-hybridgrc-postgresql-0" "false" 300
    result=$(( result + $? ))
    deleteResource "pvc" "kube-system" "license-advisor-pvc" "false" 300
    result=$(( result + $? ))
    deleteResource "pvc" "kube-system" "sre-bastion-teleport-storage-pvc" "false" 300
    result=$(( result + $? ))
    orchestratorInstallPlan=`oc get InstallPlan -n openshift-operators | grep "ibm-management-orchestrator" | awk '{ print $1 }'`
    deleteResource "InstallPlan" "openshift-operators" "${orchestratorInstallPlan}" "false" 300
    result=$(( result + $? ))
    hybridappInstallPlan=`oc get InstallPlan -n openshift-operators | grep "ibm-management-hybridapp" | awk '{ print $1 }'`
    deleteResource "InstallPlan" "openshift-operators" "${hybridappInstallPlan}" "false" 300
    result=$(( result + $? ))
    if [[ "${result}" -eq 0 ]]; then
	echo "All remaining miscellaneous resources related to CP4MCM have been removed" | tee -a "$logpath"
	return 1
    else
	echo "$result resources related to CP4MCM may remain" | tee -a "$logpath"
	return 0
    fi
}


deleteRoute(){
    echo "Deleting vault-route in kube-system namespace"
    vaultRoute=`$ocOrKubectl get route -n kube-system | grep "vault-route"`
    deleteResource "route" "kube-system" "${vaultRoute}"
    result=$?
    if [[ "${result}" -ne 0 ]]; then
	echo "Could not delete vault-route route in kube-system namespace" | tee -a "$logpath"
	echo "" | tee -a "$logpath"
	return 1
    else
	echo "Successfully deleted vault-route route in kube-system namespace" | tee -a "$logpath"
	echo "" | tee -a "$logpath"
	return 0
    fi
}

postUninstallFunc() {
    checkIfInstallationInstanceExists
    local result=$?
    removeMisc
    result=$(( result + $? ))
    echo "Delaying for 300 seconds after removal of CSV and Subscriptions"
    sleep 300s
    deleteRoute
    result=$(( result + $? ))
    deleteSecrets
    result=$(( result + $? ))
    deleteResource "secret" "ibmcloud-cluster-ca-cert" "kube-public"
    result=$(( result + $? ))
    deleteResource "configmap" "ibmcloud-cluster-info" "kube-public"
    result=$(( result + $? ))
    deleteResource "secret" "management-monitoring" "ibm-management-pull-secret" "true" 300
    result=$(( result + $? ))
    deleteResource "secret" "management-infrastructure-management" "ibm-management-pull-secret" "true" 300
    result=$(( result + $? ))
    deleteResource "secret" "management-security-services" "ibm-management-pull-secret" "true" 300
    result=$(( result + $? ))
    deleteResource "secret" "management-operations" "ibm-management-pull-secret" "true" 300
    result=$(( result + $? ))
    deleteResource "secret" "openshift-operators" "ibm-management-pull-secret" "true" 300
    result=$(( result + $? ))
    deleteResource "secret" "kube-system" "ibm-management-pull-secret" "true" 300
    result=$(( result + $? ))
    #deleteCRDs
    #result=$(( result + $? ))
    if [[ "${result}" -ne 0 ]]; then
	return 1
	echo "Did not successfully complete postUninstallCleanup" | tee -a "$logpath"
    else
	echo "Successfully completed postUninstallCleanup" | tee -a "$logpath"
	return 0
    fi
}

secretConfigmapFunc() {
    deleteRoute
    local result=$?
    deleteSecrets
    result=$(( result + $? ))
    deleteResource "secret" "ibmcloud-cluster-ca-cert" "kube-public"
    result=$(( result + $? ))
    deleteResource "configmap" "ibmcloud-cluster-info" "kube-public"
    result=$(( result + $? ))
    deleteResource "secret" "management-monitoring" "ibm-management-pull-secret" "true" 300
    result=$(( result + $? ))
    deleteResource "secret" "management-infrastructure-management" "ibm-management-pull-secret" "true" 300
    result=$(( result + $? ))
    deleteResource "secret" "management-security-services" "ibm-management-pull-secret" "true" 300
    result=$(( result + $? ))
    deleteResource "secret" "management-operations" "ibm-management-pull-secret" "true" 300
    result=$(( result + $? ))
    deleteResource "secret" "openshift-operators" "ibm-management-pull-secret" "true" 300
    result=$(( result + $? ))
    deleteResource "secret" "kube-system" "ibm-management-pull-secret" "true" 300
    result=$(( result + $? ))
    if [[ "${result}" -ne 0 ]]; then
	return 1
	echo "Did not successfully complete secretConfigmapCleanup" | tee -a "$logpath"
    else
	echo "Successfully completed secretConfigmapCleanup" | tee -a "$logpath"
	return 0
    fi
}

# end post uninstall stuff

main(){
    echo "Executing $0; logs available at $logpath"
    validate
    case "${mode}" in
	"preUninstallCleanup")
	    preUninstallFunc; exit $? ;;
	"postUninstallCleanup")
	    postUninstallFunc; exit $? ;;
	"secretConfigmapCleanup")
	    secretConfigmapFunc; exit $? ;;
	"customResourceCleanup")
	    removeParticularCR "${operator}"; exit $? ;;	
	"anyResourceCleanup")
	    deleteResource "${resKind}" "${resNamespace}" "${resName}"; exit $? ;;
	*)
	    echo "Validation should have prevented getting this far! Error!"
	    exit 1 ;;
    esac
}

parse_args "$@"

main
