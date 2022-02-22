# Backing up IBM Cloud Pak® for Multicloud Management using IBM SPP

Follow the steps to back up IBM Cloud Pak® for Multicloud Management using IBM SPP.

## Before you begin
- You need to install the `kubectl`, `oc`, and `git` CLIs on a workstation machine to access the OpenShift cluster which you want to back up.
- Register the cluster with required IBM SPP Server, IBM SPP has three primary components: SPP server, BAAS Agent, and vSnap Server. Ensure to install the components and register the cluster with SPP server before you start the back up operation. See [here](https://www.ibm.com/docs/en/spp/) for more information about installation and cluster registration.

## Procedure

### 1. Clone the GitHub repository

```
git clone https://github.com/IBM/cp4mcm-samples.git
```

### 2. Log in to the OpenShift cluster which you want to back up

```
oc login --token=<TOKEN> --server=<URL>
```

Where:
   
 - `<TOKEN>` is the token that you use to log in to the OpenShift cluster.
 - `<URL>` is the OpenShift server URL.
 
### 3. Perform pre back up tasks

Resource tagging and component specific task is performed as a pre back up task. For common services the component specific task is creating mongodb and for monitoring the component specific task is scaling down the required pods before back up.

1. Go to the directory `<Path of cp4mcm-samples>/bcdr/ibm-spp/backup/scripts` by running the following command, where `<Path of cp4mcm-samples>` is the real path where you put the `cp4mcm-samples` GitHub repository.

   ```
    cd <Path of cp4mcm-samples>/bcdr/ibm-spp/backup/scripts
   ```

2. Run `main.sh` script using below command.

   ```
    bash main.sh
   ```

### 4. Perform back up process for IBM Cloud Pak® for Multicloud Management components using IBM SPP Server UI

   1. Create a SLA policy. It defines the schedule and retention time for back up. For SLA policy creation, follow the steps mentioned [here](https://www.ibm.com/docs/en/spp/10.1.9?topic=operations-creating-sla-policy-containers).
   
   2. Attach IBM Cloud Pak® for Multicloud Management components with newly created SLA policy.
      Please follow the steps mentioned in the following doc to attach IBM Cloud Pak® for Multicloud Management components with SLA policy.
      
      https://www.ibm.com/docs/en/spp/10.1.9?topic=buocd-backing-up-namespace-scoped-resources
      
      Here, Toggle to Label views by using the options from the View menu and search for `backup=cp4mcm`, then select the labelled resources and choose newly created SLA policy. Once SLA policy is associated with labelled resources of IBM Cloud Pak® for Multicloud Management, then back up job will run at schedule time. We can also trigger on demand backup job and steps are mentioned in the IBM SPP official doc.
      
      
### 5. Perform post back up tasks for different IBM Cloud Pak® for Multicloud Management components

#### Post back up tasks for Monitoring:

1. Scale up the pods which were scaled down during "Pre back up tasks for Monitoring" step. The replica count information can be found from file `monitoring-rc-data.json` which is present in `<Path of cp4mcm-samples>/bcdr/ibm-spp/backup/scripts/monitoring` directory. 


**Notes**:

- For detailed steps about SLA policy creation, attaching the SLA policy with application, and taking back up, see [IBM SPP official](https://www.ibm.com/docs/en/spp/) document.
