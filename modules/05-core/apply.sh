#!/usr/bin/env bash
# Gemeinsame Grundlage: benötigte Pakete und die easyLinux-Programme unter /opt/easylinux.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$here/../.."
. "$repo/lib/common.sh"

pkg_need pyside6 kdialog pacman-contrib
root rm -rf "$EASYLINUX_OPT"
root mkdir -p "$EASYLINUX_OPT"
root cp -r "$repo/apps" "$repo/bin" "$repo/data" "$EASYLINUX_OPT/"
root chmod -R a+rX "$EASYLINUX_OPT"
root chmod a+x "$EASYLINUX_OPT"/bin/*
ok "easyLinux-Programme bereitgestellt"
