#!/usr/bin/env bash
#
# Capture a Perfetto system trace from a connected Android device.
#
# Usage:
#   perfetto-trace.sh --app <pkg> [--label <name>] [--duration-ms <n>]
#                     [--out <dir>] [--cold-launch] [--no-clear]
#
# Defaults: --label trace  --duration-ms 10000  --out ./perf-results
#
# --cold-launch   force-stop + clear app data, start perfetto in background,
#                 then launch <pkg> via monkey so the trace captures a true
#                 cold start (process fork -> first frame).
# --no-clear      with --cold-launch, force-stop only (preserve app data).
#
# Output: <out>/<label>-<ts>.perfetto-trace  (open at https://ui.perfetto.dev)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

APP=""
LABEL="trace"
DURATION_MS=10000
OUT_DIR="./perf-results"
COLD_LAUNCH=0
CLEAR=1

while [ $# -gt 0 ]; do
  case "$1" in
    --app)         APP="${2:?}"; shift 2 ;;
    --label)       LABEL="${2:?}"; shift 2 ;;
    --duration-ms) DURATION_MS="${2:?}"; shift 2 ;;
    --out)         OUT_DIR="${2:?}"; shift 2 ;;
    --cold-launch) COLD_LAUNCH=1; shift ;;
    --no-clear)    CLEAR=0; shift ;;
    -h|--help)     sed -n '2,20p' "$0"; exit 0 ;;
    *)             fail "unknown arg: $1" ;;
  esac
done

[ -n "$APP" ] || fail "--app <pkg> is required"
ensure_device

mkdir -p "$OUT_DIR"
TS="$(date +%Y%m%d-%H%M%S)"
OUT_FILE="${OUT_DIR}/${LABEL}-${TS}.perfetto-trace"
DEVICE_FILE="/data/misc/perfetto-traces/${LABEL}-${TS}.perfetto-trace"

CFG_TEMPLATE="$SCRIPT_DIR/perfetto-coldstart.cfg.txtproto"
[ -f "$CFG_TEMPLATE" ] || fail "perfetto config missing: $CFG_TEMPLATE"
# Template the per-app native-sampling scope + the trace duration.
CONFIG="$(sed "s/__TARGET_CMDLINE__/${APP}/g" "$CFG_TEMPLATE")"$'\n'"duration_ms: ${DURATION_MS}"

log "perfetto label=$LABEL app=$APP duration_ms=$DURATION_MS cold_launch=$COLD_LAUNCH"

"${ADB[@]}" shell "rm -f ${DEVICE_FILE}" >/dev/null 2>&1 || true

if [ "$COLD_LAUNCH" -eq 1 ]; then
  "${ADB[@]}" shell am force-stop "$APP" >/dev/null 2>&1 || true
  if [ "$CLEAR" -eq 1 ]; then
    log "clearing app data for $APP"
    "${ADB[@]}" shell pm clear "$APP" >/dev/null
    "${ADB[@]}" shell pm grant "$APP" android.permission.WRITE_EXTERNAL_STORAGE >/dev/null 2>&1 || true
    "${ADB[@]}" shell pm grant "$APP" android.permission.READ_EXTERNAL_STORAGE  >/dev/null 2>&1 || true
  fi
  "${ADB[@]}" logcat -c >/dev/null 2>&1 || true
  log "starting perfetto in background (~$((DURATION_MS / 1000))s)"
  printf '%s' "$CONFIG" | "${ADB[@]}" shell "perfetto --txt -c - -o ${DEVICE_FILE} --background" >/dev/null
  sleep 1
  log "launching $APP via monkey"
  "${ADB[@]}" shell monkey -p "$APP" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
  sleep "$(( (DURATION_MS / 1000) + 2 ))"
else
  log "starting perfetto (~$((DURATION_MS / 1000))s) over current foreground"
  printf '%s' "$CONFIG" | "${ADB[@]}" shell "perfetto --txt -c - -o ${DEVICE_FILE}"
fi

log "pulling trace -> $OUT_FILE"
"${ADB[@]}" pull "${DEVICE_FILE}" "${OUT_FILE}" >/dev/null
"${ADB[@]}" shell "rm -f ${DEVICE_FILE}" >/dev/null 2>&1 || true

# Report the OS Displayed metric if we cold-launched.
if [ "$COLD_LAUNCH" -eq 1 ]; then
  DISP="$("${ADB[@]}" logcat -d -s ActivityTaskManager:I 2>/dev/null \
    | grep -E "Displayed ${APP}/" | tail -1 | tr -d '\r' || true)"
  if [ -n "$DISP" ]; then
    MS="$(printf '%s' "$DISP" | parse_displayed_ms)"
    log "system Displayed: ${MS}ms"
  fi
fi

log "done: $OUT_FILE"
log "open at https://ui.perfetto.dev"
