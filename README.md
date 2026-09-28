# arch-dotfiles

Hyprland desktop dotfiles for Arch, version-controlled here and symlinked into
`~/.config`. The repo is local-only (no remote).

## Quick start

```bash
./setup.sh --dry-run     # preview everything, change nothing
./setup.sh               # packages + services + symlinks + shell
```

`setup.sh` re-executes itself with sudo, but every user-scoped step (yay,
makepkg, symlinks, oh-my-zsh, gsettings) runs as the invoking user.

| flag | effect |
| --- | --- |
| `--dry-run` | print commands instead of running them (no elevation) |
| `--with-dev` | also install `jdk-openjdk gradle kotlin` |
| `--with-reflector` | write `/etc/xdg/reflector/reflector.conf`, refresh mirrorlist, enable `reflector.timer` (`REFLECTOR_COUNTRY=...` overrides the default `Indonesia`) |
| `--no-shell` | skip `chsh` + oh-my-zsh |
| `--no-config` | skip symlink step + gsettings sync |
| `--help` | usage |

What it does, in order:

1. `pacman -Syu` with the package set (Hyprland session, waybar/rofi/mako,
   awww+matugen, kitty, apps, fonts, `ly`, …).
2. AUR — installs `adw-gtk-theme-git` through `yay`, bootstrapping `yay-bin`
   from the AUR first if the helper is missing (always built as the user).
3. `systemctl enable --now ly@tty2 NetworkManager bluetooth`.
4. Optional reflector mirrorlist setup.
5. zsh as the default shell + oh-my-zsh (only if `~/.oh-my-zsh` is absent).
6. `install.sh` to link `~/.config` entries, regenerate the gitignored
   `matugen/generated/*` colors from the current wallpaper (so rofi/waybar/mako
   aren't unstyled after a fresh clone), then a gsettings sync for the
   font/theme/icon state.

## Symlinks only

`install.sh` does just the linking, and is safe to re-run any time:

```bash
./install.sh
```

Each tracked entry is linked as `~/.config/<name>` -> `/home/adriel/arch-dotfiles/<name>`.
Existing non-symlink files are left alone and reported as conflicts.

## Layout

| path | contents |
| --- | --- |
| `hypr/` | hyprland, hypridle, hyprlock, scripts |
| `waybar/` | config + `style.css` (theme state lives in `waybar/theme/`, gitignored) |
| `rofi/` | base + theme rasi, bluetooth menu script |
| `matugen/` | wallpaper-driven color generation: `config.toml` + templates for gtk3/gtk4/qtct/rofi/waybar/kitty/mako/hyprland |
| `kitty/`, `mako/`, `bluetui/`, `htop/`, `lazygit/`, `pavucontrol.ini` | app configs |
| `gtk-3.0/`, `gtk-4.0/`, `qt5ct/`, `qt6ct/`, `nwg-look/`, `xsettingsd/` | toolkit theme/icon settings |

Ignored on purpose: `matugen/generated/`, `*.bak`, `waybar/bak/`, theme toggle
locks. `~/.config/{dconf,go,pulse}` and LibreOffice stay outside the repo.

## Theme and font decisions

- **Theme:** `adw-gtk3-dark` (AUR `adw-gtk-theme-git`) — required, because the
  tracked configs point at it and it has no official-repo package.
- **Font:** `JetBrainsMono Nerd Font Propo` everywhere — 10pt in GTK,
  13pt in rofi, 12pt in Qt, plus the same string in
  `org.gnome.desktop.interface font-name`. The GSettings value is the live
  source of truth; `gtk-4.0/settings.ini` is a fallback for non-GTK portal apps.
- **Icons:** `Papirus-Dark` (official repo).

## Colors from the wallpaper

Pick a wallpaper with `Super+W` (`rofi/scripts/wallpaper_menu.sh`) or the waybar
theme module (left/right/middle click -> `waybar/scripts/theme_toggle.sh`).
Both end up calling `matugen image <path>`:

1. `matugen/config.toml` templates write into `matugen/generated/`
   (gitignored — build output): the rofi palette, waybar css, mako include,
   qtct color schemes, and the GTK css symlinks.
2. `[config.wallpaper]` applies the image through `awww`.
3. The `post_hook`s refresh waybar, relink `gtk-3.0/gtk.css` /
   `gtk-4.0/gtk.css`, and push `gtk-theme` / `icon-theme` via gsettings.

`rofi/themes/colors.rasi` is a symlink to
`matugen/generated/rofi-colors.rasi`, so rofi's palette follows the wallpaper
automatically (it used to be a hand-copied snapshot that drifted). The same
applies to the tracked `gtk-3.0/gtk.css` and `gtk-4.0/gtk.css` symlinks.

`setup.sh` runs `matugen image <current wallpaper>` when those generated files
are missing, so run it (or pick a wallpaper) once after cloning.

## Manual leftovers

- ALSA mute LED: `echo 'options snd_hda_intel jackpoll_ms=20' | sudo tee /etc/modprobe.d/mute-led.conf`, then reboot (remove the file if it misbehaves).
- Check monitors after install: `hyprctl monitors all`.
- Reboot to log in through `ly@tty2`.

## Credits

These dotfiles draw from two projects:

- [BrewLand](https://github.com/BeetleBot/BrewLand/) — BeetleBot's minimal Catppuccin Mocha Hyprland dotfiles; the base this setup was built on.
- [dusky](https://github.com/dusklinux/dusky) — dusklinux's desktop suite; the notification modules, waybar scripts and `dusky-run` wrappers in this setup originally came from it.
