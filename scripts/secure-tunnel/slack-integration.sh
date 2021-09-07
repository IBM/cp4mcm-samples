#!/bin/bash

RED='\033[0;31m'
Green='\033[0;32m'
NC='\033[0m'
AIOPS_INSTANCE_NAMESPACE=cp4waiops
PORT_FORWARDING_NAMESPACE=aiops-port-forwarding
PULL_SECRET_NAME=tunnel-connector-image-pull-secret
RETRIES=60

usage() {
   cat<<EOF
   Before run this script make sure you have installed the oc and jq command line interface (CLI).

--aiops-cluster-login-string,               the AIOps cluster Log in string.
--target-openshift-cluster-login-string,    the target OpenShift cluster log in string. It is used to create the Application mapping(port-forwarding) of the IBM Cloud Pak for Watson AIOps instance URL.
--aiops-instance-namespace,                 the namespace of the IBM Cloud Pak for Watson AIOps instance in the AIOps cluster, by default it's cp4waiops.
--port-forwarding-namespace,                the namespace of the Application mapping(port-forwarding) in the target Openshift cluste, by default it's aiops-port-forwarding.
--docker-registry-username,                 the username of the Tunnel connector image pull secret
--docker-registry-password,                 the password of the Tunnel connector image pull secret
--https-proxy,                              if your AIOps cluster is in a airgap environment and it cannot access the public network in the cluster
                                            you can set a HTTPS_PROXY server for the Tunnel 
                                            then the Tunnel server with connect with the Tunnel connector by using the HTTPS_PROXY server
-h, --help,                                 for help

For example:
EOF
echo "${0}  --aiops-cluster-login-string \"oc login --token=<cluster API token> --server=<cluster API server>\" \\"
echo "--target-openshift-cluster-login-string \"oc login --token=<cluster API token> --server=<cluster API server>\" \\"
echo "--aiops-instance-namespace cp4waiops \\"
echo "--port-forwarding-namespace aiops-port-forwarding \\"
echo "--docker-registry-username <the docker registry cp.icr.io username> \\"
echo "--docker-registry-password <the docker registry cp.icr.io password>"
}

prereqs=(oc jq)
for prereq in "${prereqs[@]}"; do
    command -v "$prereq" >/dev/null 2>&1 || {
        printf "${RED}${prereq} pre-req is missing${NC}\n"
        usage
        exit 1
    }
done

while true ; do
    case "$1" in
        --aiops-cluster-login-string) 
            AIOPS_CLUSTER_LOGIN_STRING=$2
            if [ "$2" == "" ]; 
            then
                usage
                exit 1
            fi
            shift 2 ;;
        --target-openshift-cluster-login-string)
            PUBLIC_OPENSHIFT_CLUSTER_LOGIN_STRING=$2
            if [ "$2" == "" ]; 
            then
                usage
                exit 1
            fi
            shift 2 ;;
        --aiops-instance-namespace) 
            AIOPS_INSTANCE_NAMESPACE=$2
            if [ "$2" == "" ]; 
            then
                usage
                exit 1
            fi
            shift 2 ;;
        --port-forwarding-namespace)
            PORT_FORWARDING_NAMESPACE=$2
            if [ "$2" == "" ]; 
            then
                usage
                exit 1
            fi
            shift 2 ;;
        --docker-registry-username)
            DOCKER_REGISTRY_USERNAME=$2
            if [ "$2" == "" ]; 
            then
                usage
                exit 1
            fi
            shift 2 ;;
        --docker-registry-password)
            DOCKER_REGISTRY_PASSWORD=$2
            if [ "$2" == "" ]; 
            then
                usage
                exit 1
            fi
            shift 2 ;;
        --https-proxy)
            HTTPS_PROXY=$2
            if [ "$2" == "" ]; 
            then
                usage
                exit 1
            fi
            shift 2 ;;
        --help)
            usage
            exit 0 
            ;;
        -h)
            usage
            exit 0 
            ;;
        *)
            if [ "$1" != "" ]; 
            then
                usage
                exit 1
            fi
            break
            ;;
    esac
done

login_aiops() {
    echo "Start login to the AIOps cluster..."
    echo y | ${AIOPS_CLUSTER_LOGIN_STRING} --insecure-skip-tls-verify=true
    RET=$?
    if [ "${RET}" != "0" ];
    then
        echo "Error: login to the AIOps cluster failed."
        usage
        exit ${RET}
    fi
    echo "login to the AIOps cluster successful."
    echo
}
login_public_cluster() {
    echo "Start login to the target openshift cluster..."
    echo y | ${PUBLIC_OPENSHIFT_CLUSTER_LOGIN_STRING} --insecure-skip-tls-verify=true
    RET=$?
    if [ "${RET}" != "0" ];
    then
        echo "Error: login to the target openshift cluster failed."
        usage
        exit ${RET}
    fi
    echo "login to the target openshift cluster successful."
    echo
}

echo "Check if the target Openshift cluster can be logged in ..."
login_public_cluster
PUBLIC_HOSTNAME=`oc get route -n openshift-console console -o=jsonpath={.spec.host}`
PUBLIC_HOSTNAME=${PUBLIC_HOSTNAME#console-openshift-console.}
echo "target Openshift cluster domain="${PUBLIC_HOSTNAME}

echo
echo "Check if the AIOps cluster can be logged in ..."
login_aiops

AIOPS_INSTANCE_ID=`oc -n ${AIOPS_INSTANCE_NAMESPACE} get configmap aimanager-instance-configmap -o=jsonpath='{.data.instance\.json}' | jq -r ".id"`
if [ "${AIOPS_INSTANCE_ID}" == "" ]; then
    echo
    echo "Error: get the IBM Cloud Pak for Watson AIOps instance id failed."
    echo "       Please make sure that the AIOps namespace ${AIOPS_INSTANCE_NAMESPACE} is correct."
    echo 1
fi
AIOPS_DISPLAY_NAME=`oc -n ${AIOPS_INSTANCE_NAMESPACE} get configmap aimanager-instance-configmap -o=jsonpath='{.data.instance\.json}' | jq -r ".display_name"`
if [ "${AIOPS_DISPLAY_NAME}" == "" ]; then
    echo
    echo "Error: get the IBM Cloud Pak for Watson AIOps instance display_name failed."
    echo "       Please make sure that the AIOps namespace ${AIOPS_INSTANCE_NAMESPACE} is correct."
    echo 1
fi
COUNT=`oc -n ${AIOPS_INSTANCE_NAMESPACE} get service ibm-nginx-svc | grep ibm-nginx-svc | wc -l`
if [ "${COUNT}" != "1" ]; then
    echo
    echo "cannot find the IBM Cloud Pak for Watson AIOps k8s service in the namespace ${AIOPS_INSTANCE_NAMESPACE}."
    exit 1
fi

## Enable Tunnel server in the AIOps cluster
for name in `oc -n ${AIOPS_INSTANCE_NAMESPACE} get installation.orchestrator.aiops.ibm.com | awk '{print $1}'`; do
    if [ "$name" != "NAME" ]; then
        AIOPS_NAME=$name
    fi
done

if [ "${AIOPS_NAME}" == "" ]; then
    echo "Error: cannot find the aiops installation in this namespace, please install the aiops to this namespace first or change a namespace."
    exit 1
fi
COUNT=`oc -n ${AIOPS_INSTANCE_NAMESPACE} get pod | grep sre-tunnel-controller | wc -l`
if [ "${COUNT}" == "0" ]; then
    echo "Error: please enable the secure tunnel first."
    exit 1
fi

##############
echo "Create a Tunnel Connection for the IBM Cloud Pak for Watson AIOps instance."
oc -n  ${AIOPS_INSTANCE_NAMESPACE} --ignore-not-found=true delete Application slack-integration-aiops
oc -n  ${AIOPS_INSTANCE_NAMESPACE} --ignore-not-found=true delete TunnelConnection slack-integration
ACCOUNT_ID=`oc whoami`



## Create a Tunnel connection for the IBM Cloud Pak for Watson AIOps instance with the Tunnel CR.
cat <<EOF | kubectl -n ${AIOPS_INSTANCE_NAMESPACE} apply -f -
apiVersion: tunnel.management.ibm.com/v1
kind: TunnelConnection
metadata:
  name: slack-integration
spec:
  reverse: true
  installConnectorToVM: false
  allowedList:
    - allow ibm-nginx-svc 443
  accountID: "${ACCOUNT_ID}"
  connectorReplicas: 1
  creator: "${ACCOUNT_ID}"
  proxy:
    httpsProxy: "${HTTPS_PROXY}"
  connectorDomain: '${PUBLIC_HOSTNAME}'
  workerReplicas: 1
  tunnelWorkerResources:
    limits:
      cpu: ''
      memory: ''
    requests:
      cpu: ''
      memory: ''
  labels: slack=true
EOF
echo


## Create a IBM Cloud Pak for Watson AIOps instance port-forwarding with the Tunnel CR.
echo
echo "Create a Tunnel port-forwarding for the IBM Cloud Pak for Watson AIOps instance."
cat <<EOF | kubectl -n ${AIOPS_INSTANCE_NAMESPACE} apply -f -
apiVersion: tunnel.management.ibm.com/v1
kind: Application
metadata:
  name: slack-integration-aiops
  labels:
    tunnelNetworkName: slack-integration
spec:
  networkPolicy: ''
  applicationPorts:
    - 443
  applicationHostOrIP: ibm-nginx-svc
  accountID: "${ACCOUNT_ID}"
  connectionName: slack-integration
  name: aiops
  creator: "${ACCOUNT_ID}"
  accessOutCluster: false
  accessInCluster: true
  exposeConnectorSideService2Worker: false
  labels: slack=true
EOF
echo





## Obtain the Tunnel connector intall scripts.
echo
echo "Waiting for Tunnel Connection created successful."
TUNNEL_CONNECTION_ID=`kubectl -n ${AIOPS_INSTANCE_NAMESPACE} --ignore-not-found=true get TunnelConnections slack-integration -o=jsonpath='{.status.id}'`
retries=${RETRIES}
while [ "${TUNNEL_CONNECTION_ID}" == "" ]; do
    sleep 5
    retries=$((retries - 1))
    if [[ $retries == 0 ]]; then
        echo "Error: create Tunnel Connection failed."
        exit 1
    fi
    echo "retrying..."
    TUNNEL_CONNECTION_ID=`kubectl -n ${AIOPS_INSTANCE_NAMESPACE} --ignore-not-found=true get TunnelConnections slack-integration -o=jsonpath='{.status.id}'`
done
echo "Tunnel Connection created successful TUNNEL_CONNECTION_ID=${TUNNEL_CONNECTION_ID}."
echo

echo "Waiting for Tunnel Application(port-forwarding) created successful."
TUNNEL_APPLICATION_ID=`kubectl -n ${AIOPS_INSTANCE_NAMESPACE} --ignore-not-found=true get Applications slack-integration-aiops -o=jsonpath='{.status.id}'`
retries=${RETRIES}
while [ "${TUNNEL_APPLICATION_ID}" == "" ]; do
    sleep 5
    retries=$((retries - 1))
    if [[ $retries == 0 ]]; then
        echo "Error: create Tunnel Application(port-forwarding) failed."
        exit 1
    fi
    echo "retrying..."
    TUNNEL_APPLICATION_ID=`kubectl -n ${AIOPS_INSTANCE_NAMESPACE} --ignore-not-found=true get Applications slack-integration-aiops -o=jsonpath='{.status.id}'`
done
echo "Tunnel Application(port-forwarding) created successful TUNNEL_APPLICATION_ID=${TUNNEL_APPLICATION_ID}."
echo

echo "Waiting for Tunnel worker pod ready."
READY=`kubectl -n ${AIOPS_INSTANCE_NAMESPACE} --ignore-not-found=true get pod | grep ${TUNNEL_CONNECTION_ID}-0 | awk '{print $2}'`
retries=${RETRIES}
while [ "${READY}" != "1/1" ]; do
    sleep 5
    retries=$((retries - 1))
    if [[ $retries == 0 ]]; then
        echo "Error: create Tunnel worker pod start failed."
        exit 1
    fi
    echo "retrying..."
    READY=`kubectl -n ${AIOPS_INSTANCE_NAMESPACE} --ignore-not-found=true get pod | grep ${TUNNEL_CONNECTION_ID}-0 | awk '{print $2}'`
done
POD_NAME=`kubectl -n ${AIOPS_INSTANCE_NAMESPACE} get pod | grep ${TUNNEL_CONNECTION_ID}-0 | awk '{print $1}'`
echo "Tunnel worker pod: ${POD_NAME} started successful."
echo

echo "Getting tunnel client install script..."
kubectl -n ${AIOPS_INSTANCE_NAMESPACE} cp ${POD_NAME}:opt/ibm/data/download/tunnel-connector-install-scripts.tar.gz /tmp/tunnel-connector-install-scripts.tar.gz
retries=${RETRIES}
while [ ! -f /tmp/tunnel-connector-install-scripts.tar.gz ]; do
    sleep 5
    retries=$((retries - 1))
    if [[ $retries == 0 ]]; then
        echo "Error: Getting tunnel connctor install script failed"
        exit 1
    fi
    echo "retrying..."
    kubectl -n ${AIOPS_INSTANCE_NAMESPACE} cp ${POD_NAME}:opt/ibm/data/download/tunnel-connector-install-scripts.tar.gz /tmp/tunnel-connector-install-scripts.tar.gz
done
tar zxf /tmp/tunnel-connector-install-scripts.tar.gz -C /tmp
RET=$?
rm -rf /tmp/tunnel-connector-install-scripts.tar.gz
if [ "${RET}" != "0" ];
then
    echo "Error: /tmp/tunnel-connector-install-scripts.tar.gz format error."
    echo ${RET}
fi
cd /tmp/tunnel-connector-install-scripts
echo "Get tunnel connector install script successful"
echo





## Install Tunnel connector to the target Openshift cluster."
echo
login_public_cluster
COUNT=`oc --ignore-not-found=true get ns ${PORT_FORWARDING_NAMESPACE} | grep ${PORT_FORWARDING_NAMESPACE} | wc -l`
if [ "${COUNT}" != "1" ]; then
    echo "the namespace ${PORT_FORWARDING_NAMESPACE} in the target OpenShift cluster does not exist, will create it"
    oc create ns ${PORT_FORWARDING_NAMESPACE}
    RET=$?
    if [ "${RET}" != "0" ]; then
        echo "Error: Create the namespace: ${PORT_FORWARDING_NAMESPACE} failed."
        echo ${RET}
    fi
fi

if [ "${DOCKER_REGISTRY_USERNAME}" == "" -o "${DOCKER_REGISTRY_PASSWORD}" == "" ]; then
    echo "Error: the docker registry username or password is empty."
    exit 1
fi
COUNT=`oc -n ${PORT_FORWARDING_NAMESPACE} --ignore-not-found=true get secret ${PULL_SECRET_NAME} | grep ${PULL_SECRET_NAME} | wc -l`
if [ "${COUNT}" == "1" ]; then
    echo "the docker image pull secret: ${PULL_SECRET_NAME} already exists, will delete and re-create it."
    oc -n ${PORT_FORWARDING_NAMESPACE} delete secret ${PULL_SECRET_NAME}
fi

if [ "${DOCKER_IMAGE_NAME}" == "" ]; then
    DOCKER_IMAGE_NAME=`cat image.txt`
fi
echo "Tunnel connector docker image name=${DOCKER_IMAGE_NAME}"
ENTITLED_REGISTRY=`echo ${DOCKER_IMAGE_NAME} | awk -F/ '{print $1}'`
echo "Start create the docker image pull secret for docker registry: ${ENTITLED_REGISTRY}..."
oc create secret docker-registry ${PULL_SECRET_NAME} \
--docker-username=${DOCKER_REGISTRY_USERNAME} \
--docker-password=${DOCKER_REGISTRY_PASSWORD} \
--docker-server=${ENTITLED_REGISTRY} \
-n ${PORT_FORWARDING_NAMESPACE}
RET=$?
if [ "${RET}" != "0" ];
then
    echo "Error: Create the docker image pull secret for docker registry: ${ENTITLED_REGISTRY} failed."
    echo ${RET}
fi
echo "Create the docker image pull secret for docker registry: ${ENTITLED_REGISTRY} successful"
echo

echo "Start install the Tunnel connector to the target openshift cluster..."
./install-openshift.sh  \
--namespace ${PORT_FORWARDING_NAMESPACE}  \
--accept-license true \
--image-pull-secret ${PULL_SECRET_NAME} \
--image ${DOCKER_IMAGE_NAME}
RET=$?
if [ "${RET}" != "0" ];
then
    echo "Error: install the Tunnel connector to the target openshift cluster failed."
    echo ${RET}
fi
echo "Install the Tunnel connector to the target openshift cluster successful."
echo


## Obtain the port-forwarding URL of the IBM Cloud Pak for Watson AIOps instance.
ROUTE_NAME=`oc -n ${PORT_FORWARDING_NAMESPACE} get route | grep ${TUNNEL_APPLICATION_ID}-aiops-portforward | awk '{print $1}'`
AIOPS_PORT_FORWARDING_HOSTNAME=`oc -n ${PORT_FORWARDING_NAMESPACE} get route ${ROUTE_NAME} -o=jsonpath={.spec.host}`
if [ "${AIOPS_PORT_FORWARDING_HOSTNAME}" == "" ];
then
    echo "Error: get the IBM Cloud Pak for Watson AIOps instance port-forwarding URL failed."
    echo ${RET}
fi
echo
echo "================================"
printf "The IBM Cloud Pak for Watson AIOps instance port-forwarding URL is:\n${Green}https://"${AIOPS_PORT_FORWARDING_HOSTNAME}/aiops/${AIOPS_DISPLAY_NAME}/instances/${AIOPS_INSTANCE_ID}/api/slack/events${NC}"\n"
