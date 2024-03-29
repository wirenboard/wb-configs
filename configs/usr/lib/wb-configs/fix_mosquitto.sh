#!/bin/bash

mosquitto_confs=("/etc/mosquitto/acl.conf"
                 "/etc/mosquitto/passwd.conf"
                 "/etc/mosquitto/conf.d/auth.conf"
                 "/etc/mosquitto/conf.d/bridge.conf"
                 "/etc/mosquitto/conf.d/listeners.conf")

mosquitto_hashes=("d41d8cd98f00b204e9800998ecf8427e"  # acl.conf
                  "d41d8cd98f00b204e9800998ecf8427e"  # passwd.conf
                  "af196b100db1a19bed9812922b23a6eb"  # auth.conf
                  "572074e4b5df831e62ce5c5e15d9f1e6"  # bridge.conf
                  "a0ebda1c941a9314890d51bcaa80601e") # listener.conf

# remove mosquitto 1.x configs if not modified by user
for i in ${!mosquitto_confs[@]}; do
    mc=${mosquitto_confs[$i]}
    if [ -f $mc ]; then
        mc_calculated_hash=$(md5sum "$mc" | cut -f 1 -d ' ')
        mc_hash=${mosquitto_hashes[$i]}
        if [ "$mc_calculated_hash" == "$mc_hash" ]; then
            echo "Removing mosquitto 1.x config $mc"
            rm -f $mc $mc.default || true
        elif [ ! -f $mc.keep ]; then
            echo "Backup mosquitto 1.x config $mc"
            mv $mc $mc.old
        else
            echo "Keep config $mc"
        fi
    fi
done
