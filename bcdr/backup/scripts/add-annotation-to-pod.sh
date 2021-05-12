#!/bin/bash  

#--------------------------------------------------------------------------
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corporation 2019.
#
# US Government Users Restricted Rights - Use, duplication or disclosure
# restricted by GSA ADP Schedule Contract with IBM Corporation.
#--------------------------------------------------------------------------

DETAILS=$(cat pod-annotation-details.json | jq '.details')  
LENGTH=$(echo $DETAILS | jq '. | length') 
INDEX=0
EXECUTES_COMMAND_COUNT=0

# Iterating over JSON
while [ $INDEX -lt $LENGTH ]
do
  # Computing Namespace, Pod & Volume
  namespace=$(echo $DETAILS | jq -r --arg index $INDEX '.[$index | tonumber].namespace')
  pod=$(echo $DETAILS | jq -r --arg index $INDEX '.[$index | tonumber].pod')
  volume=$(echo $DETAILS | jq -r --arg index $INDEX '.[$index | tonumber].volume')
    
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
    sleep 5s
  done
    
  # Logging
  echo "-----"

  # Incrementing Index
  INDEX=$((INDEX+1))
done

# Logging Count
echo "Total commands executed: $EXECUTES_COMMAND_COUNT" 