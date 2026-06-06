#!/usr/bin/env bash
# =============================================================================
# coldstart-profile.sh
# -----------------------------------------------------------------------------
# Drive N Android cold starts of a profileable release build and collect, per
# run:
#   - a Perfetto system trace (ftrace/atrace/sched + native callstacks + our
#     RNMarker.* slices)
#   - the Hermes sampling cpuprofile dumped by the app to /sdcard/Download
#     (enabled natively in onCreate, stopped+dumped from JS), source-mapped to
#     a Chrome trace via react-native-release-profiler.
#   - the OS "Displayed" cold-start metric from logcat.
#
# Outputs (in --out):
#   <label>-run<i>.perfetto-trace
#   <label>-run<i>-hermes.json            (source-mapped Chrome trace)
#   <label>-summary.json                  (per-run + median Displayed metric)
#
# Usage:
#   coldstart-profile.sh --app <pkg> --app-dir <dir> [--label L] [--runs N]
#       [--out DIR] [--sourcemap <path>] [--build] [--no-clear] [--wait S]
#
# Defaults: --label coldstart --runs 5 --out ./perf-results --wait 12
#
# --build      build + install the release APK first (expo prebuild assumed).
# --no-clear   force-stop instead of pm clear between runs (preserve data).
# =============================================================================
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

APP=""
APP_DIR=""
LABEL="coldstart"
RUNS=5
OUT_DIR="./perf-results"
SOURCEMAP=""
DO_BUILD=0
CLEAR=1
WAIT_S=12
PERFETTO_DURATION_MS=10000

while [ $# -gt 0 ]; do
  case "$1" in
    --app)        APP="${2:?}"; shift 2 ;;
    --app-dir)    APP_DIR="${2:?}"; shift 2 ;;
    --label)      LABEL="${2:?}"; shift 2 ;;
    --runs)       RUNS="${2:?}"; shift 2 ;;
    --out)        OUT_DIR="${2:?}"; shift 2 ;;
    --sourcemap)  SOURCEMAP="${2:?}"; shift 2 ;;
    --build)      DO_BUILD=1; shift ;;
    --no-clear)   CLEAR=0; shift ;;
    --wait)       WAIT_S="${2:?}"; shift 2 ;;
    -h|--help)    sed -n '2,30p' "$0"; exit 0 ;;
    *)            fail "unknown arg: $1" ;;
  esac
done

[ -n "$APP" ]     || fail "--app <pkg> is required"
[ -n "$APP_DIR" ] || fail "--app-dir <dir> is required"
[ -d "$APP_DIR" ] || fail "app dir not found: $APP_DIR"
require_cmd python3
require_cmd node
ensure_device

ANDROID_DIR="$APP_DIR/android"
[ -d "$ANDROID_DIR" ] || fail "no android/ in $APP_DIR (run 'npx expo prebuild')"

mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
CFG_TEMPLATE="$SCRIPT_DIR/perfetto-coldstart.cfg.txtproto"

# Auto-detect the release sourcemap if not given.
if [ -z "$SOURCEMAP" ]; then
  CAND="$ANDROID_DIR/app/build/generated/sourcemaps/react/release/index.android.bundle.map"
  [ -f "$CAND" ] && SOURCEMAP="$CAND"
fi

if [ "$DO_BUILD" -eq 1 ]; then
  log "building + installing release APK ($APP)"
  ( cd "$ANDROID_DIR" && ANDROID_SERIAL="$DEVICE_SERIAL" ./gradlew :app:installRelease ) | tail -5
  CAND="$ANDROID_DIR/app/build/generated/sourcemaps/react/release/index.android.bundle.map"
  [ -f "$CAND" ] && SOURCEMAP="$CAND"
fi

[ -n "$SOURCEMAP" ] && [ -f "$SOURCEMAP" ] \
  && log "sourcemap: $SOURCEMAP" \
  || warn "no release sourcemap found; Hermes profile will be unsymbolicated"

run_one() {
  local idx="$1"
  local trace_dev="/data/misc/perfetto-traces/${LABEL}-run${idx}.perfetto-trace"
  local trace_out="$OUT_DIR/${LABEL}-run${idx}.perfetto-trace"

  if [ "$CLEAR" -eq 1 ]; then
    log "run $idx/$RUNS: pm clear $APP"
    "${ADB[@]}" shell pm clear "$APP" >/dev/null
    "${ADB[@]}" shell pm grant "$APP" android.permission.WRITE_EXTERNAL_STORAGE >/dev/null 2>&1 || true
    "${ADB[@]}" shell pm grant "$APP" android.permission.READ_EXTERNAL_STORAGE  >/dev/null 2>&1 || true
  else
    log "run $idx/$RUNS: force-stop $APP (data preserved)"
    "${ADB[@]}" shell am force-stop "$APP" >/dev/null
  fi

  "${ADB[@]}" shell 'rm -f /sdcard/Download/sampling-profiler-trace*.cpuprofile*' >/dev/null 2>&1 || true
  "${ADB[@]}" shell "rm -f ${trace_dev}" >/dev/null 2>&1 || true
  "${ADB[@]}" logcat -c >/dev/null 2>&1 || true

  # Start perfetto in background before launch so we capture process fork.
  local config
  config="$(sed "s/__TARGET_CMDLINE__/${APP}/g" "$CFG_TEMPLATE")"$'\n'"duration_ms: ${PERFETTO_DURATION_MS}"
  printf '%s' "$config" | "${ADB[@]}" shell "perfetto --txt -c - -o ${trace_dev} --background" >/dev/null
  sleep 1

  "${ADB[@]}" shell monkey -p "$APP" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
  log "run $idx/$RUNS: waiting ${WAIT_S}s for cold start + profile dump"
  sleep "$WAIT_S"

  # OS Displayed metric.
  local disp_line disp_ms=""
  disp_line="$("${ADB[@]}" logcat -d -s ActivityTaskManager:I 2>/dev/null \
    | grep -E "Displayed ${APP}/" | tail -1 | tr -d '\r' || true)"
  [ -n "$disp_line" ] && disp_ms="$(printf '%s' "$disp_line" | parse_displayed_ms)"
  echo "${disp_ms:-}" > "$OUT_DIR/.${LABEL}-run${idx}-displayed.txt"

  # Pull perfetto trace.
  if "${ADB[@]}" pull "${trace_dev}" "${trace_out}" >/dev/null 2>&1; then
    "${ADB[@]}" shell "rm -f ${trace_dev}" >/dev/null 2>&1 || true
    log "  perfetto -> $trace_out"
  else
    warn "run $idx: failed to pull perfetto trace"
  fi

  # Pull + convert Hermes cpuprofile (dumped to /sdcard/Download by the app).
  local prof
  prof="$("${ADB[@]}" shell ls /sdcard/Download/ 2>/dev/null \
    | grep -E 'sampling-profiler-trace.*\.cpuprofile' | head -1 | tr -d '\r' || true)"
  if [ -z "$prof" ]; then
    warn "run $idx: no Hermes cpuprofile in /sdcard/Download (is this a profiling release build?)"
    return 0
  fi

  # Pull the raw cpuprofile off the device, then convert it locally with our
  # standalone converter (avoids the release-profiler CLI's hard dependency
  # on @react-native-community/cli-tools, which Expo apps don't ship).
  local raw_out="$OUT_DIR/${LABEL}-run${idx}-raw.cpuprofile.txt"
  "${ADB[@]}" shell "cat /sdcard/Download/${prof}" > "$raw_out" 2>/dev/null || true
  if [ ! -s "$raw_out" ]; then
    warn "run $idx: failed to pull cpuprofile $prof"
    return 0
  fi

  local sm_args=()
  [ -n "$SOURCEMAP" ] && [ -f "$SOURCEMAP" ] && sm_args=(--sourcemap "$SOURCEMAP")
  if node "$SCRIPT_DIR/convert-hermes-profile.js" \
        --in "$raw_out" --out "$OUT_DIR/${LABEL}-run${idx}-hermes.json" \
        --app-dir "$APP_DIR" "${sm_args[@]}" \
        >"$OUT_DIR/.${LABEL}-run${idx}-convert.log" 2>&1; then
    log "  hermes  -> $OUT_DIR/${LABEL}-run${idx}-hermes.json"
  else
    warn "run $idx: cpuprofile conversion failed (see $OUT_DIR/.${LABEL}-run${idx}-convert.log)"
  fi

  local disp_str="${disp_ms:-n/a}"
  [ -n "$disp_ms" ] && disp_str="${disp_ms}ms"
  log "  run $idx: Displayed=$disp_str"
}

log "capturing $RUNS cold-start runs (app=$APP)"
for i in $(seq 1 "$RUNS"); do run_one "$i"; done

# Aggregate Displayed metric into a summary JSON.
SUMMARY="$OUT_DIR/${LABEL}-summary.json"
python3 - "$OUT_DIR" "$LABEL" "$RUNS" "$APP" "$SUMMARY" <<'PY'
import json, sys, os, statistics
out_dir, label, runs, app, summary = sys.argv[1:6]
runs = int(runs)
per_run = []
for i in range(1, runs + 1):
    p = os.path.join(out_dir, f".{label}-run{i}-displayed.txt")
    val = None
    if os.path.exists(p):
        raw = open(p).read().strip()
        val = int(raw) if raw else None
    per_run.append({"run": i, "displayedMs": val})
clean = [r["displayedMs"] for r in per_run if r["displayedMs"] is not None]
data = {
    "app": app,
    "label": label,
    "runs": runs,
    "displayedMs": per_run,
    "medianDisplayedMs": statistics.median(clean) if clean else None,
    "minDisplayedMs": min(clean) if clean else None,
    "maxDisplayedMs": max(clean) if clean else None,
}
with open(summary, "w") as f:
    json.dump(data, f, indent=2)
print(json.dumps(data, indent=2))
PY

log "summary -> $SUMMARY"
log "open any .perfetto-trace at https://ui.perfetto.dev"
