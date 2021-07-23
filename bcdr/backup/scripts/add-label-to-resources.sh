#!/bin/bash

#--------------------------------------------------------------------------
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corporation 2019.
#
# US Government Users Restricted Rights - Use, duplication or disclosure
# restricted by GSA ADP Schedule Contract with IBM Corporation.
#--------------------------------------------------------------------------

source utils.sh

basedir=$(dirname "$0")
V_FALSE=FALSE

# Function for retriving the list of the resources by using partial resource name
getResourceList() {

  resourceType=$1
  resourceName=$2
  namespace=$3

  {
    # TRY
    if [[ "$resourceType" == 'pod' ]] || [[ "$resourceType" == 'pvc' ]]; then
      resourceList=$(kubectl get $resourceType -n $namespace | grep $resourceName | cut -d " " -f1)
    else
      resourceList=$resourceName
    fi
    # Logging resourceList
    echo "resourceList: $resourceList"
  } || {
    # CATCH
    echo "Error occured, Hence retrying once"
    if [[ "$resourceType" == 'pod' ]] || [[ "$resourceType" == 'pvc' ]]; then
      resourceList=$(kubectl get $resourceType -n $namespace | grep $resourceName | cut -d " " -f1)
    else
      resourceList=$resourceName
    fi
    # Logging resourceList
    echo "resourceList: $resourceList"
  }

}

# Defining variables
details=$(cat $basedir/resource-label-details.json)
length=$(echo $details | jq '. | length')
index=0

# Iterating over JSON
while [ $index -lt $length ]; do
  # Computing resourceType, resourceName, labels & namespace
  resourceType=$(echo $details | jq -r --arg index $index '.[$index | tonumber].resourceType')
  resourceName=$(echo $details | jq -r --arg index $index '.[$index | tonumber].resourceName')
  labels=$(echo $details | jq -r --arg index $index '.[$index | tonumber].labels' | jq -r .[])
  namespace=$(echo $details | jq -r --arg index $index '.[$index | tonumber].namespace')

  # Check if namespace is enabled or not
  isNamespaceEnabled=$(IsNamespaceEnabled $namespace)
  if [ "$isNamespaceEnabled" = "$V_FALSE" ]; then
      # Incrementing Index
      index=$((index + 1))
      
      echo Namespace [$namespace] is not enabled, hence skipping adding label to a $resourceType $resourceName
      continue
  else
      echo Namespace [$namespace] is enabled, hence proceeding further for adding label to a $resourceType $resourceName    
  fi

  # Logging index & details
  echo "Looping over index: $index"
  echo ResourceType: $resourceType, ResourceName: $resourceName, Labels: $labels, Namespace: $namespace

  # Retriving the list of the resources that's need to be labeled
  getResourceList $resourceType $resourceName $namespace

  for resource in $resourceList; do

    # Creating label add command based on cluster wide or namespace specifc resource
    if [[ "$namespace" == '' ]]; then
      echo "Inside cluster wide resources block"
      # Logging labels
      echo "Labels: $labels"
      command="kubectl label $resourceType $resource $labels --overwrite=true"
      echo $command
    else
      echo "Inside namespace specific resource block"
      # Logging labels
      echo "Labels: $labels"
      command="kubectl label $resourceType $resource -n $namespace $labels --overwrite=true"
      echo $command
    fi

    # Execute command
    {
      # TRY
      $(echo $command)
    } || {
      # CATCH
      echo "Error occured, Hence retrying once"
      $(echo $command)
    }
    
    # Sleep for some time
    sleep 1s

  done

  # Incrementing Index
  index=$((index + 1))
done
