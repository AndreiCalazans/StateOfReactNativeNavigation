#!/usr/bin/env bash
#
# Measure FPS / CPU / RAM with Flashlight while a Maestro flow drives the app.
#
# Usage:
#   flashlight-measure.sh --app <pkg> --flow <maestro.yaml>
#       [--label L] [--out DIR] [--iterations N] [--maestro <bin>] [--flashlight <bin>]
#
# Defaults: --label flashlight --out ./perf-results --iterations 3
#
# Produces <out>/<label>.json (Flashlight measures file; open report with
# `flashlight report <file>`).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

APP=""
FLOW=""
LABEL="flashlight"
OUT_DIR="./perf-results"
ITER=3
MAESTRO_BIN="maestro"
FLASHLIGHT_BIN="flashlight"

while [ $# -gt 0 ]; do
  case "$1" in
    --app)        APP="${2:?}"; shift 2 ;;
    --flow)       FLOW="${2:?}"; shift 2 ;;
    --label)      LABEL="${2:?}"; shift 2 ;;
    --out)        OUT_DIR="${2:?}"; shift 2 ;;
    --iterations) ITER="${2:?}"; shift 2 ;;
    --maestro)    MAESTRO_BIN="${2:?}"; shift 2 ;;
    --flashlight) FLASHLIGHT_BIN="${2:?}"; shift 2 ;;
    -h|--help)    sed -n '2,16p' "$0"; exit 0 ;;
    *)            fail "unknown arg: $1" ;;
  esac
done

[ -n "$APP" ]  || fail "--app <pkg> is required"
[ -n "$FLOW" ] || fail "--flow <maestro.yaml> is required"
[ -f "$FLOW" ] || fail "flow not found: $FLOW"
command -v "$MAESTRO_BIN"    >/dev/null 2>&1 || fail "maestro not found ($MAESTRO_BIN)"
command -v "$FLASHLIGHT_BIN" >/dev/null 2>&1 || fail "flashlight not found ($FLASHLIGHT_BIN)"
ensure_device

mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
RESULTS="$OUT_DIR/${LABEL}.json"

log "flashlight measure app=$APP flow=$FLOW iterations=$ITER"
"$FLASHLIGHT_BIN" test \
  --bundleId "$APP" \
  --testCommand "$MAESTRO_BIN --env APP_ID=$APP test $FLOW" \
  --duration 0 \
  --iterationCount "$ITER" \
  --resultsTitle "$LABEL" \
  --resultsFilePath "$RESULTS"

log "results -> $RESULTS"
log "view with: $FLASHLIGHT_BIN report $RESULTS"
