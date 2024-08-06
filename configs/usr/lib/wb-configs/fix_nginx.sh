#!/bin/bash

SITES_ENABLED_DIR="/etc/nginx/sites-enabled"

for config in "$SITES_ENABLED_DIR"/*; do
    if [ -L "$config" ]; then
        if [ ! -e "$config" ]; then
            echo "Removing broken symlink: $config"
            rm -f "$config"
        fi
    fi
done
