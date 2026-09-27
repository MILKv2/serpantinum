#!/usr/bin/env fish
# Emoji picker przez fuzzel (odpowiednik `caelestia emoji -p`).
# Lista wyciagnieta z caelestia-cli przed jego usunieciem; zrodlo: emojibase.
set list $HOME/.local/share/hypr-scripts/emojis.txt
test -f $list; or exit 1
set pick (fuzzel --dmenu --placeholder="Type to search emojis" < $list)
test -z "$pick"; and exit 0
echo -n (string split ' ' -- $pick)[1] | wl-copy
wtype -M ctrl -M shift v -m shift -m ctrl 2>/dev/null
