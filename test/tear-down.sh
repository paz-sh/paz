#!/bin/bash

checkCWD() {
  DIR=$(basename `pwd`)
  [ "$DIR" == "test" ] || { "You must run this script from the test directory"; exit 1; }
}

# import helper scripts
. ../scripts/helpers.sh

checkCWD

# XXX check if Vagrant is installed
# XXX check version of CoreOS in local Vagrant
destroyOldVagrantCluster

echo Done.
