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
# Updated Policy Metadata Variables
#####

MEM="  policy-templates:
    - objectDefinition:
        apiVersion: policy.open-cluster-management.io/v1
        kind: ConfigurationPolicy
        metadata:
          name: policy-limitrange-mem-limit-range
        spec:
          remediationAction: inform # will be overridden by remediationAction in parent policy
          severity: medium
          namespaceSelector:
            exclude: [\"kube-*\"]
            include: [\"default\"]
          object-templates:
            - complianceType: musthave
              objectDefinition:
                apiVersion: v1
                kind: LimitRange # limit memory usage
                metadata:
                  name: mem-limit-range
                spec:
                  limits:
                  - default:
                      memory: 512Mi
                    defaultRequest:
                      memory: 256Mi
                    type: Container"

NAMESPACE="  policy-templates:
    - objectDefinition:
        apiVersion: policy.open-cluster-management.io/v1
        kind: ConfigurationPolicy
        metadata:
          name: policy-namespace-prod
        spec:
          remediationAction: inform # will be overridden by remediationAction in parent policy
          severity: low
          namespaceSelector:
            exclude: [\"kube-*\"]
            include: [\"default\"]
          object-templates:
            - complianceType: musthave
              objectDefinition:
                kind: Namespace # must have namespace 'prod'
                apiVersion: v1
                metadata:
                  name: prod"

POD="  policy-templates:
    - objectDefinition:
        apiVersion: policy.open-cluster-management.io/v1
        kind: ConfigurationPolicy
        metadata:
          name: policy-pod-1-sample-nginx-pod
        spec:
          remediationAction: inform # will be overridden by remediationAction in parent policy
          severity: low
          namespaceSelector:
            exclude: [\"kube-*\"]
            include: [\"default\"]
          object-templates:
            - complianceType: musthave
              objectDefinition:
                apiVersion: v1
                kind: Pod # nginx pod must exist
                metadata:
                  name: sample-nginx-pod
                spec:
                  containers:
                  - image: nginx:1.7.9
                    name: nginx
                    ports:
                    - containerPort: 80"

PSP="  policy-templates:
    - objectDefinition:
        apiVersion: policy.open-cluster-management.io/v1
        kind: ConfigurationPolicy
        metadata:
          name: policy-podsecuritypolicy-sample-restricted-psp
        spec:
          remediationAction: inform # will be overridden by remediationAction in parent policy
          severity: high
          namespaceSelector:
            exclude: [\"kube-*\"]
            include: [\"default\"]
          object-templates:
            - complianceType: musthave
              objectDefinition:
                apiVersion: policy/v1beta1
                kind: PodSecurityPolicy # no privileged pods
                metadata:
                  name: sample-restricted-psp
                  annotations:
                    seccomp.security.alpha.kubernetes.io/allowedProfileNames: '*'
                spec:
                  privileged: false # no privileged pods
                  allowPrivilegeEscalation: false
                  allowedCapabilities:
                  - '*'
                  volumes:
                  - '*'
                  hostNetwork: true
                  hostPorts:
                  - min: 1000 # ports < 1000 are reserved
                    max: 65535
                  hostIPC: false
                  hostPID: false
                  runAsUser:
                    rule: 'RunAsAny'
                  seLinux:
                    rule: 'RunAsAny'
                  supplementalGroups:
                    rule: 'RunAsAny'
                  fsGroup:
                    rule: 'RunAsAny'"

ROLE="  policy-templates:
    - objectDefinition:
        apiVersion: policy.open-cluster-management.io/v1
        kind: ConfigurationPolicy
        metadata:
          name: policy-role-1-sample-role
        spec:
          remediationAction: inform # will be overridden by remediationAction in parent policy
          severity: high
          namespaceSelector:
            exclude: [\"kube-*\"]
            include: [\"default\"]
          object-templates:
            - complianceType: mustonlyhave # role definition should exact match
              objectDefinition:
                apiVersion: rbac.authorization.k8s.io/v1
                kind: Role
                metadata:
                  name: sample-role
                rules:
                  - apiGroups: [\"extensions\", \"apps\"]
                    resources: [\"deployments\"]
                    verbs: [\"get\", \"list\", \"watch\", \"delete\", \"patch\"]"

ROLEBINDING="  policy-templates:
    - objectDefinition:
        apiVersion: policy.open-cluster-management.io/v1
        kind: ConfigurationPolicy
        metadata:
          name: policy-rolebinding-sample-rolebinding
        spec:
          remediationAction: inform # will be overridden by remediationAction in parent policy
          severity: high
          namespaceSelector:
            exclude: [\"kube-*\"]
            include: [\"default\"]
          object-templates:
            - complianceType: musthave
              objectDefinition:
                kind: RoleBinding # role binding must exist
                apiVersion: rbac.authorization.k8s.io/v1
                metadata:
                  name: sample-rolebinding
                subjects:
                - kind: User
                  name: admin # Name is case sensitive
                  apiGroup: rbac.authorization.k8s.io
                roleRef:
                  kind: Role #this must be Role or ClusterRole
                  name: operator # this must match the name of the Role or ClusterRole you wish to bind to
                  apiGroup: rbac.authorization.k8s.io"

#####
# Policy File
#####

echo "getting your policy"
oc get $POLICYFILENAME-namespace -n $NAMESPACE -o yaml > newPolicy.yaml
# cat policyfile.yaml > newPolicy.yaml

echo "update apiVersion"
sed -i '' "s|policy.mcm.ibm.com/v1alpha1|policy.open-cluster-management.io/v1|g" newPolicy.yaml
sed -i '' "s|roletemplate.mcm.ibm.com/v1alpha1|policy.open-cluster-management.io/v1|g" new Policy.yaml
sed -i '' "s|roletemplate.open-cluster-management.io/v1|policy.open-cluster-management.io/v1|g" newPolicy.yaml

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

echo "remove maxRoleBindingViolationsPerNamespace from IAM policy"
sed -i '' "/maxRoleBindingViolationsPerNamespace/d" newPolicy.yaml

# These Policy Types have been updated by RHACM. They switch to using PolicyTemplate and the metadata is also changed
# The sed commands match a specific name or kind and then remove all lines after matching `object-templates`
# They then append the new metadata starting with `policy-templates` to your policy

if  grep -qi "kind: LimitRange" newPolicy.yaml; then
    sed -i '' "1,/object-templates/!d" newPolicy.yaml
    sed -i '' "/object-templates/d" newPolicy.yaml
    echo "$MEM" >> newPolicy.yaml
elif grep -qi "kind: Namespace" newPolicy.yaml; then
     sed -i '' "1,/object-templates/!d" newPolicy.yaml
     sed -i '' "/object-templates/d" newPolicy.yaml
     echo "$NAMESPACE" >> newPolicy.yaml
elif grep -qi "kind: PodSecurityPolicy" newPolicy.yaml; then
     sed -i '' "1,/object-templates/!d" newPolicy.yaml
     sed -i '' "/object-templates/d" newPolicy.yaml
     echo "$PSP" >> newPolicy.yaml
elif grep -qi "kind: Pod" newPolicy.yaml; then
     sed -i '' "1,/object-templates/!d" newPolicy.yaml
     sed -i '' "/object-templates/d" newPolicy.yaml
     echo "$POD" >> newPolicy.yaml
elif grep -qi "name: policy-rolebinding" newPolicy.yaml; then
     sed -i '' "1,/object-templates/!d" newPolicy.yaml
     sed -i '' "/object-templates/d" newPolicy.yaml
     echo "$ROLEBINDING" >> newPolicy.yaml
elif grep -qi "name: policy-role" newPolicy.yaml; then
     sed -i '' "1,/object-templates/!d" newPolicy.yaml
     sed -i '' "/object-templates/d" newPolicy.yaml
     echo "$ROLE" >> newPolicy.yaml
fi

echo "your updated policy is at newPolicy.yaml"

#####
# Policy Binding
#####

echo "getting policy binding"
oc get binding-$POLICYFILENAME-namespace -n $NAMESPACE -o yaml > newBinding.yaml
#cat bindingfile.yaml > newBinding.yaml

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
oc get placement-$POLICYFILENAME-namespace -n $NAMESPACE -o yaml > newPlacementRule.yaml
#cat placementfile.yaml > newPlacementRule.yaml

echo "update apiVersion"
sed -i '' "s|mcm.ibm.com/v1alpha1|apps.open-cluster-management.io/v1|g" newPlacementRule.yaml

echo "update kinds"
sed -i '' "s|PlacementPolicy|PlacementRule|g" newPlacementRule.yaml

echo "your placement policy is at newPlacementRule.yaml"