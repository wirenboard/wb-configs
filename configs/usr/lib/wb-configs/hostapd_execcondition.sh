#!/bin/bash

hostapd_interface_line=$(grep -E -o 'interface=.+$' /etc/hostapd.conf)
hostapd_interface=${hostapd_interface_line#interface=}

wpa_ssid_search_string=$(awk -v hostapd_interface="$hostapd_interface" '/^iface/ && $2==hostapd_interface {f=1} /^iface/ && $2!=hostapd_interface {f=0} f && /^[ ]*wpa-ssid/ {print 0}' /etc/network/interfaces)

if [ -z "$wpa_ssid_search_string" ]; then exit 0; else exit 1;fi
