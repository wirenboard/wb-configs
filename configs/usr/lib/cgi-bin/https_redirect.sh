#!/bin/bash

sn=$(sudo wb-gen-serial -s | tr '[:upper:]' '[:lower:]')
prefix=$(echo "$HTTP_HOST_IP" | sed 's/\./-/g')

echo "Status: 200"
echo "Content-type: text/plain"
echo ""
echo "$prefix.$sn.ip.xcvb.win"
