import { useContext } from 'react';
import { StateNavigator } from 'navigation';
import { NavigationHandler, NavigationContext } from 'navigation-react';
import {
  NavigationStack,
  Scene,
  TabBar,
  TabBarItem,
} from 'navigation-react-native';
import { HomeScreen, DetailsScreen, ProfileScreen } from 'shared-ui';

const homeNavigator = new StateNavigator([
  { key: 'home' },
  { key: 'details', trackCrumbTrail: true },
]);
const profileNavigator = new StateNavigator([{ key: 'profile' }]);

function Home() {
  const { stateNavigator } = useContext(NavigationContext);
  return (
    <HomeScreen
      onOpenDetails={(id: number) => stateNavigator.navigate('details', { id })}
    />
  );
}

function Details() {
  const { stateNavigator, data } = useContext(NavigationContext);
  return (
    <DetailsScreen
      id={data?.id ?? 0}
      onBack={() => stateNavigator.navigateBack(1)}
    />
  );
}

function HomeTab() {
  return (
    <NavigationHandler stateNavigator={homeNavigator}>
      <NavigationStack>
        <Scene stateKey="home">
          <Home />
        </Scene>
        <Scene stateKey="details">
          <Details />
        </Scene>
      </NavigationStack>
    </NavigationHandler>
  );
}

function ProfileTab() {
  return (
    <NavigationHandler stateNavigator={profileNavigator}>
      <NavigationStack>
        <Scene stateKey="profile">
          <ProfileScreen />
        </Scene>
      </NavigationStack>
    </NavigationHandler>
  );
}

export default function App() {
  return (
    <TabBar bottomTabs primary>
      <TabBarItem title="Browse" testID="tab-home">
        <HomeTab />
      </TabBarItem>
      <TabBarItem title="Profile" testID="tab-profile">
        <ProfileTab />
      </TabBarItem>
    </TabBar>
  );
}
