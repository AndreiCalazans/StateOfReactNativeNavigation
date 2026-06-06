/**
 * bare-min: bare React Native (NO Expo). Renders the shared Home screen with no
 * navigation. The instrumentation-free floor for the "cost of Expo" experiment.
 */
import { AppRegistry } from 'react-native';
import React from 'react';
import { HomeScreen } from 'shared-ui';
import { name as appName } from './app.json';

const App = () => <HomeScreen onOpenDetails={() => {}} />;

AppRegistry.registerComponent(appName, () => App);
