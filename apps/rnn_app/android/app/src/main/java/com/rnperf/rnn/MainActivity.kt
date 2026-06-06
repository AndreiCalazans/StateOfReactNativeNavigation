package com.rnperf.rnn

import com.reactnativenavigation.NavigationActivity

/**
 * react-native-navigation owns the activity: MainActivity extends
 * NavigationActivity instead of ReactActivity. The root is set from JS via
 * Navigation.setRoot in index.js.
 */
class MainActivity : NavigationActivity()
