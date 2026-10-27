#!/usr/bin/env bash
# Andock-Assistent sofort beenden (kwinrc stellt easylinux-user-setup --remove danach wieder her).
set -uo pipefail
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript easylinux-snapassist >/dev/null 2>&1
true
