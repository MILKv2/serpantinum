#!/usr/bin/env fish
# resize-preset.fish <procent-szerokosci> <procent-wysokosci> [center]
# Odpowiednik "resizeactive, exact X% Y%" ze starego configu - hl.dsp.window.resize
# bierze piksele, wiec procenty liczymy z geometrii aktywnego monitora.
set wp $argv[1]; set hp $argv[2]
set mon (hyprctl monitors -j | jq -r 'first(.[] | select(.focused))')
set w (echo $mon | jq -r .width); set h (echo $mon | jq -r .height)
set s (echo $mon | jq -r .scale)
set lw (math "round($w / $s * $wp / 100)")
set lh (math "round($h / $s * $hp / 100)")
hyprctl dispatch "hl.dsp.window.resize({ x = $lw, y = $lh })" >/dev/null
if contains center $argv
    hyprctl dispatch 'hl.dsp.window.center()' >/dev/null
end
