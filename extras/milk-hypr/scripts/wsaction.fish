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

# Monitor-wlasciciel docelowej grupy (dla -g to INNY ekran niz ten pod kursorem).
set -l names (echo $mons | jq -r '[.[]] | sort_by(.x) | .[].name')
set -l owner_idx (math "floor(($target - 1) / 10) + 1")
set -l mon $names[$owner_idx]
test -z "$mon"; and set mon $names[(math "$idx + 1")]
set -l names_lua '{ '(string join ', ' (string replace -r '(.*)' '"$1"' -- $names))' }'

# Jedna funkcja Lua wewnatrz Hyprlanda (ta sama logika co bar/WorkspaceGroups.js
# w forku Serpantinum). Hyprland trzyma workspace na monitorze, na ktorym powstal,
# a przelaczenie na ws lezacy na innym ekranie przerzuca tam fokus. Przy starcie
# rozdaje ws po kolei zlaczy, nie od lewej, a nowy ws tworzy na monitorze z
# fokusem klawiatury, niekoniecznie tym pod kursorem. Wiec: ws z grupy lezacy
# gdzie indziej jest PRZENOSZONY tutaj, a przelaczenie dzieje sie na wlasciwym
# monitorze.
set -l act 'hl.dispatch(hl.dsp.focus({ monitor = mon })); hl.dispatch(hl.dsp.focus({ workspace = tostring(id) })); '
switch $action
    case move relmove
        set act 'if win then hl.dispatch(hl.dsp.window.move({ workspace = tostring(id), window = "address:" .. win.address })) end '
end

hyprctl dispatch "function() local names = $names_lua; local size = 10; "\
"local function groupOf(n) for i, v in ipairs(names) do if v == n then return i end end end "\
"local function monOf(id) local w = hl.get_workspace(id); return w and w.monitor and w.monitor.name end "\
"local function bring(id, mon) local on = monOf(id); if not on or on == mon then return end "\
"local om = hl.get_monitor(on); local ow = om and om.active_workspace; local oi = groupOf(on); "\
"if ow and ow.id == id and oi then local first = (oi - 1) * size + 1; local fon = monOf(first); "\
"if first ~= id and (not fon or fon == on) then hl.dispatch(hl.dsp.focus({ monitor = on })); "\
"hl.dispatch(hl.dsp.focus({ workspace = tostring(first) })); end end "\
"on = monOf(id); if on and on ~= mon then hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(id), monitor = mon })); end end "\
"local mon = \"$mon\"; local id = $target; local win = hl.get_active_window(); bring(id, mon); $act"\
"if monOf(id) and monOf(id) ~= mon then hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(id), monitor = mon })); end end" >/dev/null
