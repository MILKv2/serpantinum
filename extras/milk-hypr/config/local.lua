-- Moje ustawienia: uklad klawiszy przeniesiony 1:1 z Caelestii.
-- Ladowane jako ostatnie z hyprland.lua, wiec nadpisuje domyslki Serpantinum.
-- Funkcje shella Serpantinum sa zachowane, tylko przesuniete na klawisze,
-- ktorych Caelestia nie uzywala. Lista klawiszy: KEYBINDY.md w extras/milk-hypr forka MILKv2/serpantinum

local mainMod = _G.mainMod or "SUPER"

-------------------------------------------------------------------
-- Input
-------------------------------------------------------------------
hl.config({
  input = {
    kb_layout          = "pl",
    kb_options         = "",
    numlock_by_default = false,
    repeat_delay       = 250,
    repeat_rate        = 35,
    accel_profile      = "flat",
    sensitivity        = 0.3,
    focus_on_close     = 1,
    touchpad = {
      natural_scroll       = true,
      disable_while_typing = true,
      scroll_factor        = 0.3,
    },
  },
  binds  = { scroll_event_delay = 0 },
  -- Okno proszace o fokus (link z Discorda do otwartej przegladarki itp.)
  -- dostaje go od razu, razem z workspace'em i monitorem. Zastepuje latke 05
  -- (general.followUrgentWindows) - maintainer zamknal PR #300 wskazujac to ustawienie.
  misc   = { focus_on_activate = true },
  cursor = {
    hotspot_padding = 1,
    -- Kursor rysowany programowo, nie przez warstwe sprzetowa GPU.
    -- Uklad jest hybrydowy: HDMI wisi na NVIDII (primary), eDP na Intelu. Plaszczyzna
    -- kursora sprzetowego nie przechodzi przez kopiowanie miedzy GPU, wiec na ekranie
    -- laptopa kursor po prostu znikal. Domyslka to 2 ("auto"), ktora tego przypadku
    -- nie wykrywa. Koszt: minimalnie wiecej pracy CPU przy ruchu mysza.
    no_hardware_cursors = true,
  },
  gestures = {
    workspace_swipe_distance                 = 700,
    workspace_swipe_cancel_ratio             = 0.15,
    workspace_swipe_min_speed_to_force       = 5,
    workspace_swipe_direction_lock           = true,
    workspace_swipe_direction_lock_threshold = 10,
    workspace_swipe_create_new               = true,
  },
})

hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "up", action = "special", workspace_name = "special" })
hl.gesture({ fingers = 3, direction = "down", action = "special", workspace_name = "special" })

-------------------------------------------------------------------
-- Zdejmij domyslki Serpantinum, ktore koliduja z ukladem Caelestii
-------------------------------------------------------------------
local drop = {
  mainMod .. " + SPACE",            -- bylo play/pause  -> float
  mainMod .. " + Q",                -- bylo panel music -> zamknij okno
  mainMod .. " + C",                -- bylo clipboard   -> codium
  mainMod .. " + W",                -- bylo wallpaper   -> brave
  mainMod .. " + D",                -- bylo launcher    -> komunikatory
  mainMod .. " + R",                -- bylo reload      -> todo
  mainMod .. " + F",                -- bylo firefox     -> fullscreen z ramkami
  mainMod .. " + S",                -- bylo calendar    -> special workspace
  mainMod .. " + V",                -- bylo panel volume-> schowek
  mainMod .. " + SHIFT + F",        -- bylo float       -> (float jest na SPACE)
  mainMod .. " + SHIFT + Left", mainMod .. " + SHIFT + Right",
  mainMod .. " + SHIFT + Up",   mainMod .. " + SHIFT + Down",   -- byl resize -> przenoszenie
  "Print", "SHIFT + Print", mainMod .. " + Print", mainMod .. " + SHIFT + Print",
}
for i = 1, 10 do
  local key = tostring(i % 10)
  table.insert(drop, mainMod .. " + " .. key)
  table.insert(drop, mainMod .. " + SHIFT + " .. key)
end
for _, k in ipairs(drop) do hl.unbind(k) end

-------------------------------------------------------------------
-- Workspace'y (uklad Caelestii)
-------------------------------------------------------------------
-- Workspace'y sa w GRUPACH po 10 (grupa 1 = ws 1-10, grupa 2 = ws 11-20, ...),
-- tak jak w Caelestii. Skrypt wsaction.fish liczy docelowy numer:
--   Ctrl+Alt+N        -> ws N wewnatrz biezacej grupy
--   Ctrl+Super+N      -> przeskok na grupe N, zachowujac pozycje  (= "slidowanie")
--   Super+Alt+N       -> przenies okno na ws N w biezacej grupie
--   Ctrl+Super+Alt+N  -> przenies okno na grupe N
local wsaction = "~/.config/hypr/scripts/wsaction.fish"
local wsnormalize = "~/.config/hypr/scripts/wsnormalize.fish"
for i = 1, 10 do
  local n   = tostring(i)
  local key = tostring(i % 10)
  hl.bind("CTRL + ALT + " .. key,                    hl.dsp.exec_cmd(wsaction .. " focus " .. n))
  hl.bind("CTRL + " .. mainMod .. " + " .. key,      hl.dsp.exec_cmd(wsaction .. " -g focus " .. n))
  hl.bind(mainMod .. " + ALT + " .. key,             hl.dsp.exec_cmd(wsaction .. " move " .. n))
  hl.bind("CTRL + " .. mainMod .. " + ALT + " .. key, hl.dsp.exec_cmd(wsaction .. " -g move " .. n))
end

-- Skok o cala grupe scrollem
hl.bind("CTRL + " .. mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "-10" }))
hl.bind("CTRL + " .. mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "+10" }))

-- Sasiedni workspace strzalkami (Ctrl+Alt) + przenoszenie okna (Ctrl+Alt+Shift).
-- W Caelestii to siedzialo pod Ctrl+Super+Alt+Shift / Ctrl+Super+Shift - tamte
-- warianty zostaja nizej, te sa dodane bo tak wygodniej.
hl.bind("CTRL + ALT + Left",  hl.dsp.exec_cmd(wsaction .. " relfocus -1"), { repeating = true })
hl.bind("CTRL + ALT + Right", hl.dsp.exec_cmd(wsaction .. " relfocus 1"), { repeating = true })
hl.bind("CTRL + ALT + SHIFT + Left",  hl.dsp.exec_cmd(wsaction .. " relmove -1"), { repeating = true })
hl.bind("CTRL + ALT + SHIFT + Right", hl.dsp.exec_cmd(wsaction .. " relmove 1"), { repeating = true })

hl.bind("CTRL + " .. mainMod .. " + ALT + SHIFT + Left",  hl.dsp.exec_cmd(wsaction .. " relfocus -1"), { repeating = true })
hl.bind("CTRL + " .. mainMod .. " + ALT + SHIFT + Right", hl.dsp.exec_cmd(wsaction .. " relfocus 1"), { repeating = true })
hl.bind(mainMod .. " + Page_Up",   hl.dsp.exec_cmd(wsaction .. " relfocus -1"), { repeating = true })
hl.bind(mainMod .. " + Page_Down", hl.dsp.exec_cmd(wsaction .. " relfocus 1"), { repeating = true })
hl.bind(mainMod .. " + mouse_down", hl.dsp.exec_cmd(wsaction .. " relfocus -1"))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.exec_cmd(wsaction .. " relfocus 1"))

hl.bind("CTRL + " .. mainMod .. " + SHIFT + Left",  hl.dsp.exec_cmd(wsaction .. " relmove -1"), { repeating = true })
hl.bind("CTRL + " .. mainMod .. " + SHIFT + Right", hl.dsp.exec_cmd(wsaction .. " relmove 1"), { repeating = true })

-- Scratchpad
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("special"))
hl.bind(mainMod .. " + ALT + S", hl.dsp.window.move({ workspace = "special:special" }))

-------------------------------------------------------------------
-- Okna (uklad Caelestii)
-------------------------------------------------------------------
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("~/.config/hypr/scripts/togglefloat.fish"))
hl.bind("F11", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pin())

hl.bind(mainMod .. " + SHIFT + Left",  hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + Right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + Up",    hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + Down",  hl.dsp.window.move({ direction = "d" }))

hl.bind(mainMod .. " + ALT + Left",  hl.dsp.window.resize({ x = -100, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + ALT + Right", hl.dsp.window.resize({ x = 100,  y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + ALT + Up",    hl.dsp.window.resize({ x = 0, y = -100, relative = true }), { repeating = true })
hl.bind(mainMod .. " + ALT + Down",  hl.dsp.window.resize({ x = 0, y = 100,  relative = true }), { repeating = true })

hl.bind(mainMod .. " + minus", hl.dsp.window.resize({ x = -100, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + equal", hl.dsp.window.resize({ x = 100,  y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + minus", hl.dsp.window.resize({ x = 0, y = -100, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + equal", hl.dsp.window.resize({ x = 0, y = 100,  relative = true }), { repeating = true })

hl.bind(mainMod .. " + Z", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + X", hl.dsp.window.resize(), { mouse = true })
hl.bind("CTRL + " .. mainMod .. " + backslash", hl.dsp.window.center())

hl.bind("ALT + TAB", hl.dsp.window.cycle_next(), { repeating = true })
hl.bind("SHIFT + ALT + TAB", hl.dsp.window.cycle_next({ next = false }), { repeating = true })
hl.bind(mainMod .. " + U", hl.dsp.group.move_window())
hl.bind(mainMod .. " + comma", hl.dsp.group.toggle())

-------------------------------------------------------------------
-- Aplikacje (uklad Caelestii)
-------------------------------------------------------------------
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("uwsm app -- kitty"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("uwsm app -- brave"))
hl.bind("CTRL + ALT + V", hl.dsp.exec_cmd("uwsm app -- pavucontrol"))
-- Zdjete 2026-09-03: github-desktop (Super+G), nemo (Super+Alt+E), qps (Ctrl+Alt+Escape)
-- i codium (Super+C) - te programy NIE sa zainstalowane (nigdy nie byly, wg logu pacmana),
-- wiec bindy byly martwe juz w Caelestii. Jesli ktorys doinstalujesz, wroc tu.

-------------------------------------------------------------------
-- Shell Serpantinum na klawiszach Caelestii
-------------------------------------------------------------------
-- Launcher: tapniecie samego Super (tak jak w Caelestii)
hl.bind(mainMod .. " + Super_L", hl.dsp.exec_cmd("serpantinum msg toggle launcher"), { release = true })

hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("serpantinum msg toggle clipboard"))
hl.bind("CTRL + SHIFT + ESCAPE", hl.dsp.exec_cmd("serpantinum msg toggle system"))
hl.bind(mainMod .. " + ALT + W", hl.dsp.exec_cmd("serpantinum msg toggle wallpaper"))
hl.bind(mainMod .. " + ALT + C", hl.dsp.exec_cmd("serpantinum msg toggle calendar"))
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("serpantinum msg toggle volume"))
hl.bind("CTRL + " .. mainMod .. " + ALT + R", hl.dsp.exec_cmd("serpantinum reload"))

-- Scratchpady z aplikacja (odpowiednik `caelestia toggle ...`)
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("~/.config/hypr/scripts/scratchpad.fish music spotify spotify-launcher"))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("~/.config/hypr/scripts/scratchpad.fish communication vesktop vesktop"))
hl.bind("CTRL + SHIFT + ALT + ESCAPE", hl.dsp.exec_cmd("~/.config/hypr/scripts/scratchpad.fish sysmon btop 'kitty --class btop -e btop'"))

-------------------------------------------------------------------
-- Narzedzia
-------------------------------------------------------------------
-- Zrzuty ekranu - uklad z Caelestii (custom/keybinds.conf nadpisywal domyslke):
--   Print       = zaznaczanie regionu na ZAMROZONYM ekranie, prosto do schowka
--                 (`serpantinum screenshot` bez flag robi dokladnie to: freeze + overlay
--                  + wl-copy; `--full` to caly ekran, czyli NIE to)
--   Shift+Print = caly AKTYWNY monitor do schowka, bez zadnego okienka
hl.bind("Print", hl.dsp.exec_cmd("serpantinum screenshot"), { locked = true })
hl.bind("SHIFT + Print",
  hl.dsp.exec_cmd("grim -o \"$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')\" - | wl-copy"),
  { locked = true })
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("serpantinum screenshot"))
hl.bind(mainMod .. " + SHIFT + ALT + S", hl.dsp.exec_cmd("serpantinum screenshot --edit"))
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("serpantinum screenshot --full"), { locked = true })
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"))
hl.bind(mainMod .. " + ALT + I", hl.dsp.exec_cmd("~/.config/hypr/scripts/infinite-desktop/infinite-desktop-toggle.sh"))

hl.bind("CTRL + SHIFT + ALT + V",
  hl.dsp.exec_cmd("sleep 0.5s && ydotool type -d 1 \"$(cliphist list | head -1 | cliphist decode)\""),
  { locked = true })

hl.bind(mainMod .. " + SHIFT + L", hl.dsp.exec_cmd("systemctl suspend-then-hibernate"), { locked = true })

-- Media (uklad Caelestii)
hl.bind("CTRL + " .. mainMod .. " + SPACE", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("CTRL + " .. mainMod .. " + equal", hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("CTRL + " .. mainMod .. " + minus", hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-------------------------------------------------------------------
-- Autostart, ktorego Serpantinum nie ma
-------------------------------------------------------------------
hl.on("hyprland.start", function()
  hl.exec_cmd("trash-empty 30")
  hl.exec_cmd("mpris-proxy")
end)

-------------------------------------------------------------------
-- Reszta bindow z Caelestii (audyt 2026-09-03: brakowalo 32 kombinacji)
-------------------------------------------------------------------
-- Klawisze multimedialne
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"),     { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("XF86AudioStop", hl.dsp.exec_cmd("playerctl stop"),     { locked = true })
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })

-- Przenoszenie okna miedzy workspace'ami
hl.bind(mainMod .. " + ALT + Page_Up",   hl.dsp.exec_cmd(wsaction .. " relmove -1"), { repeating = true })
hl.bind(mainMod .. " + ALT + Page_Down", hl.dsp.exec_cmd(wsaction .. " relmove 1"), { repeating = true })
hl.bind(mainMod .. " + ALT + mouse_down", hl.dsp.exec_cmd(wsaction .. " relmove -1"))
hl.bind(mainMod .. " + ALT + mouse_up",   hl.dsp.exec_cmd(wsaction .. " relmove 1"))
hl.bind("CTRL + " .. mainMod .. " + SHIFT + Up",   hl.dsp.window.move({ workspace = "special:special" }))
hl.bind("CTRL + " .. mainMod .. " + SHIFT + Down", hl.dsp.window.move({ workspace = "+0" }))

-- Grupy okien
hl.bind("CTRL + ALT + TAB",         hl.dsp.group.next(), { repeating = true })
hl.bind("CTRL + SHIFT + ALT + TAB", hl.dsp.group.prev(), { repeating = true })
hl.bind(mainMod .. " + SHIFT + comma", hl.dsp.group.lock_active())

-- Rozmiary okna
hl.bind("CTRL + " .. mainMod .. " + ALT + backslash",
  hl.dsp.exec_cmd("~/.config/hypr/scripts/resize-preset.fish 55 70 center"))
hl.bind(mainMod .. " + ALT + backslash", hl.dsp.exec_cmd("~/.config/hypr/scripts/pip.fish"))

-- Nagrywanie ekranu
hl.bind(mainMod .. " + ALT + R", hl.dsp.exec_cmd("serpantinum screenshot --record"))
hl.bind("CTRL + ALT + R",        hl.dsp.exec_cmd("serpantinum screenshot --record"))
hl.bind(mainMod .. " + SHIFT + ALT + R", hl.dsp.exec_cmd("serpantinum screenshot --record"))

-- Panele i narzedzia
hl.bind("CTRL + ALT + DELETE", hl.dsp.exec_cmd("serpantinum msg toggle quickactions"))
hl.bind("CTRL + ALT + C",      hl.dsp.exec_cmd("serpantinum msg toggle notifications"), { locked = true })
hl.bind(mainMod .. " + period", hl.dsp.exec_cmd("pkill fuzzel || ~/.config/hypr/scripts/emoji.fish"))
hl.bind(mainMod .. " + ALT + V", hl.dsp.exec_cmd("serpantinum msg toggle clipboard"))

-------------------------------------------------------------------
-- Workspace'y PER MONITOR - DYNAMICZNIE
-------------------------------------------------------------------
-- NIE przypinamy zakresow do nazw monitorow (`hl.workspace_rule` z monitor=...).
-- Przy odpietym HDMI grupa 1 wisiala na nieistniejacym ekranie i na samym laptopie
-- robil sie balagan. Zamiast tego grupe wylicza `wsaction.fish` w locie:
-- monitory sortowane po pozycji X, pierwszy = grupa 1 (ws 1-10), drugi = grupa 2
-- (ws 11-20). Z jednym ekranem wszystko siedzi w grupie 1, wiec laptop solo dziala
-- normalnie i nic nie trzeba przestawiac.

-------------------------------------------------------------------
-- Reguly okien: aplikacje ladujace od razu na swoim scratchpadzie
-- (port z rules.conf Caelestii - dzieki temu okno rodzi sie na miejscu,
--  zamiast byc przenoszone po fakcie przez scratchpad.fish)
-------------------------------------------------------------------
hl.window_rule({
  name = "ws-music",
  match = { class = "(?i)^(spotify|feishin|supersonic|cider|plexamp)$" },
  workspace = "special:music",
})
hl.window_rule({
  name = "ws-music-title",
  match = { initial_title = "^Spotify( Free)?$" },
  workspace = "special:music",
})
hl.window_rule({
  name = "ws-communication",
  match = { class = "(?i)^(discord|equibop|vesktop|whatsapp)$" },
  workspace = "special:communication",
})
hl.window_rule({
  name = "ws-sysmon",
  match = { class = "(?i)^btop$" },
  workspace = "special:sysmon",
})

-------------------------------------------------------------------
-- Po podpieciu monitora: kazdy ekran na ws ze swojej grupy (wsnormalize.fish)
-------------------------------------------------------------------
-- Pozycje monitorow ustawiasz w Serpantinum (Display) albo w config/monitors.lua -
-- tu celowo nic nie jest wpisane na sztywno.
hl.on("monitor.added", function()
  hl.timer(function() hl.exec_cmd(wsnormalize) end, { timeout = 900, type = "oneshot" })
end)

-- Przy starcie Hyprland daje laptopowi ws 2 (pierwszy wolny), ktory nalezy do grupy
-- HDMI - wtedy "nastepny ws" na HDMI przerzucal fokus na laptopa. Normalizujemy.
hl.on("hyprland.start", function()
  hl.timer(function() hl.exec_cmd(wsnormalize) end, { timeout = 1000, type = "oneshot" })
end)
