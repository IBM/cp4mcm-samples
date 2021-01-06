#!/bin/bash

# Dependencies:
# 1. bash
# 2. OSX due to nature of sed commands
# 3. oc or kubectl
# 4. an openshift cluster on which cp4mcm is currently installed, or was recently uninstalled

# Pass in your policy to the script, or edit these variables
POLICYFILENAME=$1
NAMESPACE=$2

#####
# Policy File
#####

echo "getting your policy"
oc get policy $POLICYFILENAME-namespace -n $NAMESPACE -o yaml > newPolicy.yaml
#cat $POLICYFILENAME.yaml > newPolicy.yaml

echo "update apiVersion"
sed -i '' "s|policy.mcm.ibm.com/v1alpha1|policy.open-cluster-management.io/v1|g" newPolicy.yaml

echo "remove temporary policy values"
sed -i '' "/creationTimestamp/d" newPolicy.yaml
sed -i '' "/uid/d" newPolicy.yaml
sed -i '' "/resourceVersion/d" newPolicy.yaml

echo "update annotations section with new fields"
sed -i '' "s|policy.mcm.ibm.com/categories|policy.open-cluster-management.io/categories|g" newPolicy.yaml
sed -i '' "s|policy.mcm.ibm.com/controls|policy.open-cluster-management.io/controls|g" newPolicy.yaml
sed -i '' "s|policy.mcm.ibm.com/standards|policy.open-cluster-management.io/standards|g" newPolicy.yaml

echo "remove seed-generation from annotations"
sed -i '' "/seed-generation/d" newPolicy.yaml

echo "your updated policy is at newPolicy.yaml"

#####
# Policy Binding
#####

echo "getting policy binding"
oc get placementbinding binding-$POLICYFILENAME-namespace -n $NAMESPACE -o yaml > newBinding.yaml
#cat binding-$POLICYFILENAME-namespace.yaml > newBinding.yaml

echo "update apiVersion"
sed -i '' "s|mcm.ibm.com/v1alpha1|policy.open-cluster-management.io/v1|g" newBinding.yaml

echo "update kinds"
sed -i '' "s|PlacementPolicy|PlacementRule|g" newBinding.yaml

echo "update apiGroups"
sed -i '' "s|policy.mcm.ibm.com|policy.open-cluster-management.io|g" newBinding.yaml
sed -i '' "s|mcm.ibm.com|apps.open-cluster-management.io/v1|g" newBinding.yaml

echo "your updated binding is at newBinding.yaml"

#####
# PlacementPolicy -> PlacementRule
#####

echo "getting placement policy"
oc get placementpolicy placement-$POLICYFILENAME-namespace -n $NAMESPACE -o yaml > newPlacementRule.yaml
#cat placement-$POLICYFILENAME-namespace.yaml > newPlacementRule.yaml

echo "update apiVersion"
sed -i '' "s|mcm.ibm.com/v1alpha1|apps.open-cluster-management.io/v1|g" newPlacementRule.yaml

echo "update kinds"
sed -i '' "s|PlacementPolicy|PlacementRule|g" newPlacementRule.yaml

echo "your placement policy is at newPlacementRule.yaml"