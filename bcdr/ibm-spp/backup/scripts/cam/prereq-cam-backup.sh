#!/bin/bash

# Tagging all required cam resources
oc label pvc cam-mongo-pv appbackup=cam backup=cp4mcm --overwrite=true -n management-infrastructure-management
