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
- Leak any "Coinbase"/internal brand terms into this repo. Use neutral names
  (package `com.rnperf.systrace`, flag `ENABLE_COLD_START_SAMPLING` is generic).

## Progress

- [x] Read instructions + reference tooling in ~/coinbase/mobile/scripts/perf_testing
- [ ] Goal 1: Setup first example (Expo Router)
- [ ] Goal 2: First example end-to-end on Android (build, Maestro run, pull CPU+Systrace)
- [ ] Goal 3: Automated perf capture tooling
- [ ] Goal 4: Shareable perf tooling library
- [ ] Goal 5: Remaining navigation examples reusing tooling

## Log

- (start) Reviewed reference scripts: perfetto-trace.sh, perfetto-coldstart.cfg.txtproto,
  coldstart-profile.sh, ReleaseProfilerModule.kt, ReactMarkerSystraceForwarder.kt.
  The forwarder is generic; will re-implement under neutral package.
