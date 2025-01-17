#!/bin/bash

# grant access fastcgi sripts to mosquitto's unix socket
/usr/sbin/usermod -aG mosquitto www-data
