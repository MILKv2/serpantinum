#!/usr/bin/env fish
# Odplywajace okno dostaje 60%x70% i ladzie na srodku; z powrotem do kafelka bez zmian.
# Wersja bez zaleznosci od `caelestia resizer`.
#
# UWAGA (Hyprland na configu Lua): `hyprctl dispatch` przyjmuje juz TYLKO wyrazenie Lua.
# "dispatch togglefloating" / "dispatch resizeactive exact W H" / "dispatch centerwindow 1"
# koncza sie bledem parsera - stad hl.dsp.*.

set floating (hyprctl activewindow -j | jq -r .floating)

if test "$floating" = "false"
    set mon (hyprctl monitors -j | jq -r 'first(.[] | select(.focused))')
    set w (echo $mon | jq -r .width)
    set h (echo $mon | jq -r .height)
    set scale (echo $mon | jq -r .scale)
    set lw (math "round($w / $scale * 0.6)")
    set lh (math "round($h / $scale * 0.7)")

    hyprctl dispatch 'hl.dsp.window.float({ action = "toggle" })' >/dev/null
    hyprctl dispatch "hl.dsp.window.resize({ x = $lw, y = $lh })" >/dev/null
    hyprctl dispatch 'hl.dsp.window.center()' >/dev/null
else
    hyprctl dispatch 'hl.dsp.window.float({ action = "toggle" })' >/dev/null
end
