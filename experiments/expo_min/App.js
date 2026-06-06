// expo-min: minimal Expo app (blank), renders the shared Home screen, no
// navigation. Difference vs bare-min isolates the Expo + expo-modules-core tax.
import { HomeScreen } from 'shared-ui';

export default function App() {
  return <HomeScreen onOpenDetails={() => {}} />;
}
