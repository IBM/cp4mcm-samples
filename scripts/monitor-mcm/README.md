# Overview
This is the script to monitor legacy search and recover the legacy search from aggregator hang or redisgraph fail to respond status.

# Steps to deploy the legacy search monitoring job
1. Prepare one service account with Docker registory pull authority and the following pod authority
```
- apiGroups:
  - ""
  resources:
  - pods
  - pods/log
  - pods/exec
  verbs:
  - '*'
``` 
2. Run build.sh command to create job
```
./build.sh <DOCK_REGISTRY> <NAME_SPACE> <SA>
```


