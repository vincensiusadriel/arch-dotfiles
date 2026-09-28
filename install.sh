#!/usr/bin/env bash
# Recreate ~/.config symlinks for every entry tracked in this repo.
# Run from anywhere:  ~/arch-dotfiles/install.sh

set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config="$HOME/.config"

entries=(
    bluetui gtk-3.0 gtk-4.0 htop hypr kitty lazygit libreoffice
    mako matugen nwg-look qt5ct qt6ct rofi waybar xsettingsd
    QtProject.conf chromium-flags.conf dolphinrc mimeapps.list
    pavucontrol.ini
)

for name in "${entries[@]}"; do
    src="$repo/$name"
    dst="$config/$name"
    [ -e "$src" ] || { echo "skip (not in repo): $name"; continue; }
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        echo "ok:      $dst"
    elif [ -e "$dst" ]; then
        echo "conflict (exists, left alone): $dst"
    else
        ln -s "$src" "$dst"
        echo "linked:  $dst"
    fi
done

echo "done"
