package com.rnperf.systrace

import android.os.Build
import android.os.Trace
import android.util.Log
import com.facebook.react.bridge.ReactMarker
import com.facebook.react.bridge.ReactMarkerConstants
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

/**
 * Installs a [ReactMarker.MarkerListener] that forwards every React Native
 * internal marker into Android's `Trace` API so it shows up in atrace /
 * Perfetto on the thread where the marker actually fired.
 *
 * Two slices are emitted per marker:
 *
 *   1. An **instant** (`RNMarker.<RAW_NAME>` as a zero-duration begin+end
 *      pair) so every event is a visible point on the timeline regardless
 *      of platform version, thread, or pairing.
 *
 *   2. Opportunistic **async spans** for matched `*_START` / `*_END` pairs:
 *      a `_START` event opens an async section keyed by
 *      `(baseName, tag, instanceKey)` and the matching `_END` closes it.
 *      Async sections (not stack-based `beginSection`) are used because the
 *      paired events may fire on different threads.
 *
 * RN markers like `LOAD_REACT_NATIVE_SO_FILE_*`, `CREATE_REACT_CONTEXT_*`,
 * `RUN_JS_BUNDLE_*`, `NATIVE_MODULE_INITIALIZE_*` etc. fire on the native
 * side before JS exists, so capturing them natively at their real wall-clock
 * time on the right thread is the only faithful way to see them in a trace.
 *
 * Idempotent: calling [install] more than once is a no-op.
 */
object ReactMarkerSystraceForwarder {
  private const val TAG = "RNMarkerSystrace"
  private const val SECTION_PREFIX = "RNMarker."

  private val installed = AtomicBoolean(false)
  private val cookieSeq = AtomicInteger(0)
  private val pendingSpans = ConcurrentHashMap<String, Int>()

  @JvmStatic
  fun install() {
    if (!installed.compareAndSet(false, true)) {
      return
    }
    try {
      ReactMarker.addListener(::onMarker)
      Log.i(TAG, "ReactMarker -> Systrace forwarder installed")
    } catch (t: Throwable) {
      installed.set(false)
      Log.w(TAG, "Failed to install ReactMarker forwarder", t)
    }
  }

  private fun onMarker(name: ReactMarkerConstants, tag: String?, instanceKey: Int) {
    try {
      val rawName = name.name

      // (1) Always emit an instant. Cheap and works on every API level.
      Trace.beginSection(SECTION_PREFIX + rawName)
      Trace.endSection()

      // (2) Opportunistic async-span pairing. beginAsyncSection requires API 29+.
      if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
        return
      }

      when {
        rawName.endsWith("_START") -> {
          val baseName = rawName.substring(0, rawName.length - "_START".length)
          val key = pairKey(baseName, tag, instanceKey)
          val cookie = nextCookie()
          pendingSpans.put(key, cookie)?.let { stale ->
            Trace.endAsyncSection(SECTION_PREFIX + baseName, stale)
          }
          Trace.beginAsyncSection(SECTION_PREFIX + baseName, cookie)
        }
        rawName.endsWith("_END") -> {
          val baseName = rawName.substring(0, rawName.length - "_END".length)
          val key = pairKey(baseName, tag, instanceKey)
          val cookie = pendingSpans.remove(key) ?: return
          Trace.endAsyncSection(SECTION_PREFIX + baseName, cookie)
        }
      }
    } catch (t: Throwable) {
      Log.w(TAG, "ReactMarker listener threw", t)
    }
  }

  private fun pairKey(baseName: String, tag: String?, instanceKey: Int): String =
    baseName + '|' + (tag ?: "") + '|' + instanceKey

  private fun nextCookie(): Int = cookieSeq.incrementAndGet() and 0x7FFFFFFF
}
