#!/bin/bash

echo "Installing Paz on Vagrant"

checkScriptsDirExists() {
  [ -d "scripts" ] || { echo "You must run this script from the root directory of the repository"; exit 1; }
}

checkScriptsDirExists

# import helper scripts
. ./scripts/helpers.sh

checkDependencies

# XXX check if Vagrant is installed
# XXX check version of CoreOS in local Vagrant

destroyOldVagrantCluster

set -e
createNewVagrantCluster vagrant/user-data

configureSSHAgent

ETCDCTL_CMD="etcdctl --peers=172.17.8.101:4001"
export FLEETCTL_ENDPOINT=http://172.17.8.101:4001
printDebug ETCDCTL_CMD=${ETCDCTL_CMD}
printDebug FLEETCTL_ENDPOINT=${FLEETCTL_ENDPOINT}

# launch all base paz units except paz-web, and wait until announced
set +e
launchAndWaitForUnits 1 6
waitForCoreServicesAnnounce

# launch paz-web
launchAndWaitForUnits 2 8

# XXX need to test if paz-web can talk to orchestrator

echo
echo You will need to add the following entries to your /etc/hosts:
echo   172.17.8.101 paz-web.paz
echo   172.17.8.101 paz-scheduler.paz
echo   172.17.8.101 paz-orchestrator.paz
echo   172.17.8.101 paz-orchestrator-socket.paz

echo
echo Paz installation successful
