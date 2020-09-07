# overview
The script to monitor legacy search and recover the legacy search from aggregator hang or redisgraph can't response issues.

# steps to deploy the legacy search monitoring job
1. Prepare one service account with docker registory pull and following pod authority
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
2. run build.sh command to create job
```
./build.sh <DOCK_REGISTRY> <NAME_SPACE> <SA>
```


