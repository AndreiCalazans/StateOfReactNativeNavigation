import { router, useLocalSearchParams } from 'expo-router';
import { DetailsScreen } from 'shared-ui';

export default function Details() {
  const { id } = useLocalSearchParams<{ id?: string }>();
  return (
    <DetailsScreen
      id={id ? Number(id) : 0}
      onBack={() => router.back()}
    />
  );
}
