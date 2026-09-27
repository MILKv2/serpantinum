#!/usr/bin/env fish
# scratchpad.fish <nazwa-ws> <regex-klasy> [komenda...]
#
# Odtwarza `caelestia toggle <cos>`: trzyma jedna aplikacje na special:<nazwa-ws>.
# Jesli okno nie istnieje - odpala komende i sciaga okno na ten special ws.
# Jesli istnieje ale wisi gdzie indziej - najpierw je zabiera.
# Na koncu przelacza widocznosc special workspace.
#
# UWAGA (Hyprland na configu Lua): `hyprctl dispatch` przyjmuje juz TYLKO wyrazenie
# Lua (skrot od `hl.dispatch(...)`). Stara skladnia "dispatch togglespecialworkspace x"
# albo reguly "[workspace special:x] cmd" przy exec koncza sie bledem parsera.

set ws $argv[1]
set class_re $argv[2]
set -e argv[1..2]

function client_addr -a re
    hyprctl clients -j | jq -r --arg re "$re" \
        'first(.[] | select(.class | test($re; "i")) | .address) // empty'
end

function move_here -a addr ws
    hyprctl dispatch "hl.dsp.window.move({ workspace = \"special:$ws\", window = \"address:$addr\", silent = true })" >/dev/null
end

set addr (client_addr $class_re)

if test -z "$addr"
    if test (count $argv) -gt 0
        uwsm app -- $argv >/dev/null 2>&1 &
        for i in (seq 120)
            sleep 0.25
            set addr (client_addr $class_re)
            if test -n "$addr"
                break
            end
        end
    end
    if test -z "$addr"
        exit 0
    end
    move_here $addr $ws
else
    set cur (hyprctl clients -j | jq -r --arg a "$addr" '.[] | select(.address==$a) | .workspace.name')
    if test "$cur" != "special:$ws"
        move_here $addr $ws
    end
end

hyprctl dispatch "hl.dsp.workspace.toggle_special(\"$ws\")" >/dev/null
