#!/bin/bash

# Custom Rofi WiFi menu using nmcli
# Handles listing, connecting, and toggling WiFi

dir="$HOME/.config/rofi"
[ ! -d "$dir" ] && dir="$(dirname "$(readlink -f "$0")")/.."

# Icons
ICON_WIFI="󰖩"
ICON_WIFI_OFF="󰖪"
ICON_LOCK="󰌾"
ICON_CHECK="󰄬"
ICON_SAVED="󰄬" # Or maybe 󰂜 or 󰗘

# Get interface
WLAN_INT=$(nmcli device status | grep wifi | awk '{print $1}' | head -n1)

# Helper function to call rofi with theme override
call_rofi() {
    local prompt="$1"
    local placeholder="$2"
    local is_password="$3"
    local theme="$dir/list_search_config.rasi"
    
    local args=(-dmenu -i -p "$prompt" -theme "$theme")
    [ "$is_password" = "yes" ] && args+=(-password)
    
    # Use theme-str to override placeholder
    args+=(-theme-str "entry { placeholder: \"$placeholder\"; }")
    
    rofi "${args[@]}"
}

# Get current status
get_status() {
    wifi_state=$(nmcli -t -f WIFI g)
    if [[ "$wifi_state" =~ "enabled" ]]; then
        echo "Enabled"
    else
        echo "Disabled"
    fi
}

# Get current connection
get_current_connection() {
    nmcli -t -f ACTIVE,SSID dev wifi | grep '^yes' | cut -d':' -f2
}

# List available networks
list_networks() {
    active_connection=$(get_current_connection)
    wifi_status=$(get_status)

    if [ "$wifi_status" = "Disabled" ]; then
        echo "󰖪  Enable WiFi"
        return
    fi

    echo "󰖪  Disable WiFi"
    echo "󰖩  Rescan Networks"
    
    if [ -n "$active_connection" ]; then
        echo "󱘖  Disconnect from $active_connection"
    fi

    # Get all networks and deduplicate by SSID (keeping strongest)
    raw_list=$(nmcli -t -f SSID,SECURITY,BARS,ACTIVE dev wifi list)
    
    # Segregated lists
    saved_list=""
    new_list=""
    seen_ssids=""

    while IFS=: read -r ssid security bars active; do
        [ -z "$ssid" ] && continue
        
        # Check if we've already added this SSID
        if echo -e "$seen_ssids" | grep -qxF "$ssid"; then
            continue
        fi
        seen_ssids+="$ssid\n"

        # Determine if it's saved (check if a wireless connection profile exists with this name)
        is_saved=false
        if nmcli -t -f TYPE connection show "$ssid" 2>/dev/null | grep -q "802-11-wireless"; then
            is_saved=true
        fi

        if [ "$active" = "yes" ]; then
            icon="$ICON_CHECK"
        else
            icon="$ICON_WIFI"
        fi

        # Mark secure networks
        if [ -n "$security" ] && [ "$security" != "--" ]; then
            lock="$ICON_LOCK"
        else
            lock=""
        fi

        line=$(printf "%s %-30s | %s | %s\n" "$icon" "$ssid" "$lock" "$bars")
        
        if $is_saved; then
            saved_list+="$line\n"
        else
            new_list+="$line\n"
        fi
    done <<< "$raw_list"

    if [ -n "$saved_list" ]; then
        echo -e "--- Saved Connections ---"
        echo -e "$saved_list" | sed '/^$/d' | sort -u
    fi

    if [ -n "$new_list" ]; then
        echo -e "--- Available Networks ---"
        echo -e "$new_list" | sed '/^$/d' | sort -u
    fi
}

# Main loop
while true; do
    selection=$(list_networks | call_rofi "WiFi" "Search Networks...")
    [ -z "$selection" ] && exit
    
    # Ignore header lines
    [[ "$selection" == "---"* ]] && continue

    case "$selection" in
        *"Enable WiFi")
            nmcli radio wifi on
            notify-send "WiFi" "WiFi Enabled"
            ;;
        *"Disable WiFi")
            nmcli radio wifi off
            notify-send "WiFi" "WiFi Disabled"
            ;;
        *"Rescan Networks")
            notify-send "WiFi" "Scanning for networks..."
            nmcli dev wifi rescan
            sleep 2
            ;;
        *"Disconnect from"*)
            ssid=$(echo "$selection" | sed 's/.*Disconnect from //')
            nmcli dev disconnect "$WLAN_INT"
            notify-send "WiFi" "Disconnected from $ssid"
            ;;
        *)
            # Extract SSID: everything before the first '|', then remove the first 2 characters (icon and space)
            ssid=$(echo "$selection" | cut -d'|' -f1 | sed 's/^..//' | sed 's/ *$//')
            
            # Check if SSID is in saved connections
            is_saved=false
            if nmcli -t -f NAME,TYPE connection show | grep 802-11-wireless | cut -d':' -f1 | grep -q "^$ssid$"; then
                is_saved=true
            fi

            if $is_saved; then
                notify-send "WiFi" "Connecting to saved network $ssid..."
                if err=$(nmcli connection up "$ssid" 2>&1); then
                    notify-send "WiFi" "Successfully connected to $ssid"
                    exit
                else
                    notify-send "WiFi" "Connection Failed" "$err"
                fi
            else
                # Check if security is needed (check if there's a lock icon in the selection)
                if [[ "$selection" == *"$ICON_LOCK"* ]]; then
                    pass=$(call_rofi "Password" "Password for $ssid" "yes")
                    [ -z "$pass" ] && continue
                    
                    notify-send "WiFi" "Connecting to $ssid..."
                    if err=$(nmcli dev wifi connect "$ssid" password "$pass" 2>&1); then
                        notify-send "WiFi" "Successfully connected to $ssid"
                        exit
                    else
                        notify-send "WiFi" "Connection Failed" "$err"
                    fi
                else
                    notify-send "WiFi" "Connecting to $ssid..."
                    if err=$(nmcli dev wifi connect "$ssid" 2>&1); then
                        notify-send "WiFi" "Successfully connected to $ssid"
                        exit
                    else
                        notify-send "WiFi" "Connection Failed" "$err"
                    fi
                fi
            fi
            ;;
    esac
done
