#!/bin/bash

# This script detects if there is a PPP interface
# configured in /etc/network/interfaces either
# with explicit wb-gsm call (ensures it is an internal modem)
# or with provider which calls wb-gsm explictly

readarray -t ppp_strings < <(awk -v ppp="ppp" '/^iface/ && $4==ppp {f=1} /^iface/ && $4!=ppp {f=0} \
    f && /^[[:space:]]*pre-up.*wb-gsm/ {print "explicit_wbgsm_call"} \
    f && /^[[:space:]]*provider/ {print $2}' /etc/network/interfaces)

provider_has_wbgsm() {
    echo "Checking if provider $1 uses wb-gsm in init"
    grep -q '^init.*wb-gsm' "/etc/ppp/peers/$1"
}

for ppp_string in "${ppp_strings[@]}"; do
case "$ppp_string" in
explicit_wbgsm_call)
    echo "Explicit wb-gsm call found in ppp interface configured in /etc/network/interfaces, not starting ModemManager"
    exit 1;
    ;;
*)
    if provider_has_wbgsm "$ppp_string"; then
        echo "wb-gsm is called in provider $ppp_string used in /etc/network/interfaces, not starting ModemManager"
        exit 1;
    fi
    ;;
esac
done

exit 0
