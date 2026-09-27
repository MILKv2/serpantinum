#!/usr/bin/env bash
# Dogrywa skrypty workspace'ow/scratchpadow (+ fish) do ~/.config/hypr.
# Uruchamiac PO instalatorze Serpantinum (install/install.sh). Idempotentny.
#
# Reinstall Serpantinum kasuje ~/.config/hypr (kopia laduje w ~/.config/hypr_backup/).
# Dlatego najpierw przywracamy WLASNY config z tej kopii - keybindy (local.lua) i
# ustawienia ekranow (monitors.lua) - a dopiero gdy go nie ma, bierzemy local.lua z forka.
set -euo pipefail

HERE="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
HYPR="$HOME/.config/hypr"
STAMP="$(date +%Y%m%d-%H%M%S)"

[ -f "$HYPR/hyprland.lua" ] || { echo "Brak $HYPR/hyprland.lua - najpierw zainstaluj Serpantinum."; exit 1; }

# Skrypty sa w fishu, a Serpantinum fisha nie instaluje - bez niego kazdy bind
# workspace'ow po cichu nic nie robi.
sudo pacman -S --needed --noconfirm fish jq fuzzel wl-clipboard

backup="$HOME/.config/hypr-backup-$STAMP"
mkdir -p "$backup"
cp -a "$HYPR/." "$backup/"
echo "Kopia obecnego configu: $backup"

mkdir -p "$HYPR/config" "$HYPR/scripts" "$HOME/.local/share/hypr-scripts"

# Najnowsza kopia instalatora, ktora ma wlasny local.lua
own=""
for d in $(ls -1dt "$HOME"/.config/hypr_backup/backup_* 2>/dev/null); do
    if [ -f "$d/config/local.lua" ]; then own="$d"; break; fi
done

if [ -n "$own" ] && [ ! -f "$HYPR/config/local.lua" ]; then
    echo "Przywracam wlasny config z $own"
    cp "$own/config/local.lua" "$HYPR/config/local.lua"
    [ -f "$own/config/monitors.lua" ] && cp "$own/config/monitors.lua" "$HYPR/config/monitors.lua"
elif [ ! -f "$HYPR/config/local.lua" ]; then
    echo "Brak wlasnego local.lua - biore uklad klawiszy z forka"
    cp "$HERE/config/local.lua" "$HYPR/config/local.lua"
else
    echo "local.lua juz jest - zostawiam"
fi

# Stary local.lua z innego komputera wymusza tamten uklad monitorow (Samsung + eDP-1
# 1920x1080@144 na 2560x0) przy kazdym podpieciu ekranu. Wylaczamy ten jeden hook.
if grep -q 'LS27CG51x' "$HYPR/config/local.lua" && grep -qE '^\s*hl.timer\(applyMonitorLayout,' "$HYPR/config/local.lua"; then
    sed -i 's/^\(\s*\)hl.timer(applyMonitorLayout,/\1-- wylaczone (uklad z innego komputera): hl.timer(applyMonitorLayout,/' "$HYPR/config/local.lua"
    echo "Wylaczono wymuszanie obcego ukladu monitorow w local.lua"
fi

cp -r "$HERE/scripts/." "$HYPR/scripts/"
chmod +x "$HYPR"/scripts/*.fish "$HYPR"/scripts/infinite-desktop/*.sh
cp "$HERE/share/emojis.txt" "$HOME/.local/share/hypr-scripts/emojis.txt"

# Kursor: Serpantinum go nie ustawia, wiec bez tego czesc aplikacji ma bialy domyslny.
# Ustawiamy wszedzie tam, skad rozne toolkity go czytaja.
CURSOR="Win11-Cursors-dark"
mkdir -p "$HOME/.local/share/icons" "$HOME/.icons/default" "$HOME/.config/uwsm"
cp -a "$HERE/share/icons/$CURSOR" "$HOME/.local/share/icons/"
printf '[Icon Theme]\nName=Default\nComment=Default Cursor Theme\nInherits=%s\n' "$CURSOR" > "$HOME/.icons/default/index.theme"
gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR" 2>/dev/null || true
gsettings set org.gnome.desktop.interface cursor-size 24 2>/dev/null || true
touch "$HOME/.config/uwsm/env"
sed -i '/^export XCURSOR_THEME=/d; /^export XCURSOR_SIZE=/d; /^export HYPRCURSOR_THEME=/d' "$HOME/.config/uwsm/env"
printf "export XCURSOR_THEME='%s'\nexport XCURSOR_SIZE='24'\n" "$CURSOR" >> "$HOME/.config/uwsm/env"
# Hyprland moze byc odpalony bez uwsm - wtedy liczy sie tylko to, co w jego configu
grep -q 'XCURSOR_THEME' "$HYPR/config/local.lua" \
    || printf '\n-- kursor (extras/milk-hypr)\nhl.env("XCURSOR_THEME", "%s")\nhl.env("XCURSOR_SIZE", "24")\n' "$CURSOR" >> "$HYPR/config/local.lua"
command -v hyprctl >/dev/null && hyprctl setcursor "$CURSOR" 24 >/dev/null 2>&1 || true

grep -q 'require("config/local")' "$HYPR/hyprland.lua" \
    || printf '\nrequire("config/local")\n' >> "$HYPR/hyprland.lua"

if command -v hyprctl >/dev/null && hyprctl version >/dev/null 2>&1; then
    hyprctl reload >/dev/null
    errs="$(hyprctl configerrors)"
    if [ -n "$errs" ]; then
        echo "UWAGA, bledy w configu Hyprlanda:"; echo "$errs"; exit 1
    fi
fi
echo "Gotowe. Klawisze: $HERE/KEYBINDY.md"
