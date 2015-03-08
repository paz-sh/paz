#!/bin/bash

echo "Starting Paz integration test script"

declare -r DIR=$(cd "$(dirname "$0")" && pwd)
cd "${DIR}"

copyDependencies() {
  mkdir unitfiles
  cp -R ../unitfiles/* unitfiles
  mkdir scripts
  cp ../scripts/start-runlevel.sh scripts
}

# import helper scripts
. ../scripts/helpers.sh

checkRequiredEnvVars
checkDependencies

# XXX check if Vagrant is installed
# XXX check version of CoreOS in local Vagrant
destroyOldVagrantCluster
[ $(basename `pwd`) == "test" ] || { cd test; }
rm -rf scripts unitfiles 2>/dev/null

set -e

createNewVagrantCluster ../vagrant/user-data

copyDependencies
configureSSHAgent

ETCDCTL_CMD="etcdctl --peers=172.17.8.101:4001"
export FLEETCTL_TUNNEL=127.0.0.1:2222

set +e

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
echo Adding service to directory
# XXX if it fails (e.g. 503) then it doesn't realise
SVCDOC='{"name":"demo-api","description":"Very simple HTTP Hello World server","dockerRepository":"lukebond/demo-api","numInstances":3,"publicFacing":false}'
ORCHESTRATOR_URL=$($ETCDCTL_CMD get /paz/services/paz-orchestrator)
until curl -sf -XPOST -H "Content-Type: application/json" -d "$SVCDOC" $ORCHESTRATOR_URL/services; do
  sleep 2
done

echo
echo Deploying new service with the /hooks/deploy endpoint
# XXX if it fails (e.g. 400) then it doesn't realise
SCHEDULER_URL=$($ETCDCTL_CMD get /paz/services/paz-scheduler)
DEPLOY_DOC="{\"serviceName\":\"demo-api\",\"dockerRepository\":\"lukebond/demo-api\",\"pushedAt\":`date +%s`}"
until curl -sf -XPOST -H "Content-Type: application/json" -d "$DEPLOY_DOC" $SCHEDULER_URL/hooks/deploy; do
  sleep 2
done

echo
echo Waiting for service to announce itself
until $ETCDCTL_CMD get /paz/services/demo-api/1/1 >/dev/null 2>&1; do
  FAILED_COUNT=$(fleetctl -strict-host-key-checking=false list-units 2>/dev/null | grep "\.service" | awk '{print $3}' | grep -c "failed")
  if [ "$FAILED_COUNT" -gt 0 ]; then
    tput bel
    echo Failed unit detected
    exit 1
  fi
  sleep 1
done
echo "Test service \"demo-api\" is up"

echo
echo You will need to add the following entries to your /etc/hosts:
echo   172.17.8.101 demo-api.paz
