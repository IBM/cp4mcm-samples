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

DETAILS=$(cat pod-annotation-details.json | jq '.details')  
LENGTH=$(echo $DETAILS | jq '. | length') 
INDEX=0
EXECUTES_COMMAND_COUNT=0
V_FALSE=FALSE

# Iterating over JSON
while [ $INDEX -lt $LENGTH ]
do
  # Computing Namespace, Pod & Volume
  namespace=$(echo $DETAILS | jq -r --arg index $INDEX '.[$index | tonumber].namespace')
  pod=$(echo $DETAILS | jq -r --arg index $INDEX '.[$index | tonumber].pod')
  volume=$(echo $DETAILS | jq -r --arg index $INDEX '.[$index | tonumber].volume')

  # Check if namespace is enabled or not
  isNamespaceEnabled=$(IsNamespaceEnabled $namespace)
  if [ "$isNamespaceEnabled" = "$V_FALSE" ]; then
      # Incrementing Index
      INDEX=$((INDEX+1))
      
      echo Namespace [$namespace] is not enabled, hence skipping adding annotation to a pod $pod
      continue
  else
      echo Namespace [$namespace] is enabled, hence proceeding further for annotating a pod $pod    
  fi

  # Logging Namespace, Pod & Volume
  echo "-----"
  echo Namespace: $namespace, Pod: $pod, Volume: $volume

  { 
    # TRY
    podList=$(kubectl get pod -n $namespace | grep $pod | cut -d " " -f1)
  } || {
    # CATCH
    echo "Error occured, Hence retrying once"
    podList=$(kubectl get pod -n $namespace | grep $pod | cut -d " " -f1)
  }

  for podName in $podList
  do
    command="kubectl annotate -n $namespace pod/$podName backup.velero.io/backup-volumes=$volume --overwrite=true"

    # Logging Command
    echo Command: $command

    # Execute Command
    { 
      # TRY
      $(echo $command)
    } || {
      # CATCH
      echo "Error occured, Hence retrying once"
      $(echo $command)
    }
    
    # Incrementing Count
    EXECUTES_COMMAND_COUNT=$((EXECUTES_COMMAND_COUNT+1))

    # TODO: Sleep for some time
    sleep 1s
  done
    
  # Logging
  echo "-----"

  # Incrementing Index
  INDEX=$((INDEX+1))
done

# Logging Count
echo "Total commands executed: $EXECUTES_COMMAND_COUNT" 