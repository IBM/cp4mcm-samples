#!/bin/sh
# ****************************************************************************
# * Licensed Materials - Property of IBM
# *
# * Copyright IBM Corporation 2016-2019 All Rights Reserved
# *
# *****************************************************************************

PLUGIN=blockchain
TLSFULL=ibp-tls-certs.tar

handle_required() {
   answer=""
   while [ -z "$answer" ]; do
      printf "$1: "
      read answer
      if [ -z "$answer" ]; then
         printf "Value must be specified for required property!\n"
         continue
      fi
      break
   done
}

printf "Please input the full path including the certificates exported from your blockchain nodes\n"

while true; do
   handle_required "Enter the full path where the bulk zip is located"
   if [ "${answer:0:1}" != "/" ]; then
      continue
   fi
   if [ -d ${answer} ]; then
      count=`ls -l ${answer}/*.zip 2>&1 | grep -v ^ls: | wc -l`
      if [ ${count} -ne 1 ]; then
         printf "Re-enter the path and ensure that there is only one bulk zip in the path.\n"
         continue
      fi

      rm -rf ${answer}/tmp
      rm -rf ${answer}/bulk
      mkdir ${answer}/tmp
      mkdir ${answer}/bulk
      unzip ${answer}/*.zip -d ${answer}/tmp > /dev/null 2>&1
      cp ${answer}/tmp/*/*_orderer.json ${answer}/bulk > /dev/null 2>&1
      cp ${answer}/tmp/*/*_peer.json ${answer}/bulk > /dev/null 2>&1
      cp ${answer}/tmp/*/tls_*_identity.json ${answer}/bulk > /dev/null 2>&1
      cp ${answer}/tmp/*.json ${answer}/bulk > /dev/null 2>&1

      count=`ls -l ${answer}/bulk/*.json 2>&1 | grep -v ^ls: | wc -l`
      if [ ${count} -lt 2 ]; then
         printf "Not enough json files to access blockchain nodes.\n"
         continue
      fi
      tar cf ${TLSFULL} -C ${answer}/bulk . > /dev/null 2>&1
      break
   else
      printf "\nThe path does not exist. Make sure the path is correct and try again.\n"
      continue
   fi
done
   printf "\nConfiguration of blockchain plugin is completed.\n\n\n"
