# rn-perf-tooling

Shareable Android performance tooling used by every navigation example in this
repo. It is intentionally framework-agnostic: any RN/Expo app can consume it.

## What it provides

1. **Expo config plugin** (`rn-perf-tooling/app.plugin.js`) that makes a release
   build profileable for cold-start research:
   - adds `<profileable android:shell="true"/>` to the manifest,
   - sets `buildConfigField ENABLE_COLD_START_SAMPLING=true` on the `release`
     build type,
   - installs a `ReactMarker -> Systrace` forwarder and enables the Hermes
     sampling profiler in `MainApplication.onCreate` (gated by the flag),
   - drops a neutral `com.rnperf.systrace.ReactMarkerSystraceForwarder` into the
     android source tree.

2. **JS helper** (`rn-perf-tooling/js/coldStartProfiling`) — call
   `scheduleColdStartDump()` once at the top of your JS entry. In a release
   bundle it stops + dumps the Hermes sampling profile to `/sdcard/Download`
   after a capture window, where the scripts pull it from.

3. **Capture scripts** (`scripts/`):
   - `perfetto-trace.sh` — one Perfetto system trace (optionally cold-launch).
   - `coldstart-profile.sh` — N cold starts; pulls Perfetto + Hermes cpuprofile
     per run, source-maps the cpuprofile, aggregates the OS `Displayed` metric.
   - `flashlight-measure.sh` — FPS/CPU/RAM via Flashlight + a Maestro flow.
   - `perfetto-coldstart.cfg.txtproto` — the shared Perfetto config (the app
     process for native callstack sampling is templated with `__TARGET_CMDLINE__`).

4. **Maestro flow templates** (`maestro/`) parameterized by `${APP_ID}`:
   - `cold-start.yaml` — launch (clear state) and land on Home.
   - `navigate.yaml` — repeated stack push/pop + tab switch (the shared perf
     interaction surface; every example exposes the same testIDs).

## Shared testIDs (every example must expose these)

| testID          | meaning                                   |
|-----------------|-------------------------------------------|
| `home-screen`   | root of the Home screen                   |
| `home-row-<n>`  | list row n on Home                        |
| `open-details`  | button that pushes the Details screen     |
| `details-screen`| root of the Details screen                |
| `details-back`  | button that pops back to Home             |
| `tab-home`      | Home tab button                           |
| `tab-profile`   | Profile tab button                        |
| `profile-screen`| root of the Profile screen                |

## Usage from an app

In `app.json` plugins: `"rn-perf-tooling"`.

In the JS entry:

```ts
import { scheduleColdStartDump } from 'rn-perf-tooling/js/coldStartProfiling';
scheduleColdStartDump();
```

Then, from the repo root (see top-level README for the wrapper scripts):

```bash
# Cold-start CPU + Systrace, 5 runs:
perf-tooling/scripts/coldstart-profile.sh \
  --app com.rnperf.exporouter --app-dir apps/expo-router-app \
  --label expo-router --runs 5 --build

# A single ad-hoc system trace of a cold launch:
perf-tooling/scripts/perfetto-trace.sh \
  --app com.rnperf.exporouter --label expo-router --cold-launch

# Flashlight FPS/CPU/RAM over the navigation flow:
perf-tooling/scripts/flashlight-measure.sh \
  --app com.rnperf.exporouter --flow perf-tooling/maestro/navigate.yaml \
  --label expo-router
```

## Requirements

- `adb` (Android platform-tools), `python3`, `node`.
- The app must depend on `react-native-release-profiler` and apply the config
  plugin, and must be built as a **release** APK (profiling == release here).
- For Flashlight: `flashlight` + `maestro` on PATH (the top-level
  `scripts/setup-tools.sh` installs them into `.tools/`).
- Device must be profileable (the plugin handles this) and reachable via adb.
