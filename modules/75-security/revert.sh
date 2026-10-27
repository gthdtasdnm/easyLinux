#!/usr/bin/env bash
# Vom Virenschutz geladene Signaturen entfernen – aber nur, wenn easyLinux ClamAV installiert hat.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/../../lib/common.sh"
if root grep -qx clamav "$EASYLINUX_SYS/packages.txt" 2>/dev/null; then
    root find /var/lib/clamav -mindepth 1 -delete 2>/dev/null
fi
true
