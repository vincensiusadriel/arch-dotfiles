#!/usr/bin/env bash

NOTIFY_TITLE="Bluetooth"

## THEME SETUP
THEME_OVERRIDE="configuration {show-icons:false;} 
prompt {background-color: @bluetooth;} 
element selected {background-color: @bluetooth;} 
button selected {text-color: @bluetooth;} 
textbox {text-color: @bluetooth;}
element normal active {background-color: @bluetooth;}"

## HELPERS
resolve_device() {
    chosen_name="${1%  [*}"
    device_mac=""
    while IFS= read -r line; do
        name=$(echo "$line" | cut -d ' ' -f 3-)
        if [ "$name" = "$chosen_name" ]; then
            device_mac=$(echo "$line" | cut -d ' ' -f 2)
            break
        fi
    done <<< "$(bluetoothctl devices)"
}

do_disconnect() {
    notify-send "$NOTIFY_TITLE" "Disconnecting from \"$chosen_name\"..."
    bluetoothctl disconnect "$device_mac" && notify-send "$NOTIFY_TITLE" "Disconnected"
}

do_connect() {
    notify-send "$NOTIFY_TITLE" "Connecting to \"$chosen_name\"..."
    bluetoothctl trust "$device_mac" > /dev/null 2>&1
    if bluetoothctl connect "$device_mac"; then
        notify-send "$NOTIFY_TITLE" "Connected to \"$chosen_name\""
    else
        notify-send "$NOTIFY_TITLE" "Connection Failed" "Ensure device is in pairing mode."
    fi
}

do_pair() {
    notify-send "$NOTIFY_TITLE" "Pairing with \"$chosen_name\"..."
    bluetoothctl trust "$device_mac" > /dev/null 2>&1
    if bluetoothctl pair "$device_mac" && bluetoothctl connect "$device_mac"; then
        notify-send "$NOTIFY_TITLE" "Paired and Connected to \"$chosen_name\""
    else
        notify-send "$NOTIFY_TITLE" "Pairing Failed" "Ensure device is discoverable."
    fi
}

power_state=$(bluetoothctl show | grep "Powered: yes")

if [ -z "$power_state" ]; then
    toggle="  Enable Bluetooth"
    
    # Simple menu to power on
    chosen=$(echo -e "$toggle" | rofi -dmenu -i -selected-row 0 -p "Bluetooth" -theme-str "window {height: 160px;} listview {lines: 1;} $THEME_OVERRIDE")
    
    if [[ "$chosen" == "$toggle" ]]; then
        bluetoothctl power on
        notify-send "$NOTIFY_TITLE" "Bluetooth Enabled"
    fi
    exit
fi

## DEVICE LISTING
notify-send "$NOTIFY_TITLE" "Scanning for devices..."

# Discover available (including unpaired) devices
timeout 5s bluetoothctl scan on > /dev/null 2>&1
devices_list=$(bluetoothctl devices | awk '!seen[$0]++')

toggle="  Disable Bluetooth"
scan="  Scan for Devices"

# Build menu with status for each device
menu=""
while IFS= read -r mac_and_name; do
    mac=$(echo "$mac_and_name" | cut -d ' ' -f 2)
    name=$(echo "$mac_and_name" | cut -d ' ' -f 3-)
    [ -z "$mac" ] && continue

    info_output=$(bluetoothctl info "$mac")
    if echo "$info_output" | grep -q "Connected: yes"; then
        status="Connected"
    elif echo "$info_output" | grep -q "Paired: yes"; then
        status="Paired"
    else
        status="Unpaired"
    fi

    batt=""
    if echo "$info_output" | grep -qi "Battery Percentage"; then
        batt=", $(echo "$info_output" | grep -i "Battery Percentage" | grep -oE "[0-9]+" | tail -1)%"
    fi
    menu+="$name  [$status$batt]\n"
done <<< "$devices_list"

# Enter = connect (0), d = disconnect (10), p = pair (11)
chosen_row=$(echo -e "$toggle\n$scan\n$menu" | rofi -dmenu -i -selected-row 2 -p "Bluetooth" -kb-custom-1 d -kb-custom-2 p -theme-str "$THEME_OVERRIDE")
action=$?
[ -z "$chosen_row" ] && exit

## ACTION LOGIC
if [ "$action" = "10" ]; then
    # d = disconnect
    resolve_device "$chosen_row"
    [ -n "$device_mac" ] && do_disconnect || notify-send "$NOTIFY_TITLE" "Could not find device address."
    exit
elif [ "$action" = "11" ]; then
    # p = pair
    resolve_device "$chosen_row"
    [ -n "$device_mac" ] && do_pair || notify-send "$NOTIFY_TITLE" "Could not find device address."
    exit
fi

# Enter = connect
if [ "$chosen_row" = "$toggle" ]; then
    bluetoothctl power off
    notify-send "$NOTIFY_TITLE" "Bluetooth Disabled"
elif [ "$chosen_row" = "$scan" ]; then
    notify-send "$NOTIFY_TITLE" "Scanning for 5 seconds..."
    timeout 5s bluetoothctl scan on > /dev/null
    exec "$0"
else
    resolve_device "$chosen_row"
    if [ -z "$device_mac" ]; then
        notify-send "$NOTIFY_TITLE" "Could not find device address."
        exit
    fi
    
    if echo "$(bluetoothctl info "$device_mac")" | grep -q "Connected: yes"; then
        notify-send "$NOTIFY_TITLE" "Already connected to \"$chosen_name\""
        exit
    else
        do_connect
    fi
fi