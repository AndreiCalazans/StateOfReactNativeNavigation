package com.rnperf.rnnreanimated

import android.util.Log
import com.facebook.hermes.instrumentation.HermesSamplingProfiler
import com.facebook.react.PackageList
import com.facebook.react.ReactHost
import com.facebook.react.ReactNativeHost
import com.facebook.react.ReactPackage
import com.facebook.react.defaults.DefaultNewArchitectureEntryPoint.fabricEnabled
import com.facebook.react.defaults.DefaultReactHost.getDefaultReactHost
import com.reactnativenavigation.NavigationApplication
import com.reactnativenavigation.react.NavigationReactNativeHost
import com.rnperf.systrace.ReactMarkerSystraceForwarder

class MainApplication : NavigationApplication() {

  private val mReactNativeHost: ReactNativeHost =
    object : NavigationReactNativeHost(this) {
      override fun getPackages(): List<ReactPackage> = PackageList(this@MainApplication).packages

      override fun getJSMainModuleName(): String = "index"

      override fun getUseDeveloperSupport(): Boolean = BuildConfig.DEBUG

      override val isNewArchEnabled: Boolean = fabricEnabled
      override val isHermesEnabled: Boolean = true
    }

  override val reactNativeHost: ReactNativeHost
    get() = mReactNativeHost

  override val reactHost: ReactHost
    get() = getDefaultReactHost(applicationContext, mReactNativeHost)

  override fun onCreate() {
    super.onCreate()

    // rn-perf-tooling: cold-start profiling, gated by a release-only flag.
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
  }
}
