#!/bin/bash

short_sn=`wb-gen-serial -s`
ssid="WirenBoard-${short_sn}"
sed -i "s/^ssid=@SSID@$/ssid=${ssid}/" "/etc/NetworkManager/system-connections/wb-ap.nmconnection"
