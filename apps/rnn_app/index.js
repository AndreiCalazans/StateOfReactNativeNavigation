/**
 * react-native-navigation entry.
 *
 * RNN does not use AppRegistry's root component; instead we register each
 * screen component and set the root (bottom tabs + a stack) once the app has
 * launched.
 */
import { scheduleColdStartDump } from 'rn-perf-tooling/js/coldStartProfiling';
import { Navigation } from 'react-native-navigation';
import React from 'react';
import { HomeScreen, DetailsScreen, HeavyDetailsScreen, ProfileScreen } from 'shared-ui';

// Start dumping the cold-start Hermes profile (release builds) ASAP.
scheduleColdStartDump();

const HOME = 'rnn.Home';
const DETAILS = 'rnn.Details';
const HEAVY = 'rnn.Heavy';
const PROFILE = 'rnn.Profile';

function Home(props) {
  return (
    <HomeScreen
      onOpenDetails={(id) =>
        Navigation.push(props.componentId, {
          component: { name: DETAILS, passProps: { id } },
        })
      }
      onOpenHeavy={(id) =>
        Navigation.push(props.componentId, {
          component: { name: HEAVY, passProps: { id } },
        })
      }
    />
  );
}

function Heavy(props) {
  return (
    <HeavyDetailsScreen
      id={props.id ?? 0}
      onBack={() => Navigation.pop(props.componentId)}
    />
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
Navigation.registerComponent(HEAVY, () => Heavy);
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
