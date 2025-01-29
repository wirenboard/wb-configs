#!/bin/bash
set -e

ping -W 2 -c 1 8.8.8.8 || exit 0

. /usr/lib/wb-utils/wb_env.sh

if [[ -n $WB_DEVICE_SERIAL ]]; then
    short_sn=$(echo $WB_DEVICE_SERIAL | awk '{print tolower($0)}')
else
    short_sn=$(wb-gen-serial -s | awk '{print tolower($0)}')
fi

DOMAIN="*.$short_sn.ip.wirenboard.com"
SSL_CERT_PATH="/etc/ssl/sslip.pem"
SSL_CERT_KEY_PATH="/etc/ssl/sslip.key"
DHPARAM_PATH="/etc/ssl/dhparam.pem"
CSR=/tmp/csr.pem
KEYSPEC="ATECCx08:00:02:C0:00"
KEY=/tmp/private.key
DEVICE_ORIGINAL_CERT=/etc/ssl/certs/device_bundle.crt.pem
CERT_FOR_REQUEST=/var/run/shm/device_bundle.crt.pem

openssl x509 -checkend $((60*60*24*15))  -noout -in $SSL_CERT_PATH && {
    echo "The certificate won't expire soon, exiting"
    exit 0
}

echo "Generating CSR"
openssl req -new -newkey rsa:2048 -nodes \
  -keyout $KEY \
  -out $CSR \
  -outform PEM \
  -subj "/CN=$DOMAIN" \
  -addext "subjectAltName=DNS: $DOMAIN" \
  -addext "extendedKeyUsage=serverAuth,clientAuth"


# Create temp file, readable and writable only by current user and root
SCRATCH=$( umask 0077; mktemp -t tmp.XXXXXXXXXX )

# Cleanup temp file on script exit
function cleanup_on_exit {
    rm -f "$SCRATCH"
}
trap cleanup_on_exit EXIT

make_request_cert() {
    awk -v "req_part=2" '/BEGIN CERT/{c++} c == req_part { print }' < "$DEVICE_ORIGINAL_CERT" > "$CERT_FOR_REQUEST"
    awk -v "req_part=1" '/BEGIN CERT/{c++} c == req_part { print }' < "$DEVICE_ORIGINAL_CERT" >> "$CERT_FOR_REQUEST"
}

make_request_cert

echo "Requesting certificate from issuing server"
HTTP_CODE=$( curl -s -o "$SCRATCH" -w '%{http_code}' \
         --cert $CERT_FOR_REQUEST \
         --key "$KEYSPEC" --engine ateccx08 --key-type ENG \
         -X POST -F "csr=@$CSR" \
             https://sslip-cert.wirenboard.com/api/v1/issue )


# Analyze HTTP return code
if [ ${HTTP_CODE} -ne 200 ] ; then
    echo "Error getting certificate!" >2
    cat "${SCRATCH}" >2
    exit 1
fi

echo "Successfully got certificate"
cat "${SCRATCH}" | jq -r '.fullchain_pem' > $SSL_CERT_PATH
mv $KEY $SSL_CERT_KEY_PATH

setup_nginx()
{
    mkdir -p /etc/nginx/ssl/
    cat > /etc/nginx/ssl/auth.conf <<EOL

        server_name $DOMAIN;
        listen 80;
        listen 443 ssl;
        ssl_certificate $SSL_CERT_PATH;
        ssl_certificate_key $SSL_CERT_KEY_PATH;
        ssl_session_cache shared:le_nginx_SSL:10m;
        ssl_session_timeout 1440m;
        ssl_session_tickets off;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_prefer_server_ciphers off;
        ssl_ciphers "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384";
        ssl_dhparam $DHPARAM_PATH;
EOL
    openssl dhparam -out $DHPARAM_PATH 256
    systemctl restart nginx
}

setup_nginx
