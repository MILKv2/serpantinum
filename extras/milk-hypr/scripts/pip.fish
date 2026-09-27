#!/usr/bin/env fish
# Picture-in-picture: odpowiednik `caelestia resizer pip`.
# Aktywne okno -> plywajace, male, przypiete, w prawym dolnym rogu.
set floating (hyprctl activewindow -j | jq -r .floating)
if test "$floating" = "false"
    hyprctl dispatch 'hl.dsp.window.float({ action = "toggle" })' >/dev/null
end
set mon (hyprctl monitors -j | jq -r 'first(.[] | select(.focused))')
set w (echo $mon | jq -r .width); set h (echo $mon | jq -r .height)
set s (echo $mon | jq -r .scale)
set mx (echo $mon | jq -r .x); set my (echo $mon | jq -r .y)
set lw (math "round($w / $s * 0.25)"); set lh (math "round($h / $s * 0.25)")
set px (math "round($mx + $w / $s - $lw - 20)")
set py (math "round($my + $h / $s - $lh - 20)")
hyprctl dispatch "hl.dsp.window.resize({ x = $lw, y = $lh })" >/dev/null
hyprctl dispatch "hl.dsp.window.move({ x = $px, y = $py })" >/dev/null
hyprctl dispatch 'hl.dsp.window.pin()' >/dev/null
