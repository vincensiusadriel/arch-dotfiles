#!/bin/bash

# simple rofi power menu
# handles basic system control and a poweroff timer

dir="$HOME/.config/rofi"
[ ! -d "$dir" ] && dir="$(dirname "$(readlink -f "$0")")/.."
rofi_cmd="rofi -dmenu -i -p Power -theme $dir/no_search_config.rasi"

actions="󰐥 Poweroff\n󰜉 Reboot\n󰤄 Suspend\n⚿ Lock\n󰈆 Logout\n󱎫 Poweroff Timer"

show_timer_menu() {
    printf "󱎫  5 mins\n󱎫  10 mins\n󱎫  15 mins\n󱎫  30 mins\n󱎫  45 mins\n󱎫  1 hr" | $rofi_cmd
}

selection=$(printf "$actions" | $rofi_cmd)

case "$selection" in
    *Poweroff) systemctl poweroff ;;
    *Reboot)   systemctl reboot ;;
    *Suspend)  systemctl suspend ;;
    *Lock)     hyprlock ;;
    *Logout)   command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()' ;;
    *"Poweroff Timer")
        timer_choice=$(show_timer_menu)
        case "$timer_choice" in
            *"5 mins") m=5 ;;
            *"10 mins") m=10 ;;
            *"15 mins") m=15 ;;
            *"30 mins") m=30 ;;
            *"45 mins") m=45 ;;
            *"1 hr") m=60 ;;
        esac
        
        if [ -n "$m" ]; then
            shutdown +"$m"
            notify-send "Poweroff Timer" "System will power off in $m mins"
        fi
        ;;
esac
