#!/bin/bash

#--------------------------------------------------------------------------
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corporation 2019.
#
# US Government Users Restricted Rights - Use, duplication or disclosure
# restricted by GSA ADP Schedule Contract with IBM Corporation.
#--------------------------------------------------------------------------

BASEDIR=$(dirname "$0")

# Defining variables  
  DETAILS=$(cat $BASEDIR/resource-label-details.json)  
  length=$(echo $DETAILS | jq '. | length') 
  index=0

  # Iterating over JSON
  while [ $index -lt $length ]
  do
    # Computing resourceType, resourceName, labels & namespace
    resourceType=$(echo $DETAILS | jq -r --arg index $index '.[$index | tonumber].resourceType')
    resourceName=$(echo $DETAILS | jq -r --arg index $index '.[$index | tonumber].resourceName')
    labels=$(echo $DETAILS | jq -r --arg index $index '.[$index | tonumber].labels' | jq -r .[])
    namespace=$(echo $DETAILS | jq -r --arg index $index '.[$index | tonumber].namespace')
 
    # Logging Index & Details 
    echo "Looping over index: $index"
    echo ResourceType: $resourceType, ResourceName: $resourceName, Labels: $labels, Namespace: $namespace

    for label in $labels
    do
      # Creating label add command based on cluster wide or namespace specifc resource   
      if [[ "$namespace" == '' ]]; then
        echo "Inside cluster wide resources block"
        # Logging label 
        echo "Label: $label"
        command="kubectl label $resourceType $resourceName $label --overwrite=true"
        echo $command
      else
        echo "Inside namespace specific resource block"
        # Logging label 
        echo "Label: $label"
        command="kubectl label $resourceType $resourceName -n $namespace $label --overwrite=true"
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
      sleep 2s
    done
 
  # Incrementing Index
  index=$((index+1))
  done