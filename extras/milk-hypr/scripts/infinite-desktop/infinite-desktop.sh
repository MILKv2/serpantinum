#!/usr/bin/env bash
# Wrapper. Wykrywanie urzadzen przenieslo sie do core (po capabilities, nie po
# nazwie) - tutaj zostaje tylko predkosc przeciagania.
SPEED="${1:-1.6}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/infinite_desktop_core.py" "$SPEED"
