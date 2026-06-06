# Raw performance data

All raw artifacts behind `docs/cold-start-findings.html` are committed here so
anyone can independently validate the analysis. Device: Samsung Galaxy A16
(SM-A165M), Android 14; Hermes; New Architecture (bridgeless + Fabric);
Expo SDK 56 / RN 0.85; profileable release builds.

## Layout

```
comparison.md / comparison.json     headline table (scripts/compare.py)
analysis-breakdown.json             per-app deep-dive numbers used by the blog post
<app>/
  <app>-summary.json                cold-start OS "Displayed" metric, 3 runs
  <app>-run{1,2,3}-hermes.json      source-mapped Hermes CPU profiles (Chrome trace)
  <app>-run{1,2,3}-raw.cpuprofile.txt  raw Hermes sampling profiles (pre source-map)
  <app>.json                        Flashlight measures (FPS/CPU/RAM)
_native/
  <app>-native-*.perfetto-trace     full cold-launch system traces (~12 MB each)
```

## Reproduce / validate

```bash
# Open a Perfetto trace:
#   https://ui.perfetto.dev  -> open _native/<app>-native-*.perfetto-trace
# Open a Hermes profile:
#   Chrome DevTools (Performance > load profile) or ui.perfetto.dev

# Re-derive the blog numbers:
PERFETTO_TP=$(echo ~/.local/share/perfetto/prebuilts/trace_processor_shell-*) \
perf-tooling/scripts/analyze-perfetto-coldstart.py \
  --trace perf-results/_native/expo-router-native-*.perfetto-trace \
  --app com.rnperf.exporouter

perf-tooling/scripts/analyze-hermes-profile.py expo-router \
  perf-results/expo-router/expo-router-run*-hermes.json

# Regenerate the headline table:
scripts/compare.py
```

## Notes

- The Hermes `*.json` profiles embed source-mapped paths from the machine they
  were converted on; only the leaf file/`node_module` names matter for analysis.
- The per-run cold-start Perfetto traces from the original `measure.sh` batch were
  discarded: the device's `traced_probes` service had stopped after many
  back-to-back sessions, so those traces contained no ftrace/atrace/RSS data. The
  `_native/` traces here were re-captured after restarting the tracing stack
  (`adb shell 'setprop persist.traced.enable 0; sleep 1; setprop persist.traced.enable 1'`)
  and contain the full `RNMarker.*` spans + memory counters used by the post.
```
