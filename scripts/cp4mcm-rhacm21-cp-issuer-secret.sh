#!/bin/bash
  
ACM_ISSUER_NS=open-cluster-management-issuer
CS_NS=ibm-common-services
CS_ISSUER_SECRET=cs-ca-certificate-secret
SECRETSHARE=cert-manager
INTERVAL=5
TESTCOUNT=720

# TODO: oc or kubectl

# Wait for SecretShare to be available
while [[ "$result" -ne 0 && !( $TESTCOUNT == 0 ) ]]
do
  sleep $INTERVAL
  result=`oc get secretshare.ibmcpcs.ibm.com -n $CS_NS &>/dev/null`
  TESTCOUNT=$(( $TESTCOUNT - 1 ))
done

if [[ "$result" -ne 0 ]];then
  echo "Timeout, failed to find secretshare kind. Ensure the IBM Common Services operator has been installed."
  exit 1
fi

echo "Applying SecretShare resource"

cat << EOF | oc apply -f -
apiVersion: ibmcpcs.ibm.com/v1
kind: SecretShare
metadata:
  name: $SECRETSHARE
  namespace: $CS_NS
spec:
  secretshares:
  - secretname: $CS_ISSUER_SECRET
    sharewith:
    - namespace: $ACM_ISSUER_NS
EOF

if [[ "$?" -ne 0 ]];then
        echo "Failed to apply the SecretShare resource"
        exit 1
fi
