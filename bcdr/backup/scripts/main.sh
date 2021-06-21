#!/bin/bash

#--------------------------------------------------------------------------
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corporation 2019.
#
# US Government Users Restricted Rights - Use, duplication or disclosure
# restricted by GSA ADP Schedule Contract with IBM Corporation.
#--------------------------------------------------------------------------

#Adding labels to the required resources
sh ./add-label-to-resources.sh

# Performing prereqs for monitoring
sh monitoring/monitoring-prereqs.sh

# Creating mongo dump for common services
sh cs/create-mongo-dump.sh

# Add annotion to pod
sh ./add-annotation-to-pod.sh

# Trigger backup
sh ./trigger-backup.sh

# Post backup task for monitoring
sh monitoring/monitoring-post-backup-task.sh
