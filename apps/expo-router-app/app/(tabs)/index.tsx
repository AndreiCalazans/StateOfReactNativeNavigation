import { router } from 'expo-router';
import { HomeScreen } from 'shared-ui';

export default function Home() {
  return (
    <HomeScreen
      onOpenDetails={(id: number) =>
        router.push({ pathname: '/details', params: { id: String(id) } })
      }
      onOpenHeavy={(id: number) =>
        router.push({ pathname: '/heavy', params: { id: String(id) } })
      }
    />
  );
}
