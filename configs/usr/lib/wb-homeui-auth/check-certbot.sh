#!/bin/bash
set -e

ping -W 2 -c 1 8.8.8.8 || exit 0

. /usr/lib/wb-utils/wb_env.sh

if [[ -n $WB_DEVICE_SERIAL ]]; then
    short_sn=$(echo $WB_DEVICE_SERIAL | awk '{print tolower($0)}')
else
    short_sn=$(wb-gen-serial -s | awk '{print tolower($0)}')
fi

ssl_str="$short_sn.ip.xcvb.win"
ssl_cert_path="/etc/letsencrypt/live/$ssl_str/fullchain.pem"
ssl_cert_key_path="/etc/letsencrypt/live/$ssl_str/privkey.pem"

make_nginx_conf_tmpl()
{
    tmpfile=$(mktemp)
    cat > $tmpfile <<EOL

        server_name *.$ssl_str;
        listen 80;
        listen 443 ssl;
        ssl_certificate $ssl_cert_path;
        ssl_certificate_key $ssl_cert_key_path;
        include /etc/letsencrypt/options-ssl-nginx.conf;
        ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
EOL
    echo $tmpfile
}

nginx_conf_tmpl=$(make_nginx_conf_tmpl)

cleanup()
{
    rm -rf "$nginx_conf_tmpl"
}

trap cleanup EXIT

if [[ ! -f $ssl_cert_path ]] || [[ ! -f $ssl_cert_key_path ]]; then
    echo "Calling certbot to acquire cert"
    certbot certonly --nginx --server https://acme.xcvb.win/directory  --register-unsafely-without-email --agree-tos -n -d "*.$ssl_str"
    echo "Done"
fi

if ! grep -q $ssl_str /etc/nginx/sites-available/default; then
    echo "Filling nginx config with ssl"
    sed -i "/root \/var\/www;/r $nginx_conf_tmpl" /etc/nginx/sites-available/default
    echo "Done; restarting nginx"
    systemctl restart nginx
    echo "Done"
fi
