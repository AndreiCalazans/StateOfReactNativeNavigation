/**
 * EXPERIMENT: react-native-navigation (the leanest baseline) + Reanimated +
 * Worklets, with everything else identical to apps/rnn_app. Purpose: isolate
 * how much of Expo Router's cold-start / RAM cost comes from the
 * Reanimated/Worklets runtime by adding ONLY that to the lean app.
 */
import { scheduleColdStartDump } from 'rn-perf-tooling/js/coldStartProfiling';
import { Navigation } from 'react-native-navigation';
import React from 'react';
import { View } from 'react-native';
// Importing Reanimated initializes the Worklets runtime at startup (same as the
// Expo Router app, where it is pulled in transitively + autolinked).
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withRepeat,
  withTiming,
} from 'react-native-reanimated';
import { HomeScreen, DetailsScreen, ProfileScreen } from 'shared-ui';

scheduleColdStartDump();

const HOME = 'rnn.Home';
const DETAILS = 'rnn.Details';
const PROFILE = 'rnn.Profile';

// A tiny on-screen Reanimated animation so the Worklets UI runtime is actually
// exercised during cold start (not just linked). Kept 1px so the shared UI and
// testIDs are unchanged.
function ReanimatedProbe() {
  const o = useSharedValue(0.2);
  React.useEffect(() => {
    o.value = withRepeat(withTiming(1, { duration: 800 }), -1, true);
  }, [o]);
  const style = useAnimatedStyle(() => ({ opacity: o.value }));
  return <Animated.View style={[{ width: 1, height: 1 }, style]} />;
}

function Home(props) {
  return (
    <View style={{ flex: 1 }}>
      <ReanimatedProbe />
      <HomeScreen
        onOpenDetails={(id) =>
          Navigation.push(props.componentId, {
            component: { name: DETAILS, passProps: { id } },
          })
        }
      />
    </View>
  );
}

function Details(props) {
  return (
    <DetailsScreen
      id={props.id ?? 0}
      onBack={() => Navigation.pop(props.componentId)}
    />
  );
}

Navigation.registerComponent(HOME, () => Home);
Navigation.registerComponent(DETAILS, () => Details);
Navigation.registerComponent(PROFILE, () => ProfileScreen);

Navigation.events().registerAppLaunchedListener(() => {
  Navigation.setRoot({
    root: {
      bottomTabs: {
        children: [
          {
            stack: {
              children: [{ component: { name: HOME } }],
              options: {
                topBar: { visible: false },
                bottomTab: { text: 'Browse', testID: 'tab-home' },
              },
            },
          },
          {
            stack: {
              children: [{ component: { name: PROFILE } }],
              options: {
                topBar: { visible: false },
                bottomTab: { text: 'Profile', testID: 'tab-profile' },
              },
            },
          },
        ],
      },
    },
  });
});
