#!/usr/bin/env bash
set -euo pipefail

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --clear)
            if systemctl --user is-active --quiet mako.service; then
                systemctl --user restart mako.service
            else
                pkill -x mako && mako &
            fi
            pkill -RTMIN+8 waybar
            exit 0
            ;;
    esac
done

# Fetch notification buffers
ACTIVE=$(timeout 1 makoctl list -j 2>/dev/null || echo "[]")
ACTIVE=${ACTIVE:-[]}

HISTORY=$(timeout 1 makoctl history -j 2>/dev/null || echo "[]")
HISTORY=${HISTORY:-[]}

# Check DND mode
DND=""
if [[ "$(timeout 1 makoctl mode 2>/dev/null || true)" =~ "do-not-disturb" ]]; then
    DND="true"
fi

# Process notifications and output Waybar JSON
jq -c -n \
    --argjson active "$ACTIVE" \
    --argjson history "$HISTORY" \
    --arg dnd "$DND" '

    def extract_notifs:
        if type == "object" and .data then [.data[][]?] else (if type == "array" then . else [] end) end;

    "󰂛" as $dnd_icon | "󰂚" as $norm_icon |

    [$active, $history] | map(extract_notifs) | add
    | unique_by(.id)
    | map(select(.app_name != "notify-send"))
    | length as $count |

    if $dnd != "" then
        {
            "text": (if $count == 0 then $dnd_icon else "\($dnd_icon) \($count)" end),
            "tooltip": "Do Not Disturb (\($count) pending)",
            "class": (if $count == 0 then "dnd-none" else "dnd-notification" end)
        }
    else
        {
            "text": (if $count == 0 then $norm_icon else "\($norm_icon) \($count)" end),
            "tooltip": (if $count == 0 then "No notifications" else "\($count) pending notifications" end),
            "class": (if $count == 0 then "none" else "notification" end)
        }
    end
'
