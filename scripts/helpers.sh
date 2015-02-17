#!/bin/bash

printDebug() {
  if [ -n "$DEBUG" ]; then echo DEBUG: $*; fi
}

checkRequiredEnvVars() {
  [ ! -z "$DOCKER_REGISTRY" ] || { echo "Using the default/official Docker registry as \$DOCKER_REGISTRY environment variable not set"; DOCKER_REGISTRY="https://index.docker.io/v1/"; }
  [ ! -z "$DOCKER_AUTH" ] || { echo "You must set the \$DOCKER_AUTH environment variable"; exit 1; }
  [ ! -z "$DOCKER_EMAIL" ] || { echo "You must set the \$DOCKER_EMAIL environment variable"; exit 1; }
  printDebug DOCKER_REGISTRY=${DOCKER_REGISTRY}
  printDebug DOCKER_EMAIL=${DOCKER_EMAIL}
}

# XXX check version of fleetctl and etcdctl- should be recent and should match what will be in vagrant
checkDependencies() {
  command -v etcdctl >/dev/null 2>&1 || { echo >&2 "Please install etcdctl. Aborting."; exit 1; }
  command -v fleetctl >/dev/null 2>&1 || { echo >&2 "Please install fleetctl. Aborting."; exit 1; }
}

destroyOldVagrantCluster() {
  echo
  echo "Checking for existing Vagrant cluster"
  if [ -d "coreos-vagrant" ]; then
    echo "Deleting existing Vagrant cluster"
    cd coreos-vagrant
    vagrant destroy -f
    cd ..
  fi
  rm -rf coreos-vagrant 2>/dev/null
}

generateUserDataFile() {
  echo
  echo "Generating user-data file from $1 -> $2"
  cp $1 $2
  perl -i -p -e "s@__DOCKER_REGISTRY__@$3@" $2
  perl -i -p -e "s/__DOCKER_AUTH__/$4/" $2
  perl -i -p -e "s/__DOCKER_EMAIL__/$5/" $2
}

createNewVagrantCluster() {
  echo
  echo "Creating a new Vagrant cluster"
  git clone https://github.com/coreos/coreos-vagrant/
  cp $1 coreos-vagrant
  cd coreos-vagrant
  DISCOVERY_TOKEN=`curl -s https://discovery.etcd.io/new` && perl -i -p -e "s@discovery: https://discovery.etcd.io/\w+@discovery: $DISCOVERY_TOKEN@g" user-data
  printDebug Using discovery token ${DISCOVERY_TOKEN}
  perl -p -e 's/\#\$num_instances=1$/\$num_instances=3/g' config.rb.sample > config.rb
  vagrant box update
  vagrant up
  echo Waiting for Vagrant cluster to be ready...
  until $ETCDCTL_CMD ls >/dev/null 2>&1; do sleep 1; done
  cd ..
  echo CoreOS Vagrant cluster is up
}

configureSSHAgent() {
  echo
  echo "Configuring SSH"
  if [ -z "$SSH_AUTH_SOCK" ]; then
    eval $(ssh-agent)
  fi
  ssh-add ~/.vagrant.d/insecure_private_key
}

launchAndWaitForUnits() {
  echo
  PAZ_RUNLEVEL=$1
  ./scripts/start-runlevel.sh ${PAZ_RUNLEVEL} || {
    STATUS=$?;
    echo "Failed to start at run level ${PAZ_RUNLEVEL}. Exit code ${STATUS}";
    exit ${STATUS};
  }

  echo Waiting for runlevel $PAZ_RUNLEVEL services to be activated...
  UNIT_COUNT=$2
  ACTIVE_COUNT=0
  DOT_COUNTER=1
  until [ "$ACTIVE_COUNT" == "$UNIT_COUNT" ]; do
    ACTIVATING_COUNT=$(fleetctl -strict-host-key-checking=false list-units 2>/dev/null | grep "\.service" | awk '{print $3}' | grep -c "activating")
    ACTIVE_COUNT=$(fleetctl -strict-host-key-checking=false list-units 2>/dev/null | grep "\.service" | awk '{print $3}' | grep -c "active")
    FAILED_COUNT=$(fleetctl -strict-host-key-checking=false list-units 2>/dev/null | grep "\.service" | awk '{print $3}' | grep -c "failed")
    echo -n $'\r'Activating: $ACTIVATING_COUNT \| Active: $ACTIVE_COUNT \| Failed: $FAILED_COUNT 
    for (( c=1; c<=$DOT_COUNTER; c++ )); do echo -n .; done
    for (( c=3; c>$DOT_COUNTER; c-- )); do echo -n " "; done
    ((DOT_COUNTER++))
    if [ "$DOT_COUNTER" -gt 3 ]; then
      DOT_COUNTER=1
    fi
    if [ "$FAILED_COUNT" -gt 0 ]; then
      tput bel
      echo
      echo Failed unit detected
      exit 1
    fi
    sleep 0.5
  done
  echo
  echo All runlevel $PAZ_RUNLEVEL units successfully activated!
}

# wait for orchestrator, service directory and scheduler announce entries to be written to etcd
waitForCoreServicesAnnounce() {
  echo
  echo "Waiting for orchestrator, scheduler and service directory to be announced"
  until $ETCDCTL_CMD get /paz/services/paz-orchestrator >/dev/null 2>&1; do
    sleep 1
  done
  until $ETCDCTL_CMD get /paz/services/paz-scheduler >/dev/null 2>&1; do
    sleep 1
  done
  until $ETCDCTL_CMD get /paz/services/paz-service-directory >/dev/null 2>&1; do
    sleep 1
  done
}

loadEnvVarsFromDockerConfig() {
  local DOCKERCFG_PATH=~/.dockercfg
  printf "Attempt to autoload Docker config from ${DOCKERCFG_PATH} "
  if ! which node 2>/dev/null 1>&2; then echo ' aborted - nodejs required'; return 0; fi

  export DOCKERCFG=$(cat "${DOCKERCFG_PATH}")
  export DOCKER_REGISTRY
  [[ -z ${DOCKER_REGISTRY} ]] && DOCKER_REGISTRY='quay.io'
  [[ ! -z ${DOCKERCFG} && $(echo ${DOCKERCFG} | grep "${DOCKER_REGISTRY}" -c) -gt 0 ]] && {
    NODE_FN="(function(key) {
      var config = JSON.parse(process.env.DOCKERCFG);
      ['', 'https://', 'http://'].forEach(function(prefix) {
        var prefixedDockerRegistry = prefix + process.env.DOCKER_REGISTRY;
        if (config[prefixedDockerRegistry] && config[prefixedDockerRegistry][key]) {
          process.stdout.write(config[prefixedDockerRegistry][key]);
          process.exit(0);
        }
      });
    })"
    export DOCKER_EMAIL=$(node -e "${NODE_FN}('email');")
    export DOCKER_AUTH=$(node -e "${NODE_FN}('auth');")
    echo
  } || echo "FAILED"
  printDebug DOCKERCFG=${DOCKERCFG}
}
