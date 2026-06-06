// Custom entry: enable cold-start Hermes profile dumping as early as possible
// (in release builds) before expo-router boots the app.
const { scheduleColdStartDump } = require('rn-perf-tooling/js/coldStartProfiling');
scheduleColdStartDump();

require('expo-router/entry');
