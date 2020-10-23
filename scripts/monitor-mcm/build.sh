#!/bin/bash

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo Usage: $0 \<DOCK_REGISTRY\> \<NAME_SPACE\> \<SA\>
    echo You must specify the docker registry for the docker image of the monitor job, namespace of legacy search, and service account to deploy the monitor job and a build number.
    echo Exit ...
    exit -1
fi

DOCK_REGISTRY=$1
NAME_SPACE=$2
SA=$3
[ -n "$1" ] && namespace=$1

docker build -t sre-monitor-mcm:test -f Dockerfile .
docker tag sre-monitor-mcm:test $DOCK_REGISTRY/sretest/sre-monitor-mcm:test
docker push $DOCK_REGISTRY/sretest/sre-monitor-mcm:test

sed -i 's/REPLACE_SA/'"$SA"'/g' monitor.yaml
sed -i 's/REPLACE_DOCKER_REGISTRY/'"$DOCK_REGISTRY"'/g' monitor.yaml
sed -i 's/REPLACE_NAMESPACE/'"$NAME_SPACE"'/g' monitor.yaml

kubectl create -f monitor.yaml
