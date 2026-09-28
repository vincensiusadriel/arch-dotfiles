#!/usr/bin/env bash

NOTIFY_TITLE="Bluetooth"

## THEME SETUP
THEME_OVERRIDE="configuration {show-icons:false;} 
prompt {background-color: @bluetooth;} 
element selected {background-color: @bluetooth;} 
button selected {text-color: @bluetooth;} 
textbox {text-color: @bluetooth;}
element normal active {background-color: @bluetooth;}"

power_state=$(bluetoothctl show | grep "Powered: yes")

if [ -z "$power_state" ]; then
    toggle="  Enable Bluetooth"
    
    # Simple menu to power on
    chosen=$(echo -e "$toggle" | rofi -dmenu -i -selected-row 0 -p "Bluetooth" -theme-str "window {height: 160px;} listview {lines: 1;} $THEME_OVERRIDE")
    
    if [[ "$chosen" == "$toggle" ]]; then
        bluetoothctl power on
        notify-send "$NOTIFY_TITLE" "Bluetooth Enabled"
    fi
    exit
fi

## DEVICE LISTING
devices_list=$(bluetoothctl devices | cut -d ' ' -f 3- | awk '!seen[$0]++')

toggle="  Disable Bluetooth"
scan="  Scan for Devices"

chosen_row=$(echo -e "$toggle\n$scan\n$devices_list" | rofi -dmenu -i -selected-row 2 -p "Bluetooth" -theme-str "$THEME_OVERRIDE")

## ACTION LOGIC
if [ -z "$chosen_row" ]; then
    exit
elif [ "$chosen_row" = "$toggle" ]; then
    bluetoothctl power off
    notify-send "$NOTIFY_TITLE" "Bluetooth Disabled"
elif [ "$chosen_row" = "$scan" ]; then
    notify-send "$NOTIFY_TITLE" "Scanning for 5 seconds..."
    timeout 5s bluetoothctl scan on > /dev/null
    exec "$0"
else
    # Find MAC from the selected name
    device_info=$(bluetoothctl devices | grep "$chosen_row$")
    device_mac=$(echo "$device_info" | cut -d ' ' -f 2)
    
    if [ -z "$device_mac" ]; then
        notify-send "$NOTIFY_TITLE" "Could not find device address."
        exit
    fi
    
    info_output=$(bluetoothctl info "$device_mac")
    
    if echo "$info_output" | grep -q "Connected: yes"; then
        notify-send "$NOTIFY_TITLE" "Disconnecting from \"$chosen_row\"..."
        bluetoothctl disconnect "$device_mac" && notify-send "$NOTIFY_TITLE" "Disconnected"
    else
        notify-send "$NOTIFY_TITLE" "Connecting to \"$chosen_row\"..."
        bluetoothctl trust "$device_mac" > /dev/null 2>&1
        
        # Attempt connection
        if bluetoothctl connect "$device_mac"; then
            notify-send "$NOTIFY_TITLE" "Connected to \"$chosen_row\""
        else
             notify-send "$NOTIFY_TITLE" "Connection Failed" "Ensure device is in pairing mode."
        fi
    fi
fi
