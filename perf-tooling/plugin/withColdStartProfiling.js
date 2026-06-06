const fs = require('fs');
const path = require('path');
const {
  withAndroidManifest,
  withMainApplication,
  withAppBuildGradle,
  withDangerousMod,
  AndroidConfig,
} = require('@expo/config-plugins');

/**
 * withColdStartProfiling
 * ----------------------
 * Shared Expo config plugin that makes an Android release build "profileable"
 * for cold-start performance research:
 *
 *   1. AndroidManifest:  <profileable android:shell="true" /> so Perfetto +
 *      simpleperf can attach to the release process.
 *   2. app/build.gradle: buildConfigField ENABLE_COLD_START_SAMPLING = true
 *      for the release build type (and enable buildConfig feature).
 *   3. MainApplication.onCreate: gated by BuildConfig.ENABLE_COLD_START_SAMPLING
 *      install the ReactMarker->Systrace forwarder and enable the Hermes
 *      sampling profiler as early as possible (before the JS bundle runs).
 *   4. Copies the neutral ReactMarkerSystraceForwarder.kt into the app's
 *      android source tree (package com.rnperf.systrace).
 *
 * Note: requires `react-native-release-profiler` in the app so the
 * companion JS `stopProfiling()` can dump the sampled trace, and so the
 * Hermes instrumentation classes are present.
 */

const FORWARDER_PACKAGE = 'com.rnperf.systrace';
const FORWARDER_FILE = 'ReactMarkerSystraceForwarder.kt';

const ONCREATE_MARKER = 'loadReactNative(this)';
const COLDSTART_IMPORTS = [
  'import android.util.Log',
  'import com.facebook.hermes.instrumentation.HermesSamplingProfiler',
  'import com.rnperf.systrace.ReactMarkerSystraceForwarder',
];

const COLDSTART_ONCREATE = `
    // @generated begin rn-perf-tooling cold-start profiling (DO NOT MODIFY)
    if (BuildConfig.ENABLE_COLD_START_SAMPLING) {
      try {
        ReactMarkerSystraceForwarder.install()
      } catch (t: Throwable) {
        Log.w("RNPerf", "Failed to install ReactMarker forwarder", t)
      }
      try {
        HermesSamplingProfiler.enable()
        Log.i("RNPerf", "HermesSamplingProfiler enabled in MainApplication.onCreate")
      } catch (t: Throwable) {
        Log.w("RNPerf", "Failed to enable HermesSamplingProfiler in onCreate", t)
      }
    }
    // @generated end rn-perf-tooling cold-start profiling`;

// 1. AndroidManifest: <profileable android:shell="true"/>
function withProfileable(config) {
  return withAndroidManifest(config, (cfg) => {
    const app = AndroidConfig.Manifest.getMainApplicationOrThrow(cfg.modResults);
    app.profileable = app.profileable || [];
    // Replace any existing entry so re-runs stay idempotent.
    app.profileable = [
      {
        $: {
          'android:shell': 'true',
        },
      },
    ];
    return cfg;
  });
}

// 2. app/build.gradle: buildConfigField + buildConfig feature on release.
function withBuildConfigField(config) {
  return withAppBuildGradle(config, (cfg) => {
    let src = cfg.modResults.contents;
    const field =
      'buildConfigField "boolean", "ENABLE_COLD_START_SAMPLING", "true"';

    if (!src.includes('ENABLE_COLD_START_SAMPLING')) {
      // Insert the field into the `release { ... }` build type block.
      src = src.replace(
        /(\n(\s*)release\s*\{)/,
        `$1\n$2    ${field}`
      );
    }

    // Make sure buildConfig generation is on.
    if (!/buildFeatures\s*\{[^}]*buildConfig\s+true/s.test(src)) {
      if (/android\s*\{/.test(src)) {
        src = src.replace(
          /(android\s*\{)/,
          `$1\n    buildFeatures {\n        buildConfig true\n    }`
        );
      }
    }

    cfg.modResults.contents = src;
    return cfg;
  });
}

// 3. MainApplication.onCreate injection.
function withMainApplicationHook(config) {
  return withMainApplication(config, (cfg) => {
    let src = cfg.modResults.contents;

    // Add imports (Kotlin only).
    for (const imp of COLDSTART_IMPORTS) {
      if (!src.includes(imp)) {
        // Insert after the package declaration's following blank line, or
        // after the first existing import.
        if (/\nimport /.test(src)) {
          src = src.replace(/\nimport /, `\n${imp}\nimport `);
        } else {
          src = src.replace(/(package .*\n)/, `$1\n${imp}\n`);
        }
      }
    }

    // Inject onCreate block right after loadReactNative(this).
    if (!src.includes('rn-perf-tooling cold-start profiling')) {
      src = src.replace(
        new RegExp(`(${ONCREATE_MARKER.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')})`),
        `$1\n${COLDSTART_ONCREATE}`
      );
    }

    cfg.modResults.contents = src;
    return cfg;
  });
}

// 4. Copy the forwarder source into android source tree.
function withForwarderSource(config) {
  return withDangerousMod(config, [
    'android',
    async (cfg) => {
      const src = path.join(__dirname, 'src', FORWARDER_FILE);
      const destDir = path.join(
        cfg.modRequest.platformProjectRoot,
        'app',
        'src',
        'main',
        'java',
        ...FORWARDER_PACKAGE.split('.')
      );
      fs.mkdirSync(destDir, { recursive: true });
      fs.copyFileSync(src, path.join(destDir, FORWARDER_FILE));
      return cfg;
    },
  ]);
}

module.exports = function withColdStartProfiling(config) {
  config = withProfileable(config);
  config = withBuildConfigField(config);
  config = withMainApplicationHook(config);
  config = withForwarderSource(config);
  return config;
};
