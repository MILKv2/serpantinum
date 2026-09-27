#!/usr/bin/env python3
"""
Infinite Desktop - przerobiona wersja skryptu sarodscommits/hyprland-infinite-desktop.

Co zmienione wzgledem oryginalu i DLACZEGO (oryginal chodzil "50/50"):

1. ORYGINAL SLUCHAL TYLKO JEDNEGO URZADZENIA.
   infinite-desktop.sh zgadywal po NAZWIE jedna klawiature i jedna mysz. Na tym
   sprzecie wybieral "COMPANY USB Device Keyboard" (klawiatura wbudowana w odbiornik
   myszy) i touchpada - czyli realna klawiatura Evision, klawiatura laptopa i mysz
   KRUX byly ignorowane. Stad losowosc: dzialalo tylko gdy uzywales akurat tego
   jednego urzadzenia. Teraz czytamy WSZYSTKIE urzadzenia z odpowiednimi
   capabilities (wykrywane po bitach z /sys, nie po nazwie).

2. STARA SKLADNIA hyprctl.
   `hyprctl dispatch movewindowpixel exact X Y,address:0x...` i `focuswindow`
   NIE dzialaja na configu Lua - hyprctl parsuje argument jako wyrazenie Lua.
   Teraz: hl.dsp.window.move({ x =, y =, window = "address:..." }).

3. WYDAJNOSC.
   Oryginal odpalal przy przeciaganiu 2 zapytania hyprctl + jeden proces NA OKNO
   w kazdej klatce (60x/s). Teraz stan okien jest zdejmowany raz, na starcie
   przeciagania, a kazda klatka to jeden `hyprctl --batch`. Przy okazji znika dryf,
   bo pozycje licza sie od snapshotu, a nie narastajaco z odczytow.
"""

import glob
import json
import os
import select
import struct
import subprocess
import sys
import threading
import time

EVENT_SIZE = struct.calcsize('llHHi')
EV_KEY, EV_REL = 1, 2
REL_X, REL_Y = 0, 1
KEY_LEFTCTRL, KEY_RIGHTCTRL = 29, 97
KEY_LEFTALT, KEY_RIGHTALT = 56, 100
KEY_LEFTMETA, KEY_RIGHTMETA = 125, 126
KEY_LEFT, KEY_RIGHT = 105, 106
KEY_A = 30
BTN_LEFT = 272

SPEED = float(sys.argv[1]) if len(sys.argv) > 1 else 1.6
STATE_FILE = "/tmp/infinite-desktop-state"
NAV_COOLDOWN = 0.2
PROTECTED_APPS = ['brave-browser', 'brave', 'chromium', 'chromium-browser',
                  'google-chrome', 'firefox', 'firefoxdeveloperedition',
                  'librewolf', 'vivaldi', 'opera', 'microsoft-edge']

lock = threading.Lock()
mods = {'super': False, 'alt': False, 'ctrl': False, 'btn': False}
acc_x = acc_y = 0.0
last_nav = 0.0


# --------------------------------------------------------------------------
# Wykrywanie urzadzen po capabilities (a nie po nazwie)
# --------------------------------------------------------------------------
def _bits(path):
    try:
        words = [int(w, 16) for w in open(path).read().split()]
    except OSError:
        return []
    words.reverse()          # words[0] = bity 0..63
    return words


def _has(words, bit):
    i, off = bit // 64, bit % 64
    return i < len(words) and bool((words[i] >> off) & 1)


def find_devices():
    keyboards, pointers = [], []
    for dev in sorted(glob.glob('/dev/input/event*')):
        base = os.path.basename(dev)
        cap = f'/sys/class/input/{base}/device/capabilities'
        key, rel = _bits(f'{cap}/key'), _bits(f'{cap}/rel')
        if not os.access(dev, os.R_OK):
            continue
        # klawiatura: ma zwykle klawisze literowe i modyfikatory
        if _has(key, KEY_A) and _has(key, KEY_LEFTCTRL):
            keyboards.append(dev)
        # wskaznik: ruch wzgledny w dwoch osiach + lewy przycisk
        if _has(rel, REL_X) and _has(rel, REL_Y) and _has(key, BTN_LEFT):
            pointers.append(dev)
    return keyboards, pointers


# --------------------------------------------------------------------------
# Hyprland
# --------------------------------------------------------------------------
def hypr_json(*args):
    try:
        r = subprocess.run(['hyprctl', *args, '-j'],
                           capture_output=True, text=True, timeout=0.5)
        return json.loads(r.stdout)
    except Exception:
        return None


def move_windows(moves):
    """moves: [(address, x, y)] -> jeden batch zamiast procesu na okno."""
    if not moves:
        return
    cmds = ' ; '.join(
        f'dispatch hl.dsp.window.move({{ x = {int(x)}, y = {int(y)}, '
        f'window = "address:{addr}" }})'
        for addr, x, y in moves
    )
    subprocess.Popen(['hyprctl', '--batch', cmds],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def inverted():
    try:
        return open(STATE_FILE).read().strip() == 'inverse'
    except OSError:
        return False


def floating_on_active():
    ws = hypr_json('activeworkspace')
    clients = hypr_json('clients')
    if not ws or not clients:
        return None, []
    wid = ws.get('id')
    return wid, [c for c in clients
                 if c.get('floating') and c.get('workspace', {}).get('id') == wid]


def monitor_center():
    mons = hypr_json('monitors') or []
    for m in mons:
        if m.get('focused'):
            return m['x'] + m['width'] // 2, m['y'] + m['height'] // 2
    if mons:
        m = mons[0]
        return m['x'] + m['width'] // 2, m['y'] + m['height'] // 2
    return 960, 540


def protected(win):
    return any(a in (win or {}).get('class', '').lower() for a in PROTECTED_APPS)


def change_focus(direction):
    global last_nav
    now = time.time()
    if now - last_nav < NAV_COOLDOWN:
        return
    last_nav = now

    _, wins = floating_on_active()
    if len(wins) <= 1:
        return

    focused = hypr_json('activewindow') or {}
    addrs = [w['address'] for w in wins]
    try:
        idx = addrs.index(focused.get('address'))
    except ValueError:
        idx = -1

    step = 1 if direction == 'right' else -1
    nxt = wins[(idx + step) % len(wins)] if idx >= 0 else wins[0]
    for _ in range(len(wins)):
        if not protected(nxt):
            break
        idx = addrs.index(nxt['address'])
        nxt = wins[(idx + step) % len(wins)]
    else:
        return

    cx, cy = monitor_center()
    dx = cx - (nxt['at'][0] + nxt['size'][0] // 2)
    dy = cy - (nxt['at'][1] + nxt['size'][1] // 2)
    move_windows([(w['address'], w['at'][0] + dx, w['at'][1] + dy) for w in wins])
    if not protected(nxt):
        subprocess.Popen(
            ['hyprctl', 'dispatch',
             f'hl.dsp.focus({{ window = "address:{nxt["address"]}" }})'],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


# --------------------------------------------------------------------------
# Czytanie wejscia - wszystkie urzadzenia naraz przez select()
# --------------------------------------------------------------------------
def reader(paths, handler):
    fds = {}
    for p in paths:
        try:
            fds[open(p, 'rb', buffering=0)] = p
        except OSError:
            pass
    if not fds:
        return
    while True:
        ready, _, _ = select.select(list(fds), [], [], 1.0)
        for f in ready:
            try:
                data = f.read(EVENT_SIZE)
            except OSError:
                continue
            if not data or len(data) < EVENT_SIZE:
                continue
            _, _, etype, code, value = struct.unpack('llHHi', data)
            handler(etype, code, value)


def on_key(etype, code, value):
    if etype != EV_KEY or value == 2:
        return
    with lock:
        if code in (KEY_LEFTMETA, KEY_RIGHTMETA):
            mods['super'] = value == 1
        elif code in (KEY_LEFTALT, KEY_RIGHTALT):
            mods['alt'] = value == 1
        elif code in (KEY_LEFTCTRL, KEY_RIGHTCTRL):
            mods['ctrl'] = value == 1
        elif value == 1 and mods['ctrl'] and mods['super'] and not mods['alt']:
            if code == KEY_RIGHT:
                threading.Thread(target=change_focus, args=('right',), daemon=True).start()
            elif code == KEY_LEFT:
                threading.Thread(target=change_focus, args=('left',), daemon=True).start()


def on_pointer(etype, code, value):
    global acc_x, acc_y
    with lock:
        if etype == EV_KEY and code == BTN_LEFT:
            mods['btn'] = value == 1
        elif etype == EV_REL:
            if mods['super'] and mods['alt'] and mods['btn']:
                sign = -1 if inverted() else 1
                if code == REL_X:
                    acc_x += value * SPEED * sign
                elif code == REL_Y:
                    acc_y += value * SPEED * sign
            else:
                acc_x = acc_y = 0.0


# --------------------------------------------------------------------------
def main():
    keyboards, pointers = find_devices()
    if not keyboards or not pointers:
        print('Brak dostepnych urzadzen wejscia (czy jestes w grupie "input"?)',
              file=sys.stderr)
        print(f'  klawiatury: {keyboards}\n  wskazniki:  {pointers}', file=sys.stderr)
        sys.exit(1)
    print(f'Infinite Desktop: {len(keyboards)} klawiatur, {len(pointers)} wskaznikow',
          flush=True)
    print('  Super+Alt+LPM przeciaga plotno, Ctrl+Super+strzalki skacze po oknach',
          flush=True)

    threading.Thread(target=reader, args=(keyboards, on_key), daemon=True).start()
    threading.Thread(target=reader, args=(pointers, on_pointer), daemon=True).start()

    global acc_x, acc_y
    dragging = False
    base = []          # snapshot [(addr, x, y)] z chwili rozpoczecia przeciagania
    tot_x = tot_y = 0.0

    while True:
        time.sleep(0.016)  # ~60 FPS
        with lock:
            active = mods['super'] and mods['alt'] and mods['btn']
            dx, dy = acc_x, acc_y
            acc_x = acc_y = 0.0

        if not active:
            dragging, base, tot_x, tot_y = False, [], 0.0, 0.0
            continue

        if not dragging:
            _, wins = floating_on_active()
            if not wins:
                continue
            base = [(w['address'], w['at'][0], w['at'][1]) for w in wins]
            dragging, tot_x, tot_y = True, 0.0, 0.0

        tot_x += dx
        tot_y += dy
        if int(round(tot_x)) == 0 and int(round(tot_y)) == 0:
            continue
        move_windows([(a, x + tot_x, y + tot_y) for a, x, y in base])


if __name__ == '__main__':
    main()
