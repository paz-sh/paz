#!/bin/bash
while true; do
  curl -o /dev/null -s -i --write-out '%{http_code}\n' http://demo-api.lukeb0nd.com
  sleep 1;
done
