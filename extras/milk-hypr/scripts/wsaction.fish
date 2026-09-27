#!/usr/bin/env fish
# wsaction.fish [-g] <focus|move|relfocus|relmove> <n>
#
# Workspace'y w grupach po 10, po jednej grupie na monitor:
#   grupa 1 = ws 1-10, grupa 2 = ws 11-20, ...
#
# Grupa jest liczona DYNAMICZNIE z pozycji monitorow (sortowanie po X), a nie
# przypieta do nazwy ekranu. Dzieki temu:
#   - dwa monitory  -> lewy dostaje grupe 1, prawy grupe 2
#   - sam laptop    -> jest jedynym monitorem, wiec dostaje grupe 1 i wszystko
#                      dziala normalnie, bez zadnego przestawiania configu
#
#   focus <n>     ws <n> w grupie BIEZACEGO monitora   (na 13 + 5 -> 15)
#   move  <n>     przenies okno tamze
#   -g focus <n>  przeskocz na grupe <n>, zachowujac pozycje w grupie
#   -g move  <n>  przenies okno na grupe <n>
#   relfocus ±1   sasiedni ws WEWNATRZ grupy (na krancu nic nie robi)
#   relmove  ±1   przenies okno na sasiedni ws w grupie
#
# UWAGA: na configu Lua `hyprctl dispatch` bierze wyrazenie Lua, nie stara skladnie.

set group false
if test "$argv[1]" = '-g'
    set group true
    set -e argv[1]
end

if test (count $argv) -ne 2
    echo 'Usage: wsaction.fish [-g] <focus|move|relfocus|relmove> <n>' >&2
    exit 1
end

set -l action $argv[1]
set -l n $argv[2]

# Monitor bierzemy spod KURSORA, nie z "focused".
# Powod: przy pustym workspace na drugim ekranie fokus klawiatury zostaje na
# ostatnim oknie (czyli na monitorze glownym), mimo ze kursor jest juz na laptopie.
# Wtedy "focused" wskazywal glowny ekran i przelaczanie dzialo sie nie tam, gdzie
# patrzysz. Pozycja kursora jest jednoznaczna.
set -l cpos (hyprctl cursorpos 2>/dev/null | string replace -a ' ' '')
set -l cx (string split ',' -- $cpos)[1]
set -l cy (string split ',' -- $cpos)[2]

set -l mons (hyprctl monitors -j)
set -l idx ''
if test -n "$cx" -a -n "$cy"
    set idx (echo $mons | jq -r --argjson x $cx --argjson y $cy \
        '[.[]] | sort_by(.x) | to_entries
         | map(select(.value.x <= $x and $x < (.value.x + .value.width)
                  and .value.y <= $y and $y < (.value.y + .value.height)))
         | (.[0].key // empty)')
end
if test -z "$idx"
    # awaryjnie: monitor oznaczony jako focused
    set idx (echo $mons | jq -r '[.[]] | sort_by(.x) | to_entries | map(select(.value.focused)) | (.[0].key // 0)')
end
test -z "$idx"; and set idx 0

set -l mongroup (math "$idx + 1")
# workspace tego konkretnego monitora, a nie globalny "activeworkspace"
set -l active (echo $mons | jq -r --argjson i $idx '[.[]] | sort_by(.x) | .[$i].activeWorkspace.id')
test -z "$active"; and set active 1

# Pozycja w grupie: 1..10
set -l pos (math "($active - 1) % 10 + 1")

switch $action
    case focus move
        if test "$group" = true
            set target (math "($n - 1) * 10 + $pos")
        else
            set target (math "($mongroup - 1) * 10 + $n")
        end
    case relfocus relmove
        # Bez zawijania: na krancu grupy po prostu nic nie robimy.
        # Zawijanie (10 -> 1) probowalem i wygladalo zle: Hyprland dobiera kierunek
        # animacji po numerze workspace'a, wiec skok z 1 na 10 jedzie slajdem w PRAWO,
        # mimo ze logicznie cofasz sie na koniec. Pasek pokazywal jedno, animacja drugie.
        set -l newpos (math "$pos + $n")
        if test $newpos -gt 10 -o $newpos -lt 1
            exit 0
        end
        set target (math "($mongroup - 1) * 10 + $newpos")
    case '*'
        echo "unknown action: $action" >&2
        exit 1
end

switch $action
    case focus relfocus
        hyprctl dispatch "hl.dsp.focus({ workspace = \"$target\" })" >/dev/null
    case move relmove
        hyprctl dispatch "hl.dsp.window.move({ workspace = \"$target\" })" >/dev/null
end
