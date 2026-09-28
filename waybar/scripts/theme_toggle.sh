#!/usr/bin/env bash
# ==============================================================================
# THEME TOGGLE - Simple light/dark mode switcher
# ==============================================================================
# Usage:
#   theme_toggle          # Toggle between light and dark
#   theme_toggle light    # Set light mode
#   theme_toggle dark     # Set dark mode
# ==============================================================================

set -euo pipefail

# --- CONFIG ---
readonly STATE_DIR="$HOME/.config/waybar/theme"
readonly STATE_FILE="${STATE_DIR}/state"
readonly LOCK_FILE="${STATE_DIR}/.toggle.lock"
readonly WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
readonly MATUGEN_TYPE="scheme-tonal-spot"
readonly MATUGEN_CONTRAST="0"

# --- HELPERS ---
log()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

check_deps() {
    local cmd
    local -a missing=()
    for cmd in "$@"; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    (( ${#missing[@]} == 0 )) || die "Missing required commands: ${missing[*]}"
}

# --- STATE MANAGEMENT ---
read_state() {
    if [[ -f "$STATE_FILE" ]]; then
        local state
        state=$(<"$STATE_FILE")
        state="${state,,}"
        state="${state%%[[:space:]]*}"
        case "$state" in
            light|dark) printf '%s' "$state"; return ;;
        esac
    fi
    printf 'dark'
}

write_state() {
    local mode="$1"
    mkdir -p "$STATE_DIR"
    local tmp
    tmp=$(mktemp "${STATE_DIR}/state.XXXXXX")
    printf '%s\n' "$mode" > "$tmp"
    mv -fT -- "$tmp" "$STATE_FILE"
}

# --- WALLPAPER ---
get_current_wallpaper() {
    local query_output line wallpaper=""

    if command -v awww >/dev/null 2>&1; then
        query_output=$(awww query 2>/dev/null) || true
        while IFS= read -r line; do
            if [[ "$line" == *"currently displaying: image: "* ]]; then
                wallpaper="${line##*image: }"
                wallpaper="${wallpaper%%[[:space:]]*}"
                break
            fi
        done <<< "$query_output"
    fi

    if [[ -n "$wallpaper" && -f "$wallpaper" ]]; then
        printf '%s' "$wallpaper"
        return 0
    fi

    # Fallback: pick random from wallpaper dir
    if [[ -d "$WALLPAPER_DIR" ]]; then
        local -a files=()
        mapfile -t files < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \
            \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | sort -R)
        if (( ${#files[@]} > 0 )); then
            printf '%s' "${files[0]}"
            return 0
        fi
    fi

    return 1
}

# --- MATUGEN ---
generate_colors() {
    local img="$1"
    local mode="$2"

    [[ -f "$img" ]] || die "Wallpaper not found: $img"

    log "Generating colors: mode=${mode} image=${img##*/}"

    local -a cmd=(matugen --mode "$mode")
    [[ "$MATUGEN_TYPE" != "disable" ]] && cmd+=(--type "$MATUGEN_TYPE")
    [[ "$MATUGEN_CONTRAST" != "0" && "$MATUGEN_CONTRAST" != "disable" ]] && cmd+=(--contrast "$MATUGEN_CONTRAST")
    cmd+=(image "$img")

    local output
    if ! output=$("${cmd[@]}" 2>&1); then
        die "Matugen failed: $output"
    fi

    # Update GNOME color-scheme if available
    if command -v gsettings >/dev/null 2>&1; then
        gsettings set org.gnome.desktop.interface color-scheme "prefer-${mode}" 2>/dev/null || true
    fi
}

# --- MAIN ---
main() {
    check_deps flock matugen

    mkdir -p "$STATE_DIR"
    exec 99>"$LOCK_FILE"
    flock -n 99 || exit 0

    local current_mode
    current_mode=$(read_state)

    # Parse argument
    local target_mode=""
    case "${1:-}" in
        light)  target_mode="light" ;;
        dark)   target_mode="dark" ;;
        "")     target_mode=$( [[ "$current_mode" == "dark" ]] && echo "light" || echo "dark" ) ;;
        *)      die "Usage: theme_toggle [light|dark]" ;;
    esac

    # Get current wallpaper
    local wallpaper
    wallpaper=$(get_current_wallpaper) || die "No wallpaper found. Set one first."

    # Generate colors for new mode
    generate_colors "$wallpaper" "$target_mode"

    # Save state
    write_state "$target_mode"

    log "Theme changed: ${current_mode} → ${target_mode}"
}

main "$@"
