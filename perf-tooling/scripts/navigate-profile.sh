#!/usr/bin/env bash
# Capture a Perfetto system trace + Hermes CPU profile of a Home -> Details
# navigation. Cold-launches the app (so the onCreate Hermes sampler is running),
# waits for Home to settle, taps the shared "open-details" button, and keeps the
# trace open through the screen transition. The Hermes cold-start dump (~9 s)
# therefore also covers the navigation burst.
#
# Usage:
#   navigate-profile.sh --app <pkg> --app-dir <dir> --label <name> [--out DIR]
#       [--tap-delay-s S] [--duration-ms N] [--sourcemap PATH]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

APP="" APP_DIR="" LABEL="" OUT="./perf-results" TAP_DELAY=3.5 DUR=9000 SOURCEMAP=""
while [ $# -gt 0 ]; do
  case "$1" in
    --app) APP="${2:?}"; shift 2;;
    --app-dir) APP_DIR="${2:?}"; shift 2;;
    --label) LABEL="${2:?}"; shift 2;;
    --out) OUT="${2:?}"; shift 2;;
    --tap-delay-s) TAP_DELAY="${2:?}"; shift 2;;
    --duration-ms) DUR="${2:?}"; shift 2;;
    --sourcemap) SOURCEMAP="${2:?}"; shift 2;;
    *) fail "unknown arg: $1";;
  esac
done
[ -n "$APP" ] && [ -n "$LABEL" ] || fail "--app and --label required"
ensure_device
mkdir -p "$OUT"; OUT="$(cd "$OUT" && pwd)"
LABEL_OUT="$OUT/${LABEL}-nav"
DEVF="/data/misc/perfetto-traces/${LABEL}-nav.perfetto-trace"
CFG="$SCRIPT_DIR/perfetto-coldstart.cfg.txtproto"

if [ -z "$SOURCEMAP" ] && [ -n "$APP_DIR" ]; then
  c="$APP_DIR/android/app/build/generated/sourcemaps/react/release/index.android.bundle.map"
  [ -f "$c" ] && SOURCEMAP="$c"
fi

log "navigate capture: app=$APP tap-delay=${TAP_DELAY}s dur=${DUR}ms"
"${ADB[@]}" shell pm clear "$APP" >/dev/null
"${ADB[@]}" shell pm grant "$APP" android.permission.WRITE_EXTERNAL_STORAGE >/dev/null 2>&1 || true
"${ADB[@]}" shell 'rm -f /sdcard/Download/sampling-profiler-trace*' >/dev/null 2>&1 || true
"${ADB[@]}" shell "rm -f ${DEVF}" >/dev/null 2>&1 || true
"${ADB[@]}" logcat -c >/dev/null 2>&1 || true

config="$(sed "s/__TARGET_CMDLINE__/${APP}/g" "$CFG")"$'\n'"duration_ms: ${DUR}"
printf '%s' "$config" | "${ADB[@]}" shell "perfetto --txt -c - -o ${DEVF} --background" >/dev/null
sleep 1
"${ADB[@]}" shell monkey -p "$APP" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1

sleep "$TAP_DELAY"
# Resolve the shared open-details button center (same layout in every app).
"${ADB[@]}" shell uiautomator dump /sdcard/ud.xml >/dev/null 2>&1 || true
bounds="$("${ADB[@]}" shell cat /sdcard/ud.xml 2>/dev/null | tr '>' '\n' \
  | grep -i 'open-details' | grep -oE 'bounds="[^"]*"' | head -1 | grep -oE '[0-9]+' || true)"
set -- $bounds
if [ $# -eq 4 ]; then
  cx=$(( ($1 + $3) / 2 )); cy=$(( ($2 + $4) / 2 ))
else
  warn "could not read open-details bounds; falling back to (540,427)"; cx=540; cy=427
fi
log "tapping open-details at ($cx,$cy)"
"${ADB[@]}" shell input tap "$cx" "$cy"

# Wait for the trace to finish + the Hermes dump (~9 s after JS entry).
WAIT=$(( (DUR/1000) + 4 ))
log "waiting ${WAIT}s for trace + Hermes dump"
sleep "$WAIT"

"${ADB[@]}" pull "${DEVF}" "${LABEL_OUT}.perfetto-trace" >/dev/null && log "perfetto -> ${LABEL_OUT}.perfetto-trace"
"${ADB[@]}" shell "rm -f ${DEVF}" >/dev/null 2>&1 || true

prof="$("${ADB[@]}" shell ls /sdcard/Download/ 2>/dev/null | grep -E 'sampling-profiler-trace.*\.cpuprofile' | head -1 | tr -d '\r' || true)"
if [ -n "$prof" ]; then
  raw="${LABEL_OUT}-raw.cpuprofile.txt"
  "${ADB[@]}" shell "cat /sdcard/Download/${prof}" > "$raw" 2>/dev/null || true
  sm=(); [ -n "$SOURCEMAP" ] && [ -f "$SOURCEMAP" ] && sm=(--sourcemap "$SOURCEMAP")
  if node "$SCRIPT_DIR/convert-hermes-profile.js" --in "$raw" --out "${LABEL_OUT}-hermes.json" \
       --app-dir "${APP_DIR:-.}" "${sm[@]}" >/dev/null 2>&1; then
    log "hermes -> ${LABEL_OUT}-hermes.json"
  else
    warn "hermes conversion failed"
  fi
else
  warn "no Hermes cpuprofile produced"
fi
log "done: $LABEL"
