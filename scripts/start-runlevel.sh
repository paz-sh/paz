#!/bin/bash -e
[[ $1 ]] || { echo "Missing numeric runlevel argument (ie. 1 or 2)"; exit 1; }
[[ $ETCD_ENDPOINT ]] || ETCD_ENDPOINT=172.17.9.101:4001

etcdctl --peers=$ETCD_ENDPOINT ls > /dev/null 2>&1 || (echo "etcd unreachable at $ETCD_ENDPOINT"; exit 1)

echo Starting paz runlevel $1 units
fleetctl -strict-host-key-checking=false start unitfiles/$1/*
echo Successfully started all runlevel $1 paz units on the cluster with Fleet
