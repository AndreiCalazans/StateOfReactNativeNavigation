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

## Deep-dive analysis (docs/cold-start-findings.html)

Analyzed Hermes CPU profiles + Perfetto Systrace to explain the differences:
- New analyzers in perf-tooling/scripts: analyze-hermes-profile.py (call-tree
  self-time + library blame + distinct files/modules) and
  analyze-perfetto-coldstart.py (RNMarker spans + RSS split + hades thread count).
- Persisted numbers: perf-results/analysis-breakdown.json. Raw data is committed
  for validation (perf-results/_native/*.perfetto-trace + per-run Hermes profiles);
  re-capture with perfetto-trace.sh --cold-launch into perf-results/_native.
- Gotcha discovered: device's traced_probes service stops after many back-to-back
  perfetto sessions -> sparse traces (no ftrace/atrace/RSS). Fix:
  `adb shell 'setprop persist.traced.enable 0; sleep 1; setprop persist.traced.enable 1'`.

## Controlled experiment: apps/rnn_reanimated_app (RNN + Reanimated/Worklets only)

Added ONLY react-native-reanimated@4.3.1 + react-native-worklets@0.8.3 (+ babel
plugin react-native-worklets/plugin, + a 1px looping animation to exercise the
UI runtime) to the lean RNN app; everything else identical. Result splits the
hypothesis in two:
- RAM: CONFIRMED. peak RAM 195 -> 320MB (Flashlight), RSS 182 -> 318MB, anon heap
  62 -> 185MB (+123MB). Lands at/above expo-router (308MB) on its own. Same JS
  signature as expo-router (react-native-worklets ~146ms, runOnUISync ~104ms).
- Cold start: mostly NOT Reanimated. 316 -> 378ms (+62ms) = only ~10% of
  expo-router's ~600ms gap. RUN_JS_BUNDLE 55 -> 128ms. So expo-router's slow cold
  start is the 2x bundle + 106 modules at boot + router-on-react-navigation, not
  the animation runtime. Corrected the blog accordingly.
- CPU 31 -> 73% over navigate flow is an artifact of the continuous-loop probe
  (worklet runtime busy while animating); not a cost of merely linking Reanimated.
- Also learned the hades-thread count is a NOISY proxy (rnn=2, rnn-reanimated=2,
  expo=3); removed that claim, rely on anon-RSS instead.

## Press anatomy post (docs/press-anatomy.html)

Used existing nav traces (react-navigation-nav.perfetto-trace + hermes.json).
Extracted the full press pipeline with precise timing via trace_processor SQL:
- deliverInputEvent 14ms -> EarlyPostImeInputStage 9.4ms (binder round-trips,
  Samsung OEM tax) -> ViewPostImeInputStage 4.3ms (TouchTargetHelper hit-test)
  -> FabricEventEmitter.receiveEvent('topTouchStart') 1ms -> JS thread wakes up.
- JS: beginEvent/updateCallback (~12ms event routing) + workLoopSync/beginWork
  (reconcile) + completeRoot 16ms (synchronous JSI Fabric commit, the main
  risk) + appendChild calls -> MountItemDispatcher::mountViews on UI thread
  (~33ms after press) -> RenderThread DrawFrames -> eglSwapBuffers = first pixel.
- Hermes profile: top leaves are completeRoot 16.4ms, beginEvent 11.9ms,
  updateCallback 10.9ms, appendChild 10.7ms.
- Post answers: where can I block? (onPress handler, large render subtree,
  heavy Fabric commit via completeRoot, sync native module calls, animation
  contention on JS thread). How to instrument? (tracedPress util with RAF,
  React Profiler, Systrace.beginEvent, Hermes release profiler, Flashlight).

## Cold-start side-by-side videos (docs/cold-*.mp4, in cold-start-findings.html)

Recorded cold start (launcher -> Home) for all 4 apps via adb screenrecord with
retries (screenrecord flakily stops early on native-surface apps rnn/navigation;
retry until >=2.4s). Aligned each on the launcher->app scene-change anchor,
normalized CFR 30, trimmed to a 2.0s launch-aligned window. Composed two pairs
with ~/Movies/side-by-side.sh: cold-rnn-vs-expo-router.mp4 (extremes: rnn on Home
while expo still on splash) and cold-react-navigation-vs-navigation.mp4 (middle).
Embedded after the headline cold-start chart.

## Side-by-side video (docs/rnn-vs-react-navigation-heavy.mp4)

Recorded heavy-screen transitions with `adb screenrecord` and composed via
~/Movies/side-by-side.sh (rnn left, react-navigation right, stopwatch middle).
Embedded in navigation-heavy.html §2. Shows rnn hard-cutting to the rendered
screen (drops transition frames) while react-navigation slides smoothly.
Gotchas: RNN's surface push makes screenrecord stop early (~2.9s) regardless of
--time-limit -> recorded both, normalized to CFR 30fps, trimmed to a tap-aligned
1.47s window ([1.40,2.85], transition ~2.09s). Found tap moment via ffmpeg scene
detection (rnn = 1 abrupt jump; rnav = continuous gradual = smooth slide).
Minor artifact: Hermes-profiler dump Toast on the rnn clip (profiling build).

## Heavy-screen navigation (docs/navigation-heavy.html, perf-results/_nav/*-heavy*)

Added HeavyDetailsScreen (24-row FlatList, initialNumToRender=24, ~12 host
components/row -> ~290 nodes ESTIMATED FROM THE COMPONENT TREE, not the trace;
neither systrace nor sampled Hermes prints a node count) + open-heavy button; wired a heavy route into all 4 apps;
rebuilt + reinstalled all 4; captured nav to heavy (navigate-profile.sh
--button-id open-heavy). Data: perf-results/_nav/nav-heavy-analysis.json.
Trivial -> heavy:
- JS mount jumped for all (completeRoot / Fabric commit of the ~290-node tree ~50-60ms
  dominates): rnn 19.5->86.7, react-navigation 79.8->113.6, navigation
  11.8->123.7 (lean-JS edge GONE), expo-router 47.8->134.2. Router overhead is a
  shrinking slice; content is React/Fabric regardless of router.
- press->first frame splits by architecture: rnn 44->61ms (starts the native
  transition before content is ready -> then a 221ms 'App Deadline Missed' stall
  frame while the tree commits); the content-gated routers scale with mount:
  navigation 243, react-navigation 299, expo-router 322ms.
- press->settled: rnn ~320ms (same wall time but via dropped frames, 4/8 janky);
  content-gated grew ~200ms (526-749ms) but animate smoother (navigation jank
  15/25 trivial -> 3/24 heavy: cost moved out of the animation window).
- Trade-off: rn-navigation = time-to-first-pixel + stutter; React Navigation /
  Expo Router / navigation router = render-before-present (slower start, smooth).
- Propagating shared-ui: file: deps are COPIED at install, so after editing
  shared-ui I copied index.js into each app's node_modules/shared-ui before build.
- navigate-profile.sh now takes --button-id (open-details | open-heavy).

## Navigation cost study (docs/navigation-cost.html, perf-results/_nav/)

Cold-start captures had no taps, so captured fresh per-app traces with
navigate-profile.sh: cold-launch + Hermes sampler running, settle Home, input tap
the shared open-details button, record Perfetto through the transition. Anchors:
press = startDispatchCycleLocked(.../MainActivity) input dispatch; paint = app
actual_frame_timeline frames (first frame = content, last of burst = settled).
New analyzers: analyze-navigate.py (press->paint) + analyze-navigate-hermes.py
(JS mount burst). Data: perf-results/_nav/nav-analysis.json.
Findings:
- press->first frame ~44-62ms for all (all feel instant to start).
- press->fully painted splits: rnn 335 / navigation 330 vs react-navigation 522 /
  expo-router 520. The gap = transition ANIMATION length (a library default).
  expo-router == react-navigation (same native-stack slide, 43 frames).
- JS mount cost mirrors how native each router is: navigation 11.8ms (commits a
  native scene), rnn 19.5ms (render + RNN appear events), expo-router 47.8ms
  (commit + router context propagation), react-navigation 79.8ms (full React
  reconcile + appendChild + synthetic-event pool + nav state).
- Distinct call stacks per lib documented in the HTML. For a trivial screen,
  navigation cost is a native-pipeline cost, not JS.
- Jank (n=1): navigation router janked 15/25 frames on its run; others 8-19%.
- Caveat: n=1 per app, trivial screen, default transition durations.

## Expo cost study (docs/expo-cost.html, experiments/bare_min + expo_min)

Control: 2 bare RN apps (no Expo) vs 3 Expo apps. Built minimal bare-min vs
expo-min (same Home, no nav, vanilla release) measured with quick-coldstart.sh
(Displayed + dumpsys PSS, median of 5 + warmup). Added a per-module sweep.
Findings:
- Every Expo app autolinks the SAME 10 core modules (expo, expo-modules-core,
  expo-asset, expo-constants, expo-file-system, expo-font, expo-keep-awake,
  expo-status-bar, @expo/dom-webview, @expo/log-box). Verified via
  expo-modules-autolinking resolve across all 3 real Expo apps.
- Fixed Expo core tax (bare-min->expo-min): +36ms cold start, +12.6MB PSS,
  +16.2MB APK. Small.
- Per added module (present but UNUSED): light (device/haptics/clipboard) ~0;
  native-view (image/blur/gradient) ~0-2MB; heavy SDK (camera +5.1MB/+25ms,
  video +5.9MB/+16ms, notifications +2.7MB). expo-modules-core inits lazily.
- Reconciliation: instrumented apps showed @expo+expo-modules-core JS-CPU blame
  of 118/185/241ms (react-navigation/navigation/expo-router) but the fixed
  Displayed tax is only ~36ms. That blame = the app's OWN native-module calls
  routed through expo-modules-core (scales with usage), not extra Expo work.
  Softened the cold-start doc's "~115ms Expo tax" wording accordingly.
- Tooling: quick-coldstart.sh (instrumentation-free Displayed+PSS) added;
  lib.sh log()/warn() now go to stderr so JSON stdout stays clean.

Key findings:
1. Expo Router cold start/RAM premium = Reanimated+Worklets second Hermes runtime
   (3 hades GC threads vs 1-2; 8 extra .so; ~106ms JS via runOnUISync/worklets) +
   2x HBC bundle (2.8MB) with 106 files evaluated at boot (vs ~36-43) + it IS
   React Navigation plus a routing layer. RAM premium is mostly anon heap
   (176MB vs 62-94MB).
2. RNN leanest: native nav, RUN_JS_BUNDLE 55ms (JS only registers + setRoot).
   React Navigation adds JS nav tree reconciliation + Expo runtime tax
   (expo-modules-core getConstants ~115ms) + theme color processing -> +50ms JS,
   +110ms RN bringup, +19MB. Caveat: RNN is bare RN (no Expo) so part of its lead
   is "no expo-modules-core".
3. Shared hot functions: getConstants / getConstantsForViewManager (bridge tax),
   completeRoot/createNode/appendChild (Fabric commit), React reconciliation,
   GC. Expo Router adds runOnUISync/registerCustomSerializable (worklets); the
   navigation router has the heaviest getConstants (eager native view-manager
   registration + Material3 constants at import).

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
