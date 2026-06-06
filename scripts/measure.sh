#!/usr/bin/env bash
# =============================================================================
# measure.sh  — one command to run the full perf suite for an example app.
# -----------------------------------------------------------------------------
# Runs, for a given app:
#   1. coldstart-profile.sh  -> N cold starts (Perfetto systrace + Hermes CPU
#                               profile + OS Displayed metric)
#   2. flashlight-measure.sh -> FPS/CPU/RAM over the shared navigate flow
#
# Assumes the release APK is already built+installed unless --build is passed.
#
# Usage:
#   scripts/measure.sh --app <pkg> --app-dir <dir> --label <name> \
#       [--runs N] [--iterations N] [--build] [--cold-only] [--flash-only]
# =============================================================================
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=env.sh
source "$REPO_ROOT/scripts/env.sh" >/dev/null

APP="" APP_DIR="" LABEL=""
RUNS=5 ITER=3 BUILD="" COLD=1 FLASH=1
OUT_BASE="$REPO_ROOT/perf-results"

while [ $# -gt 0 ]; do
  case "$1" in
    --app)        APP="${2:?}"; shift 2 ;;
    --app-dir)    APP_DIR="${2:?}"; shift 2 ;;
    --label)      LABEL="${2:?}"; shift 2 ;;
    --runs)       RUNS="${2:?}"; shift 2 ;;
    --iterations) ITER="${2:?}"; shift 2 ;;
    --build)      BUILD="--build"; shift ;;
    --cold-only)  FLASH=0; shift ;;
    --flash-only) COLD=0; shift ;;
    --out)        OUT_BASE="${2:?}"; shift 2 ;;
    -h|--help)    sed -n '2,20p' "$0"; exit 0 ;;
    *)            echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

[ -n "$APP" ] && [ -n "$APP_DIR" ] && [ -n "$LABEL" ] \
  || { echo "ERROR: --app, --app-dir and --label are required" >&2; exit 1; }

# Resolve app dir relative to repo root if not absolute.
case "$APP_DIR" in /*) : ;; *) APP_DIR="$REPO_ROOT/$APP_DIR" ;; esac
OUT="$OUT_BASE/$LABEL"
mkdir -p "$OUT"

echo "=== measure: $LABEL ($APP) ==="

if [ "$COLD" -eq 1 ]; then
  echo "--- cold-start CPU + Systrace ($RUNS runs) ---"
  "$REPO_ROOT/perf-tooling/scripts/coldstart-profile.sh" \
    --app "$APP" --app-dir "$APP_DIR" --label "$LABEL" \
    --runs "$RUNS" --out "$OUT" $BUILD
fi

if [ "$FLASH" -eq 1 ]; then
  echo "--- Flashlight FPS/CPU/RAM ($ITER iterations) ---"
  "$REPO_ROOT/perf-tooling/scripts/flashlight-measure.sh" \
    --app "$APP" --flow "$REPO_ROOT/perf-tooling/maestro/navigate.yaml" \
    --label "$LABEL" --out "$OUT" --iterations "$ITER"
fi

echo "=== done: results in $OUT ==="
