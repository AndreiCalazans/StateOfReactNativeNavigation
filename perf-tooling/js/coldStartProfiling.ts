/**
 * Cold-start Hermes sampling profiler control (JS side).
 *
 * The native side (see withColdStartProfiling config plugin) enables the
 * Hermes sampling profiler in MainApplication.onCreate when the release
 * build was compiled with ENABLE_COLD_START_SAMPLING=true. This module is
 * responsible for *stopping* the profiler and dumping the sampled trace to
 * the device's Downloads folder, where the capture scripts pull it from.
 *
 * Strategy: in a non-dev (release) bundle, schedule a single stop+dump a
 * fixed window after the app entry runs. The window must comfortably cover
 * a cold start plus the scripted Maestro interactions we want to profile.
 *
 * Safe no-op in dev or when react-native-release-profiler is unavailable.
 */

// Default capture window (ms) from app entry to profile dump.
const DEFAULT_WINDOW_MS = 9000;

let scheduled = false;

type ReleaseProfiler = {
  startProfiling?: () => boolean;
  stopProfiling: (saveToDownloads: boolean) => Promise<string>;
};

function loadProfiler(): ReleaseProfiler | null {
  try {
    // Lazy require so dev bundles / web don't choke on the native module.
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    return require('react-native-release-profiler') as ReleaseProfiler;
  } catch {
    return null;
  }
}

export function isProfilingEnabled(): boolean {
  // Release bundle only. EXPO_PUBLIC_PROFILING=0 explicitly disables.
  // eslint-disable-next-line no-undef
  const dev = typeof __DEV__ !== 'undefined' && __DEV__;
  if (dev) return false;
  if (process.env.EXPO_PUBLIC_PROFILING === '0') return false;
  return true;
}

/**
 * Schedule the cold-start profile dump. Call once, as early as possible in
 * the JS entry point. Idempotent.
 */
export function scheduleColdStartDump(windowMs: number = DEFAULT_WINDOW_MS): void {
  if (scheduled) return;
  scheduled = true;

  if (!isProfilingEnabled()) return;

  const profiler = loadProfiler();
  if (!profiler) return;

  setTimeout(() => {
    Promise.resolve()
      .then(() => profiler.stopProfiling(true))
      .then((p) => {
        // eslint-disable-next-line no-console
        console.log('[RNPerf] cold-start profile dumped to', p);
      })
      .catch((e) => {
        // eslint-disable-next-line no-console
        console.warn('[RNPerf] stopProfiling failed', e);
      });
  }, windowMs);
}
