# Upgrade from CP4MCM FP6 to FP8

Due to internal constraints with IBM Cloud, upgrade for existing customers using CP4MCM on Red Hat on IBM Cloud must be performed manually. Perform the following steps below

## Steps to begin
Using a cluster admin account, login to the cluster on the command line using `oc login`.

## Upgrade to Red Hat Advanced Cluster Management version 2.6

Patch the ACM subscription channel:

```
export RHACM_SUBSCRIPTION_CHANNEL="release-2.6"
oc -n open-cluster-management patch sub acm-operator-subscription --type json -p '[{"op":"replace", "path":"/spec/channel", "value":"'"$RHACM_SUBSCRIPTION_CHANNEL"'"}]'
```

## Upgrade to Cloud Pak for Multicloud Management Fixpack 7

Patch the CP4MCM CatalogSource image:
```
export CP4MCM_CATALOGSOURCE_IMAGE="quay.io/cp4mcm/cp4mcm-orchestrator-catalog:2.3.29
oc -n openshift-marketplace patch catalogsource ibm-management-orchestrator --type json -p '[{"op":"replace", "path":"/spec/image", "value":"'"$CP4MCM_CATALOGSOURCE_IMAGE"'"}]'
```
To verify that the upgrade to CP4MCM FP7 has completed, verify that all pods in the `kube-system` and `management-x` namespaces (e.g. `management-monitoring`, `management-infrastructure-management` if you have the Monitoring or Infrastructure Management modules enabled) are either in `Running` or `Completed` status.

To verify that the upgrade to RHACM version 2.6 has completed, verify that all pods in the `open-cluster-management` namespace are either in `Running` or `Completed` status.

## Upgrade from OCP 4.12 to OCP 4.14

For more information, see [Preparing to update to OpenShift Container Platform 4.14](https://docs.openshift.com/container-platform/4.14/updating/preparing_for_updates/updating-cluster-prepare.html)

## Upgrade to Red Hat Advanced Cluster Management version 2.7

Patch the ACM subscription channel:

```
export RHACM_SUBSCRIPTION_CHANNEL="release-2.7"
oc -n open-cluster-management patch sub acm-operator-subscription --type json -p '[{"op":"replace", "path":"/spec/channel", "value":"'"$RHACM_SUBSCRIPTION_CHANNEL"'"}]'
```

To verify that the upgrade to RHACM version 2.7 has completed, verify that all pods in the `open-cluster-management` namespace are either in `Running` or `Completed` status.

## Upgrade to Red Hat Advanced Cluster Management version 2.8

Patch the ACM subscription channel:

```
export RHACM_SUBSCRIPTION_CHANNEL="release-2.8"
oc -n open-cluster-management patch sub acm-operator-subscription --type json -p '[{"op":"replace", "path":"/spec/channel", "value":"'"$RHACM_SUBSCRIPTION_CHANNEL"'"}]'
```

To verify that the upgrade to RHACM version 2.8 has completed, verify that all pods in the `open-cluster-management` namespace are either in `Running` or `Completed` status.

## Upgrade to Red Hat Advanced Cluster Management version 2.9

Patch the ACM subscription channel:

```
export RHACM_SUBSCRIPTION_CHANNEL="release-2.9"
oc -n open-cluster-management patch sub acm-operator-subscription --type json -p '[{"op":"replace", "path":"/spec/channel", "value":"'"$RHACM_SUBSCRIPTION_CHANNEL"'"}]'
```

To verify that the upgrade to RHACM version 2.9 has completed, verify that all pods in the `open-cluster-management` namespace are either in `Running` or `Completed` status.

## Upgrade to Cloud Pak for Multicloud Management Fixpack 8

Patch the CP4MCM CatalogSource image:
```
export CP4MCM_CATALOGSOURCE_IMAGE="quay.io/cp4mcm/cp4mcm-orchestrator-catalog:2.3.32"
oc -n openshift-marketplace patch catalogsource ibm-management-orchestrator --type json -p '[{"op":"replace", "path":"/spec/image", "value":"'"$CP4MCM_CATALOGSOURCE_IMAGE"'"}]'
```
To verify that the upgrade to CP4MCM FP8 has completed, verify that all pods in the `kube-system` and `management-x` namespaces (e.g. `management-monitoring`, `management-infrastructure-management` if you have the Monitoring or Infrastructure Management modules enabled) are either in `Running` or `Completed` status.
