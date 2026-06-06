# Project Memory / Progress Log

Living document tracking decisions, direction changes, and progress for the
React Native navigation performance comparison.

## Goal (from README.md)

Compare 4 RN navigation solutions (June 2026) on functionality + Android
performance:

1. Expo Router (Expo SDK 56)
2. React Navigation (v7)
3. react-native-navigation (Wix)
4. `navigation` router by Graham Mendick

Performance captured on Android only via:
- Flashlight (bamlab) driven by Maestro
- Perfetto Systrace
- Hermes CPU release profiler (react-native-release-profiler)

## Environment (verified)

- Device: Samsung SM-A165M (Galaxy A16), Android 14, SDK 34. Always connected.
- Node v24, yarn 1.22, npm 11, bun 1.3.
- Java 17 (mise). ANDROID_HOME set.
- `perfetto` binary present on device (/system/bin/perfetto).
- Maestro + Flashlight NOT yet installed (installing into repo `.tools/`).

## Architecture decisions

- Monorepo layout:
  - `apps/<example>/` — one app per navigation library.
  - `perf-tooling/` — shareable performance tooling (scripts, perfetto config,
    a small native module for ReactMarker->Systrace forwarding, Maestro flow
    templates, analysis helpers).
- Perf approach per app (Android, release/profileable):
  - Build release variant with `<profileable android:shell="true"/>`.
  - Start Hermes sampling profiler as early as possible (react-native-release-profiler
    `startProfiling()` at the very top of the JS entry, gated by an env flag).
  - Install our own `ReactMarkerSystraceForwarder` (neutral package name) from
    Application.onCreate to forward RN markers into atrace/Perfetto.
  - Capture Perfetto systrace with the cold-start config (ported, de-branded).
  - Pull + convert Hermes cpuprofile via react-native-release-profiler CLI.
  - Flashlight measures FPS/CPU/RAM via Maestro flow.

## Do NOT

- Commit INSTRUCTIONS.md (in .gitignore).
- Leak any internal/employer brand terms into this repo. Use neutral names
  (package `com.rnperf.systrace`, flag `ENABLE_COLD_START_SAMPLING` is generic).

## Progress

- [x] Read instructions + external reference tooling (outside this repo)
- [x] Goal 1: Setup first example (Expo Router) — apps/expo-router-app, SDK 56
- [x] Goal 2: First example end-to-end on Android (build, Maestro, CPU, Systrace, Flashlight)
    - [x] Release (profileable) build succeeds
    - [x] Cold start launches; OS Displayed ~0.9-1.0s captured
    - [x] Hermes cpuprofile dumped + source-mapped (expo-router internals visible)
    - [x] Perfetto systrace captured incl. our RNMarker.* slices + native callstacks
    - [x] Maestro flow run (Maestro 2.6 installed into .tools/)
    - [x] Flashlight FPS/CPU/RAM (Flashlight installed into .tools/)
- [x] Goal 3: Automated perf capture tooling (coldstart-profile.sh + flashlight + measure.sh + compare.py)
- [x] Goal 4: Shareable perf tooling library (rn-perf-tooling + shared-ui)
- [x] Goal 5: All 4 navigation examples built, run, and measured on device

## Results (3 cold-start runs + 2 Flashlight iterations, SM-A165M / Android 14)

| Library                 | Cold start median (ms) | Avg FPS | Avg CPU % | Peak RAM (MB) |
|-------------------------|------------------------|---------|-----------|---------------|
| react-native-navigation | 316                    | 59.8    | 31.2      | 195.3         |
| react-navigation v7     | 358                    | 59.9    | 37.8      | 213.6         |
| navigation router       | 398                    | 59.8    | 34.8      | 241.4         |
| expo-router             | 917                    | 59.8    | 37.1      | 307.9         |

See perf-results/comparison.md (regenerate with scripts/compare.py).

Notes / decisions:
- RNN is incompatible with Expo's ExpoReactHostFactory (it owns the React host),
  so rnn_app is a BARE RN 0.85 app. RNN 8.8.7 supports RN 0.85 new arch
  (ReactHost/createSurface). Perf tooling reused manually (no Expo plugin):
  same forwarder .kt, ENABLE_COLD_START_SAMPLING, scripts.
- navigation-react-native needs a Material3 app theme (app-local config plugin).
- Native bottom tab bars (navigation router, RNN) don't expose testIDs to
  Maestro; app-local flows tap tabs by title/point. Stack push/pop uses shared
  testIDs everywhere. measure.sh auto-uses app-local .maestro/navigate.yaml.
- Profiling overhead (Hermes sampling + ReactMarker forwarder) is present in
  every release build, so it is constant across apps and the comparison stays
  fair. Set EXPO_PUBLIC_PROFILING=0 to disable the JS-side dump.

## Log

- Built rn-perf-tooling config plugin; verified it injects profileable, buildConfigField,
  MainApplication.onCreate hooks, and copies the forwarder. Re-implemented the Hermes
  cpuprofile converter standalone (convert-hermes-profile.js) because the
  react-native-release-profiler CLI hard-depends on @react-native-community/cli-tools
  which Expo apps don't ship.
- coldstart-profile.sh validated on device: 2 runs -> perfetto traces, symbolicated
  hermes profiles, Displayed median ~930ms.
- shared-ui package gives every app identical screens (Home/Details/Profile) so the
  comparison isolates the navigation library.
- (start) Reviewed reference scripts: perfetto-trace.sh, perfetto-coldstart.cfg.txtproto,
  coldstart-profile.sh, ReleaseProfilerModule.kt, ReactMarkerSystraceForwarder.kt.
  The forwarder is generic; will re-implement under neutral package.
