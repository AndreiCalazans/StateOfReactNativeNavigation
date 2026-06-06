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
