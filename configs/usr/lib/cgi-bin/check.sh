#!/bin/bash

# set -e

send_output() {
    echo "Status: $1"
    echo "Content-type: text/plain"
    echo ""
    echo "$2"
}

SERIAL=$(cat "/var/lib/wirenboard/short_sn.conf")
URL="${HTTP_SCHEME}://${HTTP_HOST}/"

data=$(curl --silent --show-error --fail -X POST -o /dev/stdout -d "serial=${SERIAL}&url=${URL}" "http://10.200.10.232:8222/probe/")
if [ $? -ne 0 ]; then
    send_output 503 "Failed to get response from upstream"
    exit 0
fi

result=$(echo "$data" | jq -r '.result')
if [ "$result" == "cooldown" ]; then
    send_output 200 "Cooldown"
    exit 0
else
    mosquitto_pub -d -t "/rpc/v1/exp-check" -m "$data" -r 2>&1
    send_output 200 "OK"
    exit 0
fi