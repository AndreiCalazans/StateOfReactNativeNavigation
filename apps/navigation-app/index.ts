import { registerRootComponent } from 'expo';
// Enable cold-start Hermes profile dumping (release builds) before the app mounts.
import { scheduleColdStartDump } from 'rn-perf-tooling/js/coldStartProfiling';

import App from './App';

scheduleColdStartDump();

registerRootComponent(App);
