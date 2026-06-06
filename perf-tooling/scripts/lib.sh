#!/usr/bin/env bash
# Shared helpers for the rn-perf-tooling capture scripts.

log()  { printf '[perf] %s\n' "$*"; }
warn() { printf '[perf] WARNING: %s\n' "$*" >&2; }
fail() { printf '[perf] ERROR: %s\n' "$*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command '$1' not in PATH${2:+ ($2)}"
}

# Echo the first connected adb device serial (empty if none).
first_device() {
  adb devices 2>/dev/null | awk 'NR>1 && $2=="device" {print $1; exit}'
}

# Ensure exactly one usable device; export ADB="adb -s <serial>".
ensure_device() {
  require_cmd adb "install Android platform-tools"
  local serial
  serial="$(first_device)"
  [ -n "$serial" ] || fail "no Android device connected (check 'adb devices')"
  DEVICE_SERIAL="$serial"
  ADB=(adb -s "$DEVICE_SERIAL")
  log "using device: $DEVICE_SERIAL"
}

# Parse an "ActivityTaskManager: Displayed <pkg>/... +1s951ms" line to ms.
parse_displayed_ms() {
  python3 -c "
import sys, re
m = re.search(r'\+(?:(\d+)s)?(\d+)ms', sys.stdin.read())
if m:
    print((int(m.group(1) or 0)) * 1000 + int(m.group(2)))
"
}
