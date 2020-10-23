#!/bin/bash 

namespaces=()
since=24h

usage() {
    echo "A script to collect logs from your namespace for delivery to IBM Support." 1>&2;
    echo "" 1>&2;
    echo "Usage:" 1>&2;
    echo "  $0 <namespace> -s=<timespan>" 1>&2;
    echo "" 2>&1;
    echo "  List of namepace(s) for which to collect logs (required). <namespace> <namespace> ..." 2>&1;
    echo "  -s timespan of logs to collect. Default is 24h." 2>&1;
    echo "" 2>&1;
    echo "" 2>&1;
    echo "" 2>&1;
    exit 1;
}

collectDiagnosticsData() {
    echo "******************************* diagnostics data collected on ${diagnostic_collection_date} for the following namespace(s) *******************************"
    echo -e "\n"
    for namespace in "${namespaces[@]}"
    do
        echo "$namespace"
    done
    echo -e "\n"

    echo "**********************************************************"
    echo "GET Persistent Volumes"
    echo "**********************************************************"
    oc get persistentvolume
    echo -e "\n"

    for namespace in "${namespaces[@]}"
    do
        echo "**********************************************************"
        echo "GET Persistent Volume Claims in $namespace namespace"
        echo "**********************************************************"
        oc get persistentvolumeclaims --namespace=$namespace
        echo -e "\n"

        echo "**********************************************************"
        echo "DESCRIBE Persistent Volume Claims in $namespace namespace"
        echo "**********************************************************"
        echo -e "\n"

        getPersistentVolumeClaimsResult=$(oc get persistentvolumeclaims --namespace=$namespace --output=name | sed s/"persistentvolumeclaim\/"/""/)
        echo "Running DESCRIBE for the following Persistent Volume Claims"
        echo "-----------------------------------------------------------"
        echo "${getPersistentVolumeClaimsResult}"
        echo -e "\n"

        echo "$getPersistentVolumeClaimsResult" |
        while read persistentVolumeClaim; do
            oc describe persistentvolumeclaims $persistentVolumeClaim --namespace=$namespace
            echo -e "----------------------------------------------------------------\n"
        done
        echo -e "\n"

        echo "**********************************************************"
        echo "GET ConfigMaps in $namespace namespace"
        echo "**********************************************************"
        oc get configmaps --namespace=$namespace
        echo -e "\n"

        echo "**********************************************************"
        echo "GET Pods in $namespace namespace"
        echo "**********************************************************"
        oc get pods --namespace=$namespace
        echo -e "\n"

        echo "**********************************************************"
        echo "GET Pods in $namespace namespace sorted by node"
        echo "**********************************************************"
        oc get pods -o wide --namespace=$namespace  --sort-by=".status.hostIP"
        echo -e "\n"

        getPodsResult=$(oc get pods --namespace=$namespace --output=name | cut -d'/' -f2-)

        getPodCount=$(oc get pods --namespace=$namespace --output=name | wc -l)

        if [ "${getPodCount}" -ne "0" ]; then

            echo "**********************************************************"
            echo "DESCRIBE Pods in $namespace namespace"
            echo "**********************************************************"
            echo -e "\n"

            echo "Running DESCRIBE for the following pods"
            echo "---------------------------------------"
            echo "${getPodsResult}"
            echo -e "\n"

            echo "$getPodsResult" |
            while read podName; do
            oc describe pods $podName --namespace=$namespace
            echo -e "----------------------------------------------------------------\n"
            done
            echo -e "\n"

            echo "**********************************************************"
            echo "Downloading logs from pods in $namespace namespace"
            echo "**********************************************************"
            echo "$getPodsResult" |
            while read podName; do
                echo "Downloading logs from pod ${podName}"
                podContainers=$(oc get pods --namespace=${namespace} ${podName} -o jsonpath='{.spec.containers[*].name}')

                for podContainer in ${podContainers}
                do
                    echo "Downloading logs for container ${podContainer}"
                    # if pod name contains temasda get the log from beginning
                    if [[ ${podName} == *"temasda"* ]]; then
                    oc --namespace=$namespace logs ${podName} -c ${podContainer} >> "${diagnostic_data_folder}/${podName}-podContainer-${podContainer}-$namespace.log"  2>&1
                    else
                    oc --namespace=$namespace logs ${podName} -c ${podContainer} --since ${since} >> "${diagnostic_data_folder}/${podName}-podContainer-${podContainer}-$namespace.log"  2>&1
                    fi
                done

                podInitContainers=$(oc get pods --namespace=${namespace} ${podName} -o jsonpath='{.spec.initContainers[*].name}')

                for podInitContainer in ${podInitContainers}
                do
                    echo "Downloading logs for initContainer ${podInitContainer}"
                    oc --namespace=$namespace logs ${podName} -c ${podInitContainer} >> "${diagnostic_data_folder}/${podName}-podInitContainer-${podInitContainer}-$namespace.log"  2>&1
                done

                echo "Successfully downloaded logs from pod ${podName}"
            done
            echo -e "\n"
        fi

        echo "**********************************************************"
        echo "GET events in $namespace namespace"
        echo "**********************************************************"
        oc get events | grep $namespace
        echo -e "\n"
    done
}

if [[ $1 == "" ]]; then
    usage
fi 

for arg in "$@"
do
    if [[ $arg == "-s="* ]]; then
        since="$(cut -d'=' -f2 <<<"$arg")"
    else
        namespaces+=($arg)
    fi
done

echo "**********************************************************"
echo "Checking for oc"
echo "**********************************************************"

if ! which oc; then
    echo "oc command not found. Ensure that you have oc installed."
    exit 1
fi

diagnostic_collection_date=`date +%Y%m%dT%H%M%SZ`
echo "******************************* diagnostics data collected on ${diagnostic_collection_date} for the following namespace(s) *******************************"
echo ""
for namespace in "${namespaces[@]}"
do
    echo "$namespace"
done
echo -e "\n"

tempFolder="containerLogs"
mkdir ${tempFolder}
diagnostic_data_folder_name="diagnostic_data_${diagnostic_collection_date}"
diagnostic_data_folder="${tempFolder}/${diagnostic_data_folder_name}"
diagnostic_data_log="${diagnostic_data_folder}/diagnostics-data.log"
diagnostic_data_zipped_file="${diagnostic_data_folder}.tgz"
echo "Creating temporary folder ${diagnostic_data_folder}"
if `mkdir ${diagnostic_data_folder}`; then
    echo "Successfully created temporary folder ${diagnostic_data_folder}"
else
    echo "Failed creating temporary folder ${diagnostic_data_folder}"
    exit 1
fi

echo "Collecting Diagnostics data. Please wait...."
collectDiagnosticsData $@ > ${diagnostic_data_log} 2>&1
if [ $? -eq 0 ]; then
    echo "Successfully collected diagnostics data"
else
    echo "Error occurred while trying to collect diagnostics data. Check ${diagnostic_data_log} for details"
    exit 1
fi

echo "Zipping up Diagnostics data from ${diagnostic_data_folder}"
tar cfz ${diagnostic_data_zipped_file} --directory ${tempFolder} ${diagnostic_data_folder_name}
if [ $? -eq 0 ]; then
    echo "Cleaning up temporary folder ${diagnostic_data_folder}"
    rm -rf ${diagnostic_data_folder}
    echo "******************************* Successfully collected and zipped up diagnostics data. *******************************"
    echo "The diagnostics data is available at ${diagnostic_data_zipped_file}"
else
    echo "******************************* Failed to zip up diagnostics data. Diagnostics data folder is available at ${diagnostic_data_folder} *******************************"
fi