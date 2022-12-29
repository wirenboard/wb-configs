#!/bin/bash

# remove old wi-fi ap connection
wb_ap_connection="/etc/NetworkManager/system-connections/wb-ap.nmconnection"
short_sn=`wb-gen-serial -s`
if [ -f $wb_ap_connection ]; then
    tmp_connection="/tmp/wb-ap.nmconnection"
    cp -f $wb_ap_connection $tmp_connection
    # remove default SSID value as it is device specific ad affects md5 hash
    sed -i "/Wiren[Bb]oard-${short_sn}/d" $tmp_connection
    # remove timestamp
    sed -i "/timestamp/d" $tmp_connection
    MD5=$(md5sum "$tmp_connection" | cut -f 1 -d ' ')
    # remove old wb-ap without subnet address
    if [ "$MD5" == "2ed8e74107f2dc68fabe96cd0fe6b61c" ]; then
        rm -f $wb_ap_connection || true
    fi

    # Bad generated ssid
    grep -q -x -F "ssid=WirenBoard-" "$wb_ap_connection" && rm -f $wb_ap_connection
fi

# make new nmconnection if missing
deleted_wb_ap="/etc/NetworkManager/system-connections/d12c8d3c-1abe-4832-9b71-4ed6e3c20885.nmmeta"
if [ ! -f "$wb_ap_connection" ] && [ ! -f "$deleted_wb_ap" ]; then
    wb_ap_connection_template="/usr/lib/NetworkManager/system-connections/wb-ap.nmconnection"
    ssid="WirenBoard-${short_sn}"
    cp -f $wb_ap_connection_template $wb_ap_connection
    sed -i "s/^ssid=@SSID@$/ssid=${ssid}/" "$wb_ap_connection"
fi
