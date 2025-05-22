#!/bin/bash

MOSQUITTO_CONF="/etc/mosquitto/mosquitto.conf"
LISTENERS_CONF='/etc/mosquitto/conf.d/10listeners.conf'
restart_required=0
if grep -q "log_dest file /var/log/mosquitto/mosquitto.log" $MOSQUITTO_CONF; then
    sed -i 's#log_dest file /var/log/mosquitto/mosquitto.log#log_dest syslog#' $MOSQUITTO_CONF
    restart_required=1
fi
if grep -q "pid_file /var/run/mosquitto.pid" $MOSQUITTO_CONF; then
    sed -i 's#pid_file /var/run/mosquitto.pid#pid_file /run/mosquitto/mosquitto.pid#' $MOSQUITTO_CONF
    restart_required=1
fi
if ! grep -q -F "include_dir /usr/share/wb-configs/mosquitto" $MOSQUITTO_CONF; then
    sed -i '\#include_dir /etc/mosquitto/conf.d#iinclude_dir /usr/share/wb-configs/mosquitto' $MOSQUITTO_CONF
    restart_required=1
fi
if grep -q "persistence .*" $MOSQUITTO_CONF; then
    sed -i 's@persistence .*@# persistence is disabled by default. enable in /etc/mosquitto/conf.d/000persistence.conf@' $MOSQUITTO_CONF
    restart_required=1
fi
if grep -q "^listener 18883$" $LISTENERS_CONF; then
	sed -i '/^listener 18883$/clistener 18883 lo' $LISTENERS_CONF
	restart_required=1
fi

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

# Fix permissions for default ACL and password files
MOSQUITTO_ACL_CONF="/etc/mosquitto/acl/default.conf"
MOSQUITTO_PASSWD_CONF="/etc/mosquitto/passwd/default.conf"

chmod 0700 $MOSQUITTO_ACL_CONF
chmod 0700 $MOSQUITTO_PASSWD_CONF

chgrp mosquitto $MOSQUITTO_ACL_CONF
chgrp mosquitto $MOSQUITTO_PASSWD_CONF

chown mosquitto $MOSQUITTO_ACL_CONF
chown mosquitto $MOSQUITTO_PASSWD_CONF

exit "$restart_required"
