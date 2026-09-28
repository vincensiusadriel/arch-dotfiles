#!/usr/bin/env bash
# Arch bootstrap for the hyprland dotfiles in this repo: packages + post-install.
#
#   ./setup.sh                 full install (pacman, AUR, services, shell, links)
#   ./setup.sh --dry-run       print what would run, change nothing
#   ./setup.sh --with-reflector  configure mirrorlist + enable reflector.timer
#   ./setup.sh --with-dev      also install jdk-openjdk gradle kotlin
#   ./setup.sh --no-shell      skip zsh/oh-my-zsh/chsh
#   ./setup.sh --no-config     skip gsettings font sync + link step
#
# Run with sudo: the script re-executes itself as root, but every user-scoped
# step (yay, makepkg, symlinks, oh-my-zsh, gsettings) runs as the invoking user.

set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
user="${SUDO_USER:-$USER}"
home="$(getent passwd "$user" | cut -d: -f6)"
uid="$(id -u "$user")"
session_bus="unix:path=/run/user/$uid/bus"

DRY_RUN=0 WITH_REFLECTOR=0 WITH_DEVI=0 DO_SHELL=1 DO_CONFIG=1

usage() { sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)          DRY_RUN=1 ;;
        --with-dev)         WITH_DEVI=1 ;;
        --with-reflector)   WITH_REFLECTOR=1 ;;
        --no-shell)         DO_SHELL=0 ;;
        --no-config)        DO_CONFIG=0 ;;
        -h|--help)          usage 0 ;;
        *) echo "unknown option: $1 (see --help)" >&2; exit 2 ;;
    esac
    shift
done

# --- output helpers -----------------------------------------------------------
step() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
note() { printf '    %s\n' "$*"; }
die()  { printf '\033[31merror: %s\033[0m\n' "$*" >&2; exit 1; }

run() {  # run <cmd...> : executes, or echoes under --dry-run
    if [ "$DRY_RUN" = 1 ]; then printf '[dry-run] %s\n' "$*"; else "$@"; fi
}
run_bash() { # run_bash <string> : shell snippet, quoted for dry-run
    if [ "$DRY_RUN" = 1 ]; then printf '[dry-run] %s\n' "$*"; else bash -c "$*"; fi
}
run_user() { # run_user <cmd...> : as the real user, never as root
    if [ "$(id -u)" = 0 ]; then
        if [ "$DRY_RUN" = 1 ]; then printf '[dry-run] sudo -u %s -H -- %s\n' "$user" "$*"; else sudo -u "$user" -H -- "$@"; fi
    else
        run "$@"
    fi
}
run_user_bash() {
    if [ "$(id -u)" = 0 ]; then
        if [ "$DRY_RUN" = 1 ]; then printf '[dry-run] sudo -u %s -H -- %s\n' "$user" "$*"; else sudo -u "$user" -H -- bash -c "$*"; fi
    else
        run_bash "$*"
    fi
}

# --- self-elevate -------------------------------------------------------------
if [ "$(id -u)" != 0 ] && [ "$DRY_RUN" = 0 ]; then
    exec sudo -E env SUDO_USER="$user" bash "$0" "$@"
fi

# --- packages -----------------------------------------------------------------
PKGS_BASE=(
    git base-devel jq lsof fastfetch reflector curl
)
PKGS_SESSION=(
    hyprland xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    polkit hypridle hyprlock hyprpolkitagent qt5ct qt6ct
    qt5-wayland qt6-wayland xdg-utils
)
PKGS_BAR=(waybar rofi mako nwg-look gnome-themes-extra xsettingsd)
PKGS_WALL=(awww matugen)
PKGS_TERM=(kitty zsh zsh-completions wl-clipboard)
PKGS_APPS=(
    nemo imv mpv bluetui pavucontrol alsa-utils
    bluez bluez-utils libnotify
    pipewire pipewire-pulse pipewire-alsa wireplumber
    htop lazygit fzf
)
PKGS_NET=(networkmanager playerctl brightnessctl cliphist)
PKGS_SHOT=(flameshot grim slurp)
PKGS_FONTS=(ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji noto-fonts-cjk)
PKGS_DM=(ly)
PKGS_ICONS=(papirus-icon-theme)
PKGS_DEV=(jdk-openjdk gradle kotlin)

PKGS=("${PKGS_BASE[@]}" "${PKGS_SESSION[@]}" "${PKGS_BAR[@]}" "${PKGS_WALL[@]}"
      "${PKGS_TERM[@]}" "${PKGS_APPS[@]}" "${PKGS_NET[@]}" "${PKGS_SHOT[@]}"
      "${PKGS_FONTS[@]}" "${PKGS_DM[@]}" "${PKGS_ICONS[@]}")
[ "$WITH_DEVI" = 1 ] && PKGS+=("${PKGS_DEV[@]}") || true

AUR_PKGS=(adw-gtk-theme-git)

# --- 1. pacman ----------------------------------------------------------------
step "Installing ${#PKGS[@]} packages from the official repos"
run pacman -Syu --needed --noconfirm "${PKGS[@]}"
if [ "$WITH_DEVI" = 1 ]; then
    note "dev toolchain requested: ${PKGS_DEV[*]}"
fi

# --- 2. AUR -------------------------------------------------------------------
step "Installing AUR packages: ${AUR_PKGS[*]}"
if ! command -v yay >/dev/null 2>&1; then
    note "yay not found - bootstrapping it (builds as $user, never as root)"
    run_user_bash 'set -e
        tmp=$(mktemp -d); trap "rm -rf $tmp" EXIT
        git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
        cd "$tmp/yay-bin"; makepkg -sf --noconfirm
        pacman -U --noconfirm --needed *.pkg.tar.*'
fi
run_user_bash 'yay -S --needed --noconfirm '"${AUR_PKGS[*]}"''

# --- 3. services --------------------------------------------------------------
step "Enabling services"
run systemctl enable --now ly@tty2 NetworkManager bluetooth
note "ly@tty2 is the display manager - a reboot (or startx-less login) picks it up"

# --- 4. reflector (optional) --------------------------------------------------
if [ "$WITH_REFLECTOR" = 1 ]; then
    step "Configuring reflector (country: ${REFLECTOR_COUNTRY:-Indonesia})"
    run_bash 'mkdir -p /etc/xdg/reflector && cat > /etc/xdg/reflector/reflector.conf <<EOF
--save /etc/pacman.d/mirrorlist
--country '"${REFLECTOR_COUNTRY:-Indonesia}"'
--protocol https
--latest 15
--sort rate
EOF'
    run reflector --save /etc/pacman.d/mirrorlist \
        --country "${REFLECTOR_COUNTRY:-Indonesia}" --protocol https --latest 15 --sort rate
    run systemctl enable --now reflector.timer
else
    step "Skipping reflector (pass --with-reflector to configure it)"
fi

# --- 5. shell (optional) ------------------------------------------------------
if [ "$DO_SHELL" = 1 ]; then
    step "Setting up zsh + oh-my-zsh for $user"
    if [ ! -d "$home/.oh-my-zsh" ]; then
        run_user_bash 'CHSH=no RUNZSH=no KEEP_ZSHRC=yes sh -c \
            "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
    else
        note "~/.oh-my-zsh already present - left alone"
    fi
    run chsh -s /usr/bin/zsh "$user"
    note "default shell -> /usr/bin/zsh (re-login to take effect)"
else
    step "Skipping shell setup (--no-shell)"
fi

# --- 6. dotfile links + theme state (optional) --------------------------------
if [ "$DO_CONFIG" = 1 ]; then
    step "Linking ~/.config entries to this repo"
    run_user "$repo/install.sh"

    if [ "$DRY_RUN" = 0 ] && [ -S "/run/user/$uid/bus" ]; then
        step "Syncing GSettings font (source of truth for GTK) "
        run_user_bash 'export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/'"$uid"'/bus
            gsettings set org.gnome.desktop.interface font-name "JetBrainsMono Nerd Font Propo 10" || true
            gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3-dark" || true
            gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark" || true'
    elif [ "$DRY_RUN" = 1 ]; then
        step "Would sync GSettings font/theme over $session_bus"
    else
        note "no session bus at $session_bus - skipped gsettings sync"
    fi
else
    step "Skipping config step (--no-config)"
fi

# --- done ---------------------------------------------------------------------
step "Done"
cat <<EOF
    manual leftovers:
      * ALSA mute-LED (ThinkPad-style mic LED, once):
          echo 'options snd_hda_intel jackpoll_ms=20' | sudo tee /etc/modprobe.d/mute-led.conf
        then reboot; if it misbehaves remove the file.
      * check monitor layout:  hyprctl monitors all
      * wallhaven/matugen wallpaper seeding (see ~/awww-matugen-setup-plan.md)
      * reboot to log in through ly@tty2
EOF
