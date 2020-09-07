#!/bin/bash

set -x

[ -n "$1" ] && namespace=$1
[ -z "$namespace" ] && namespace=kube-system

while true; do
    echo --------------
    date
    echo --------------
    kubectl -n $namespace get pod | grep search- | grep Running > /tmp/pods.out
    aggregators=$(cat /tmp/pods.out | grep search-aggregator | awk '{print $1}')
    for pod in $aggregators; do
        kubectl -n $namespace logs $pod | tail -20 > /tmp/aggregator.log
        found=$(grep 'Too many pending requests .* Rejecting sync from cluster' /tmp/aggregator.log | wc -l)
        # if more than 15 lines had the rejection message, then restart the aggregator
        [ $found -gt 15 ] && echo Issue 11880 occurred, must restart pod $pod. && kubectl -n $namespace delete pod $pod && continue
    done
    redis=$(cat /tmp/pods.out | grep search-redisgraph | awk '{print $1}')
    pass=$(kubectl -n $namespace exec -it $redis -- env | grep REDIS_PASSWORD | sed -e 's/REDIS_PASSWORD=//')
    timeout 60s kubectl -n $namespace exec -it $redis -- redis-cli -a $pass < /scripts/test.cmd
    code=$?
    [ $code -eq 124 ] && echo The RedisGraph is not responding, issue 12316 occurred. Must restart the RedisGraph. && kubectl -n $namespace delete pod $redis
    sleep 60
done
