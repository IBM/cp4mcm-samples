#!/bin/bash

#--------------------------------------------------------------------------
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corporation 2019.
#
# US Government Users Restricted Rights - Use, duplication or disclosure
# restricted by GSA ADP Schedule Contract with IBM Corporation.
#--------------------------------------------------------------------------

# Retrieving list of enabled namespaces
ENABLED_NAMESPACES=$(cat enabled-namespaces.json | jq -r '.[]')

IsNamespaceEnabled() {
    namespaceToBeVerify=$1
    isNamespaceEnabled=FALSE

    for namespace in $ENABLED_NAMESPACES; do
        if [ "$namespace" = "$namespaceToBeVerify" ]; then
            isNamespaceEnabled=TRUE
            break
        fi
    done

    # Check for global or all namespaces.
    if [[ "$namespaceToBeVerify" == '' ]]; then
        isNamespaceEnabled=TRUE
    fi

    echo $isNamespaceEnabled
}
