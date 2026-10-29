#!/usr/bin/env bash
# Hinweis für Coding-Agenten (Einstellungen › Für Entwickler) beim Deinstallieren wieder entfernen.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
cd "$here/../../apps" 2>/dev/null && python3 -c 'from easylinux import myservices; myservices.set_agent_hint(False)'
rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/easylinux/dienste.json"
true
