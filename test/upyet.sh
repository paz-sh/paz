#!/bin/bash
export FLEETCTL_TUNNEL=127.0.0.1:2222
echo Waiting for services to be activated...
UNIT_COUNT=8
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
done

echo
echo All units successfully activated!
