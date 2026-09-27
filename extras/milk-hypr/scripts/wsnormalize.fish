#!/usr/bin/env fish
# wsnormalize.fish
#
# Ustawia kazdemu monitorowi workspace z JEGO grupy (patrz wsaction.fish:
# monitory po X, pierwszy = ws 1-10, drugi = ws 11-20, ...).
#
# Po co: przy starcie Hyprland daje kazdemu monitorowi pierwszy wolny workspace,
# czyli HDMI = 1, laptop = 2. A ws 2 nalezy do grupy HDMI - wiec "nastepny ws" na
# HDMI (1 -> 2) trafial w workspace wiszacy na laptopie i Hyprland przerzucal tam
# fokus. Dopiero ruszenie wsami na laptopie (na 11+) zwalnialo ws 2.
#
# Odpalane z local.lua na hyprland.start i monitor.added. Idempotentne: monitor,
# ktory juz stoi na ws ze swojej grupy, nie jest ruszany.

set -l mons (hyprctl monitors -j)
set -l count (echo $mons | jq 'length')
test "$count" -gt 0; or exit 0

set -l focused (echo $mons | jq -r '.[] | select(.focused) | .name')
set -l wss (hyprctl workspaces -j)
set -l changed false

for i in (seq 0 (math "$count - 1"))
    set -l name (echo $mons | jq -r --argjson i $i '[.[]] | sort_by(.x) | .[$i].name')
    set -l active (echo $mons | jq -r --argjson i $i '[.[]] | sort_by(.x) | .[$i].activeWorkspace.id')
    set -l lo (math "$i * 10 + 1")
    set -l hi (math "$i * 10 + 10")

    # juz w swojej grupie (albo cos dziwnego, np. special) - nie ruszamy
    test "$active" -lt 1; and continue
    test "$active" -ge $lo -a "$active" -le $hi; and continue

    # Docelowy ws istnieje na INNYM monitorze -> fokus by tam przeskoczyl i
    # wyciagnal okna. Nie zgadujemy, zostawiamy.
    set -l owner (echo $wss | jq -r --argjson id $lo '.[] | select(.id == $id) | .monitor')
    if test -n "$owner" -a "$owner" != "$name"
        echo "wsnormalize: ws $lo jest na $owner, pomijam $name" >&2
        continue
    end

    hyprctl dispatch "hl.dsp.focus({ monitor = \"$name\" })" >/dev/null
    hyprctl dispatch "hl.dsp.focus({ workspace = \"$lo\" })" >/dev/null
    set changed true
end

# oddajemy fokus tam, gdzie byl
if test "$changed" = true -a -n "$focused"
    hyprctl dispatch "hl.dsp.focus({ monitor = \"$focused\" })" >/dev/null
end
