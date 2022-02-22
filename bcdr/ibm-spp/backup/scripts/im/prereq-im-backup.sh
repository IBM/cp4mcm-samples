#!/bin/bash

# Assigning backup=cp4mcm label to all IM resources which are having label imbackup=t
oc label all -l imbackup=t backup=cp4mcm

# Label missing resources
oc label IMInstall im-iminstall imbackup=t backup=cp4mcm --overwrite -n management-infrastructure-management
oc label pvc postgresql imbackup=t backup=cp4mcm --overwrite -n management-infrastructure-management

# Remove velero annotation from postgresql pvc
postgresqlPodName=$(kubectl get po -n management-infrastructure-management | grep postgresql| cut -d " " -f1)
oc annotate po $postgresqlPodName backup.velero.io/backup-volumes- -n management-infrastructure-management

#Needs to be removed later
# oc label secret -l imbackup=t cfbackup=t backup=cp4mcm --overwrite -n management-infrastructure-management
# oc label cm -l imbackup=t cfbackup=t backup=cp4mcm --overwrite -n management-infrastructure-management
# oc label pvc postgresql cfbackup=t backup=cp4mcm --overwrite -n management-infrastructure-management

