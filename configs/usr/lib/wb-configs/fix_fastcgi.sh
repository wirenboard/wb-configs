#!/bin/bash

# grant access fastcgi sripts to mosquitto's unix socket
/usr/sbin/usermod -aG mosquitto www-data

# grant access fastcgi sripts to /var/wb-webui
chgrp www-data /var/wb-webui
chmod g+wx /var/wb-webui
