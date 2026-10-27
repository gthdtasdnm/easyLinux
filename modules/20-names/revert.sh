#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/../../lib/common.sh"
[ -x "$EASYLINUX_OPT/bin/easylinux-names" ] && root "$EASYLINUX_OPT/bin/easylinux-names" --remove
true
