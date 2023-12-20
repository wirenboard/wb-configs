#!/bin/bash

wb_ap_ssid_prefix="${WB_AP_SSID_PREFIX:-WirenBoard}"

# find Wi-Fi module
wifi_module="RTL8723BU"
if [ -z $(lsusb -d'0bda:b720') ]; then
    wifi_module="RTL8733BU"
fi

# Args:
# - MD5 hash of wb-ap.nmconnection without ssid and timestamp
# - Wi-Fi module name
should_delete_config() {
    # remove old wb-ap without subnet address
    if [ "$1" == "2ed8e74107f2dc68fabe96cd0fe6b61c" ]; then
        return 0
    fi

    # remove old wb-ap without channel
    if [ "$1" == "f2a720dc98d3764efab777f060ca79c4" ]; then
        return 0
    fi

    # remove old wb-ap with band and channels
    if [ "$2" == "RTL8733BU" ] && [ "$1" == "1737c3e9aa4a887f59235c6b4867fa5d" ]; then
        return 0
    fi

    return 1
}

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

    should_delete_config $MD5 $wifi_module && {
        rm -f $wb_ap_connection || true
    }

    # Bad generated ssid
    if [ -f $wb_ap_connection ]; then
        grep -q -x -F "ssid=WirenBoard-" "$wb_ap_connection" && rm -f $wb_ap_connection
    fi
fi

wb_ap_connection_template="/usr/lib/NetworkManager/system-connections/wb-ap.nmconnection"
wb_ap_uuid=$(awk -F '=' '$1=="uuid" {print $2}' ${wb_ap_connection_template})
# make new nmconnection if missing
deleted_wb_ap="/etc/NetworkManager/system-connections/${wb_ap_uuid}.nmmeta"
if [ ! -f "$wb_ap_connection" ] && [ ! -f "$deleted_wb_ap" ]; then
    ssid="${wb_ap_ssid_prefix}-${short_sn}"
    cp -f $wb_ap_connection_template $wb_ap_connection
    sed -i "s/^ssid=@SSID@$/ssid=${ssid}/" "$wb_ap_connection"

    # remove band and channel for new chipset
    if [ "$wifi_module" == "RTL8733BU" ]; then
        sed -i "/channel=1/d" "$wb_ap_connection"
        sed -i "/band=bg/d" "$wb_ap_connection"
    fi
fi
