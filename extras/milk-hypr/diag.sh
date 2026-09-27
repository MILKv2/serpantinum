#!/usr/bin/env bash
# Zbiera stan Hyprlanda/Serpantinum do jednego pliku. NICZEGO nie zmienia.
# Wynik: ~/diag-serpantinum.txt
OUT="$HOME/diag-serpantinum.txt"
H="$HOME/.config/hypr"

sec() { printf '\n==================== %s\n' "$1"; }
show() { for f in "$@"; do [ -f "$f" ] && { printf -- '--- %s\n' "$f"; cat "$f"; }; done; }
mon() { grep -n -E 'hl\.monitor|output|position|mode|scale|applyMonitorLayout|workspace_rule' "$1" 2>/dev/null; }

{
sec "data / wersje"
date; uname -r
hyprctl version 2>&1 | head -2
cat "$HOME/.local/state/serpantinum/version" 2>&1
git -C "${XDG_CACHE_HOME:-$HOME/.cache}/serpantinum-installer" log --oneline -1 2>&1
git -C "${XDG_CACHE_HOME:-$HOME/.cache}/serpantinum-installer" remote get-url origin 2>&1

sec "monitory (podlaczone + dostepne tryby)"
hyprctl monitors all -j 2>&1 | jq -r '.[] | "\(.name) | \(.description) | \(.width)x\(.height)@\(.refreshRate) | pos \(.x)x\(.y) | scale \(.scale) | disabled \(.disabled)\n   tryby: \(.availableModes | join(" "))"' 2>&1

sec "bledy configu"
hyprctl configerrors 2>&1

sec "narzedzia"
for t in fish jq fuzzel wl-copy; do printf '%s: %s\n' "$t" "$(command -v "$t" || echo BRAK)"; done

sec "obecny ~/.config/hypr"
find "$H" -maxdepth 2 -printf '%TY-%Tm-%Td %TH:%TM  %p\n' 2>&1 | sort -k3
show "$H/hyprland.lua" "$H/config/monitors.lua"
printf -- '--- monitory w local.lua:\n'; mon "$H/config/local.lua"
printf -- '--- pierwsze bindy w local.lua:\n'; grep -n 'hl.bind' "$H/config/local.lua" 2>/dev/null | head -15

sec "kopie zrobione przez instalator (~/.config/hypr_backup)"
for d in $(ls -1dt "$HOME"/.config/hypr_backup/backup_* 2>/dev/null); do
    printf '\n##### %s\n' "$d"
    ls "$d/config" 2>&1 | tr '\n' ' '; echo
    show "$d/config/monitors.lua"
    printf -- '--- monitory w local.lua:\n'; mon "$d/config/local.lua"
    [ -f "$d/config/local.lua" ] && printf 'local.lua: %s linii, %s bindow\n' "$(wc -l < "$d/config/local.lua")" "$(grep -c 'hl.bind' "$d/config/local.lua")"
done

sec "kopie zrobione przez extras (~/.config/hypr-backup-*)"
ls -1d "$HOME"/.config/hypr-backup-* 2>&1

sec "ustawienia serpantinum"
ls -la "$HOME/.config/serpantinum/" 2>&1
for f in "$HOME"/.config/serpantinum/settings.json*; do
    printf -- '--- %s: %s kluczy, wallpaperDir=%s, display=%s\n' "$f" \
        "$(jq 'keys|length' "$f" 2>&1)" "$(jq -c '.wallpaperDir' "$f" 2>&1)" "$(jq -c '.display' "$f" 2>&1)"
done

sec "kursor"
grep -n XCURSOR "$HOME/.config/uwsm/env" 2>&1
gsettings get org.gnome.desktop.interface cursor-theme 2>&1
} > "$OUT" 2>&1

echo "Zapisane: $OUT"
