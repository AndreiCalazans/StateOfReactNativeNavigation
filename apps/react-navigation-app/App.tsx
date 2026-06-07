import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { HomeScreen, DetailsScreen, HeavyDetailsScreen, ProfileScreen } from 'shared-ui';

type HomeStackParamList = {
  Home: undefined;
  Details: { id: number };
  Heavy: { id: number };
};

const Stack = createNativeStackNavigator<HomeStackParamList>();
const Tab = createBottomTabNavigator();

function HomeStack() {
  return (
    <Stack.Navigator>
      <Stack.Screen name="Home" options={{ headerShown: false }}>
        {({ navigation }) => (
          <HomeScreen
            onOpenDetails={(id: number) => navigation.navigate('Details', { id })}
            onOpenHeavy={(id: number) => navigation.navigate('Heavy', { id })}
          />
        )}
      </Stack.Screen>
      <Stack.Screen name="Heavy">
        {({ route, navigation }) => (
          <HeavyDetailsScreen id={route.params?.id ?? 0} onBack={() => navigation.goBack()} />
        )}
      </Stack.Screen>
      <Stack.Screen name="Details">
        {({ route, navigation }) => (
          <DetailsScreen id={route.params?.id ?? 0} onBack={() => navigation.goBack()} />
        )}
      </Stack.Screen>
    </Stack.Navigator>
  );
}

export default function App() {
  return (
    <NavigationContainer>
      <Tab.Navigator screenOptions={{ headerShown: false }}>
        <Tab.Screen
          name="HomeTab"
          component={HomeStack}
          options={{ title: 'Home', tabBarButtonTestID: 'tab-home' }}
        />
        <Tab.Screen
          name="Profile"
          component={ProfileScreen}
          options={{ title: 'Profile', tabBarButtonTestID: 'tab-profile' }}
        />
      </Tab.Navigator>
    </NavigationContainer>
  );
}
