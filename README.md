This is a experimental repo to test the difference between navigation solutions
for React Native in June 2026.

For this research I want to compare the following:

1. Expo Router (Expo SDK 56)
2. React Navigation (v7)
3. react-native-navigation
   (https://wix.github.io/react-native-navigation/docs/installing) 
4. "navigation" AKA navigation router by Graham
   (https://github.com/grahammendick/navigation)

We will compare functionality plus performance.

For performance we will focus solely on Android since it has the most available
data plus it's where the performance bottleneck usually is. To do that we will:

- Pull data with Flashlight (https://github.com/bamlab/flashlight)
- Run Perfetto Systrace
- Run Hermes CPU release profiler (https://github.com/margelo/react-native-release-profiler)

Example on how I have used Flashlight with Maestro before (https://github.com/cortinico/repro-36296)

---

## Repository layout

```
apps/
  expo-router-app/        Expo Router (Expo SDK 56)            -> com.rnperf.exporouter
  react-navigation-app/   React Navigation v7                 -> com.rnperf.reactnavigation
  navigation-app/         navigation router (Graham Mendick)  -> com.rnperf.navigation
  rnn_app/                react-native-navigation (Wix, bare) -> com.rnperf.rnn
shared-ui/                Navigation-agnostic screens shared by every app
experiments/              Controlled experiments (bare_min, expo_min) for the Expo-cost study
perf-tooling/             Shareable Android perf tooling (see perf-tooling/README.md)
scripts/                  setup-tools.sh, env.sh, measure.sh, compare.py
perf-results/             Captured results: comparison.md + committed raw data
                          (Perfetto traces, Hermes profiles) for validation
docs/                     Write-ups (open in a browser):
                            cold-start-findings.html  cold start + RAM deep dive
                            expo-cost.html            the cost of Expo / expo-modules-core
```

Every app renders the **same** screens (from `shared-ui`) and exposes the same
testIDs, so the comparison isolates the navigation library itself. The shared
interaction surface: cold start, repeated stack push/pop, and a tab switch.

## One-time setup

```bash
scripts/setup-tools.sh      # installs Maestro + Flashlight into .tools/ (no globals)
source scripts/env.sh       # PATH + JAVA_HOME + ANDROID_HOME for the repo toolchain
```

## Build an example (release == profiling build)

Expo apps use Continuous Native Generation, so `android/` is generated:

```bash
cd apps/expo-router-app
yarn install
npx expo prebuild --platform android       # applies the rn-perf-tooling config plugin
cd android && ./gradlew :app:installRelease
```

The bare RNN app already contains `android/`:

```bash
cd apps/rnn_app && yarn install
cd android && ./gradlew :app:installRelease
```

## Measure performance

```bash
# Full suite (cold start CPU + Systrace, then Flashlight) for one app:
scripts/measure.sh --app com.rnperf.exporouter --app-dir apps/expo-router-app \
  --label expo-router --runs 5 --iterations 3

# Aggregate every app's results into perf-results/comparison.md:
scripts/compare.py
```

See `perf-tooling/README.md` for the individual scripts and the methodology.
Perfetto traces open at https://ui.perfetto.dev; Hermes profiles open in Chrome
DevTools or Perfetto. Latest aggregated numbers: `perf-results/comparison.md`.
