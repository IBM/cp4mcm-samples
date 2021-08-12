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

V_FALSE=FALSE
IS_MONITORING_NAMESPACE_ENABLED=$(IsNamespaceEnabled "management-monitoring")
IS_COMMON_SERVICES_NAMESPACE_ENABLED=$(IsNamespaceEnabled "ibm-common-services")

#Adding labels to the required resources
sh ./add-label-to-resources.sh

# Creating mongo dump for common services
if [ "$IS_COMMON_SERVICES_NAMESPACE_ENABLED" = "$V_FALSE" ]; then
    echo Namespace [ibm-common-services] is not enabled, hence skipping creating mongo dump for common services
else
    echo Namespace [ibm-common-services] is enabled, hence proceeding further for creating mongo dump for common services
    sh cs/create-mongo-dump.sh
fi

# Add annotion to pod
sh ./add-annotation-to-pod.sh

# Remove annotation from PVC
sh ./remove-annotation-from-pvc.sh

# Pre backup task for monitoring
if [ "$IS_MONITORING_NAMESPACE_ENABLED" = "$V_FALSE" ]; then
    echo Namespace [management-monitoring] is not enabled, hence skipping performing prereqs for Monitoring

else
    echo Namespace [management-monitoring] is enabled, hence proceeding further for performing prereqs for Monitoring
    sh monitoring/monitoring-prereqs.sh
fi

# Trigger backup
sh ./trigger-backup.sh

# Post backup task for monitoring
if [ "$IS_MONITORING_NAMESPACE_ENABLED" = "$V_FALSE" ]; then
    echo Namespace [management-monitoring] is not enabled, hence skipping performing post backup task for monitoring

else
    echo Namespace [management-monitoring] is enabled, hence proceeding further for performing post backup task for monitoring
    sh monitoring/monitoring-post-backup-task.sh
fi
