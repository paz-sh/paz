#!/bin/bash

echo "Installing Paz on Vagrant"

checkRequiredEnvVars() {
  [ ! -z "$DOCKER_REGISTRY" ] || { echo "Using the default/official Docker registry as \$DOCKER_REGISTRY environment variable not set"; DOCKER_REGISTRY="https://index.docker.io/v1/"; }
  [ ! -z "$DOCKER_AUTH" ] || { echo "You must set the \$DOCKER_AUTH environment variable"; exit 1; }
  [ ! -z "$DOCKER_EMAIL" ] || { echo "You must set the \$DOCKER_EMAIL environment variable"; exit 1; }
}

checkScriptsDirExists() {
  [ -d "scripts" ] || { echo "You must run this script from the root directory of the repository"; exit 1; }
}

checkScriptsDirExists

# import helper scripts
. ./scripts/helpers.sh

checkRequiredEnvVars
checkDependencies

# XXX check if Vagrant is installed
# XXX check version of CoreOS in local Vagrant

destroyOldVagrantCluster

mkdir .install-temp 2>/dev/null
generateUserDataFile vagrant/user-data .install-temp/user-data $DOCKER_REGISTRY $DOCKER_AUTH $DOCKER_EMAIL
createNewVagrantCluster .install-temp/user-data
rm -rf .install-temp

configureSSHAgent

ETCDCTL_CMD="etcdctl --peers=172.17.8.101:4001"
export FLEETCTL_TUNNEL=127.0.0.1:2222

# launch all base paz units except paz-web, and wait until announced
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
