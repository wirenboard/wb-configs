#!/bin/bash
# Wiren Board figlet banner for login
# Called via pam_exec to display banner before MOTD
# Adapts to terminal width

cols=$(tput cols 2>/dev/null || echo 80)

echo -ne "\033[32m"

figlet_width=$(figlet wirenboard 2>/dev/null | head -1 | wc -c)
if [ "$cols" -ge "$figlet_width" ]; then
    figlet wirenboard
else
    figlet_width=$(figlet Wiren 2>/dev/null | head -1 | wc -c)
    if [ "$cols" -ge "$figlet_width" ]; then
        figlet Wiren
        figlet Board
    else
        figlet WB
    fi
fi

echo -ne "\033[0m"
