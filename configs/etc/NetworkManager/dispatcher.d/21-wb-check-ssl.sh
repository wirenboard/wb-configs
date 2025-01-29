#/bin/sh

if [ "$2" = "connectivity-change" ]; then
    /usr/lib/wb-homeui-auth/check-ssl.sh
fi
