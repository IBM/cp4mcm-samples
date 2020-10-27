#!/bin/bash

ISSUER_NS=open-cluster-management-issuer
CS_NS=ibm-common-services
ISSUER_SECRET=cs-ca-certificate-secret
INTERVAL=5
TESTCOUNT=720

r=`kubectl -n $ISSUER_NS get secret ${ISSUER_SECRET} 2>/dev/null | grep $ISSUER_SECRET`
if [ ! -z "$r" ]; then
  echo "secret already exist."
  exit 0
fi

echo "Waiting for secret $ISSUER_SECRET to be created"
while [[ -z "$result" && !( $TESTCOUNT == 0 ) ]]
do
  sleep $INTERVAL
  result=`kubectl get secret ${ISSUER_SECRET} -n $CS_NS 2>/dev/null |grep -v NAME`
  TESTCOUNT=$(( $TESTCOUNT - 1 ))
  printf "."
done

echo " "

if [ -z "$result" ];then
  echo "Timeout, failed to create issuer secret $ISSUER_SECRET in namespace $ISSUER_NS."
  exit 1
fi

kubectl create ns ${ISSUER_NS} 2>/dev/null
kubectl -n $CS_NS get secret ${ISSUER_SECRET} -o yaml --export| kubectl apply -n $ISSUER_NS -f -

echo "issuer secret $ISSUER_SECRET created successfully."
