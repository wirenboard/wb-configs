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
if ! grep -q -E "^[[:space:]]*include_dir /usr/share/wb-configs/mosquitto" $MOSQUITTO_CONF; then
    sed -i '\#include_dir /etc/mosquitto/conf.d#iinclude_dir /usr/share/wb-configs/mosquitto' $MOSQUITTO_CONF
    restart_required=1
fi
if ! grep -q -E "^[[:space:]]*include_dir /usr/share/wb-configs/mosquitto-post" $MOSQUITTO_CONF; then
    sed -i '/include_dir \/etc\/mosquitto\/conf.d/a include_dir /usr/share/wb-configs/mosquitto-post' $MOSQUITTO_CONF
    restart_required=1
fi
if grep -q "persistence .*" $MOSQUITTO_CONF; then
    sed -i '/persistence .*/c# persistence is disabled by default. enable in /etc/mosquitto/conf.d/000persistence.conf' $MOSQUITTO_CONF
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

MOSQUITTO_ACL_CONF="/etc/mosquitto/acl/default.conf"
MOSQUITTO_EXTERNAL_ACL_CONF="/etc/mosquitto/acl/external.conf"
MOSQUITTO_PASSWD_CONF="/etc/mosquitto/passwd/default.conf"

# md5 of the stock /etc/mosquitto/acl/default.conf:
#   topic readwrite #
#   topic readwrite $SYS/#
MOSQUITTO_ACL_CONF_HASH="a5f75ce092ed11139995d31db8fc355b"

# Listener 1883 used to share the default ACL with the web interface listener,
# which allowed any client in the network to call MQTT-RPC of Wiren Board
# services. Switch it to its own ACL, unless the user has customized
# the default ACL (e.g. added accounts) or the listener.
#
# Runs both from postinst and on boot (data partition may come from an older
# firmware), so it must be idempotent.
migrate_external_acl()
{
    local new_conf="$LISTENERS_CONF.wb-new"

    [ -f "$LISTENERS_CONF" ] || return 0

    awk -v from="$MOSQUITTO_ACL_CONF" -v to="$MOSQUITTO_EXTERNAL_ACL_CONF" '
        $1 == "listener" { in_1883 = ($2 == "1883") }
        in_1883 && $1 == "acl_file" && $2 == from && NF == 2 {
            i = index($0, from)
            $0 = substr($0, 1, i - 1) to substr($0, i + length(from))
        }
        { print }
    ' "$LISTENERS_CONF" > "$new_conf"

    if cmp -s "$LISTENERS_CONF" "$new_conf"; then
        rm -f "$new_conf"
        return 0
    fi

    if [ ! -f "$MOSQUITTO_EXTERNAL_ACL_CONF" ]; then
        echo "Not switching listener 1883 to $MOSQUITTO_EXTERNAL_ACL_CONF: file is missing" >&2
        rm -f "$new_conf"
        return 0
    fi

    local acl_hash
    acl_hash=$(md5sum "$MOSQUITTO_ACL_CONF" 2>/dev/null | cut -f 1 -d ' ')
    if [ "$acl_hash" != "$MOSQUITTO_ACL_CONF_HASH" ]; then
        echo "WARNING: listener 1883 uses customized $MOSQUITTO_ACL_CONF, keeping it." >&2
        echo "WARNING: anonymous clients may have access to MQTT-RPC (/rpc/#), see $MOSQUITTO_EXTERNAL_ACL_CONF" >&2
        rm -f "$new_conf"
        return 0
    fi

    echo "Switching listener 1883 to $MOSQUITTO_EXTERNAL_ACL_CONF"
    chmod --reference="$LISTENERS_CONF" "$new_conf"
    chown --reference="$LISTENERS_CONF" "$new_conf"
    sync -f "$new_conf"
    mv -f "$new_conf" "$LISTENERS_CONF"
    restart_required=1
}

migrate_external_acl

# Fix permissions for default ACL and password files
for f in "$MOSQUITTO_ACL_CONF" "$MOSQUITTO_EXTERNAL_ACL_CONF" "$MOSQUITTO_PASSWD_CONF"; do
    [ -f "$f" ] || continue
    chmod 0700 "$f"
    chgrp mosquitto "$f"
    chown mosquitto "$f"
done

exit "$restart_required"
