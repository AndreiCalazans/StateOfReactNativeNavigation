#!/usr/bin/env bash
#
# Fast, instrumentation-free cold-start sampler: for N runs, clear app data,
# cold-launch, read the OS "Displayed" time and the TOTAL PSS from
# `dumpsys meminfo`. Prints per-run values + medians as JSON. No Perfetto,
# no Hermes profiler needed -> works on any release APK and is fair to compare
# across instrumented and vanilla builds.
#
# Usage: quick-coldstart.sh --app <pkg> [--runs N] [--settle S] [--label L]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

APP="" RUNS=3 SETTLE=4 LABEL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --app) APP="${2:?}"; shift 2;;
    --runs) RUNS="${2:?}"; shift 2;;
    --settle) SETTLE="${2:?}"; shift 2;;
    --label) LABEL="${2:?}"; shift 2;;
    *) fail "unknown arg: $1";;
  esac
done
[ -n "$APP" ] || fail "--app required"
ensure_device
LABEL="${LABEL:-$APP}"

# Warmup launch (untimed): the first cold start after install/clear pays ART
# verification + dexopt and is an outlier we don't want in the median.
"${ADB[@]}" shell pm clear "$APP" >/dev/null 2>&1 || true
"${ADB[@]}" shell monkey -p "$APP" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
sleep "$SETTLE"
"${ADB[@]}" shell am force-stop "$APP" >/dev/null 2>&1 || true

disp=(); pss=()
for i in $(seq 1 "$RUNS"); do
  "${ADB[@]}" shell pm clear "$APP" >/dev/null
  "${ADB[@]}" logcat -c >/dev/null 2>&1 || true
  "${ADB[@]}" shell monkey -p "$APP" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
  sleep "$SETTLE"
  d="$("${ADB[@]}" logcat -d -s ActivityTaskManager:I 2>/dev/null \
      | grep -E "Displayed ${APP}/" | tail -1 | tr -d '\r' | parse_displayed_ms || true)"
  # TOTAL PSS (kB) -> MB
  p="$("${ADB[@]}" shell dumpsys meminfo "$APP" 2>/dev/null \
      | awk '/TOTAL PSS:/ {print $3; exit} /^ *TOTAL +[0-9]/ {print $2; exit}' | tr -d '\r')"
  [ -n "$d" ] && disp+=("$d")
  [ -n "$p" ] && pss+=("$p")
  printf '  run %d: Displayed=%sms PSS=%sMB\n' "$i" "${d:-?}" "$( [ -n "$p" ] && echo "scale=1;$p/1024" | bc || echo '?')" >&2
done

median() { printf '%s\n' "$@" | sort -n | awk '{a[NR]=$1} END{print (NR%2)?a[(NR+1)/2]:(a[NR/2]+a[NR/2+1])/2}'; }
md=$( [ ${#disp[@]} -gt 0 ] && median "${disp[@]}" || echo null )
mp=$( [ ${#pss[@]} -gt 0 ] && median "${pss[@]}" || echo null )
mp_mb=$( [ "$mp" != null ] && echo "scale=1;$mp/1024" | bc || echo null )

cat <<JSON
{"label":"$LABEL","app":"$APP","runs":$RUNS,"medianDisplayedMs":$md,"medianPssMb":$mp_mb,"displayedMs":[$(IFS=,;echo "${disp[*]:-}")],"pssKb":[$(IFS=,;echo "${pss[*]:-}")]}
JSON
