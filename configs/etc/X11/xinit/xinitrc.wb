#!/bin/sh
xset s off          # Disable screensaver
xset -dpms          # Disable Display Power Management Signaling
xset s noblank      # Disable blank screen

# Hide cursor:
unclutter -idle 0 &

# Run WM
matchbox-window-manager &

# wait run WM
sleep 1

# Read URL from /etc/wb-hardware.conf:
url=$(jq -r '.mod4.options.url // "http://localhost"' /etc/wb-hardware.conf 2>/dev/null)

# If zero URL -> set default URL:
if [ -z "$url" ] || [ "$url" = "null" ]; then
    url="http://localhost"
fi

# Run FireFox in kiosk mode:
firefox --kiosk "$url"

