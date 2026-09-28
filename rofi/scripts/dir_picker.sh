#!/usr/bin/env bash

# rofi directory picker
# returns the absolute path of the chosen directory

current_dir="${1:-$HOME}"
dir="$HOME/.config/rofi"

while true; do
    dirs=$(find "$current_dir" -mindepth 1 -maxdepth 1 -type d -not -name '.*' -printf "%f\n" | sort)
    options="  Use This Folder\n..\n$dirs"
    options=$(echo "$options" | sed '/^$/d')

    # try standard or fallback theme
    theme_file="$dir/list_search_config.rasi"
    [ ! -f "$theme_file" ] && theme_file="$(dirname "$(readlink -f "$0")")/../list_search_config.rasi"

    chosen=$(echo -e -n "$options" | rofi -dmenu -i -p "$current_dir" -theme "$theme_file")
    
    if [ -z "$chosen" ]; then 
        exit 1
    elif [ "$chosen" == "  Use This Folder" ]; then 
        echo "$current_dir"
        exit 0
    elif [ "$chosen" == ".." ]; then 
        current_dir=$(dirname "$current_dir")
    else 
        current_dir="$current_dir/$chosen"
    fi
done
