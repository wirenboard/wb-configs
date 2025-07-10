#!/bin/sh
xset s off          # отключает screensaver (черный экран)
xset -dpms          # отключает Display Power Management Signaling
xset s noblank      # отключает затемнение экрана

# Скрываю курсор
unclutter -idle 0 &

# Запуск matchbox WM
matchbox-window-manager &

# Подождать немного, чтобы WM стартовал
sleep 1

# Прочитать URL из /etc/wb-hardware.conf с помощью jq
url=$(jq -r '.mod4.options.url // "http://localhost"' /etc/wb-hardware.conf 2>/dev/null)

# Если по какой-то причине jq не вернул URL, установить значение по умолчанию
if [ -z "$url" ] || [ "$url" = "null" ]; then
    url="http://localhost"
fi

# Запуск Firefox в режиме киоска
firefox --kiosk "$url"

