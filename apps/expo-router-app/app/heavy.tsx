import { router, useLocalSearchParams } from 'expo-router';
import { HeavyDetailsScreen } from 'shared-ui';

export default function Heavy() {
  const { id } = useLocalSearchParams<{ id?: string }>();
  return (
    <HeavyDetailsScreen id={id ? Number(id) : 0} onBack={() => router.back()} />
  );
}
