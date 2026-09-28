#!/usr/bin/env bash

# Simple mako notification menu
# Dependencies: bash, makoctl, jq, rofi

NOTIFS=$( { makoctl list -j 2>/dev/null; makoctl history -j 2>/dev/null; } \
       | jq -s 'add | unique_by(.id) | map(select(.app_name != "notify-send")) | sort_by(.id) | reverse' 2>/dev/null)

if [[ $(echo "$NOTIFS" | jq 'length') -eq 0 ]]; then
    notify-send -t 1500 "󰎟 Notifications" "No notifications."
    exit 0
fi

IDS=()
while IFS= read -r id; do
    IDS+=("$id")
done < <(echo "$NOTIFS" | jq -r '.[].id')

MENU=$(echo "$NOTIFS" | jq -r '.[] |
    (.app_name // "unknown") as $app |
    (.summary // "No summary") as $sum |
    (.body // "" | gsub("\n"; " ") | .[0:100]) as $body |
    if $body == "" then "<b>[\($app)]</b> \($sum)"
    else "<b>[\($app)]</b> \($sum) — <span size=\"smaller\" alpha=\"75%\">\($body)</span>"
    end')

SELECTED=$(echo -n "$MENU" | rofi -dmenu -i -p "󰎟 Notifications" \
    -mesg "<b>Alt+y</b>: Clear All  |  <b>Alt+t</b>: Toggle DND" \
    -markup-rows \
    -format 'i' \
    -eh 1 \
    -kb-custom-2 "Alt+y" \
    -kb-custom-3 "Alt+t")

EXIT=$?

case $EXIT in
    0)
        if [[ "$SELECTED" =~ ^[0-9]+$ ]]; then
            ID="${IDS[$SELECTED]}"
            makoctl invoke -n "$ID" default 2>/dev/null
            makoctl dismiss -n "$ID" 2>/dev/null
        fi
        ;;
    11)
        # Alt+Y Wipe
        if systemctl --user is-active --quiet mako.service; then
            systemctl --user restart mako.service
        else
            pkill -x mako &&  mako &
        fi
        pkill -RTMIN+8 waybar
        ;;
    12)
        # Alt+T Toggle Do Not Disturb
        if makoctl mode | grep -qw "do-not-disturb"; then
            makoctl mode -r do-not-disturb && pkill -RTMIN+8 waybar
            notify-send  -u normal "󰂚  Do Not Disturb" "Disabled"
        else
            makoctl mode -a do-not-disturb && pkill -RTMIN+8 waybar
        fi
        ;;
esac

