const React = require('react');
const {
  View,
  Text,
  FlatList,
  Pressable,
  StyleSheet,
  ScrollView,
} = require('react-native');

// Deterministic shared dataset so every example renders the same list.
const ITEMS = Array.from({ length: 30 }, (_, i) => ({
  id: i,
  title: `Item ${i}`,
  subtitle: `Tap to open details for item ${i}`,
}));

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: '#ffffff' },
  header: {
    paddingHorizontal: 16,
    paddingTop: 16,
    paddingBottom: 8,
  },
  title: { fontSize: 22, fontWeight: '700', color: '#11181C' },
  subtitle: { fontSize: 14, color: '#687076', marginTop: 4 },
  primaryBtn: {
    margin: 16,
    backgroundColor: '#0a7ea4',
    paddingVertical: 14,
    borderRadius: 10,
    alignItems: 'center',
  },
  primaryBtnText: { color: '#fff', fontSize: 16, fontWeight: '600' },
  row: {
    paddingVertical: 14,
    paddingHorizontal: 16,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#E6E8EB',
  },
  rowTitle: { fontSize: 16, color: '#11181C' },
  rowSub: { fontSize: 13, color: '#687076', marginTop: 2 },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 },
  big: { fontSize: 28, fontWeight: '800', color: '#11181C', marginBottom: 12 },
  body: { fontSize: 16, color: '#11181C', textAlign: 'center' },
});

function HomeScreen({ onOpenDetails }) {
  const renderItem = ({ item }) =>
    React.createElement(
      Pressable,
      {
        testID: `home-row-${item.id}`,
        style: styles.row,
        onPress: () => onOpenDetails(item.id),
      },
      React.createElement(Text, { style: styles.rowTitle }, item.title),
      React.createElement(Text, { style: styles.rowSub }, item.subtitle)
    );

  return React.createElement(
    View,
    { testID: 'home-screen', style: styles.screen },
    React.createElement(
      View,
      { style: styles.header },
      React.createElement(Text, { style: styles.title }, 'Home'),
      React.createElement(
        Text,
        { style: styles.subtitle },
        'Navigation performance comparison'
      )
    ),
    React.createElement(Pressable, {
      testID: 'open-details',
      style: styles.primaryBtn,
      onPress: () => onOpenDetails(0),
      children: React.createElement(
        Text,
        { style: styles.primaryBtnText },
        'Open Details'
      ),
    }),
    React.createElement(FlatList, {
      data: ITEMS,
      keyExtractor: (item) => String(item.id),
      renderItem,
      initialNumToRender: 12,
    })
  );
}

function DetailsScreen({ id, onBack }) {
  return React.createElement(
    View,
    { testID: 'details-screen', style: [styles.screen, styles.center] },
    React.createElement(Text, { style: styles.big }, `Details #${id ?? 0}`),
    React.createElement(
      Text,
      { style: styles.body },
      'This screen was pushed onto the stack.'
    ),
    React.createElement(Pressable, {
      testID: 'details-back',
      style: styles.primaryBtn,
      onPress: onBack,
      children: React.createElement(Text, { style: styles.primaryBtnText }, 'Go Back'),
    })
  );
}

function ProfileScreen() {
  return React.createElement(
    ScrollView,
    {
      testID: 'profile-screen',
      style: styles.screen,
      contentContainerStyle: styles.center,
    },
    React.createElement(Text, { style: styles.big }, 'Profile'),
    React.createElement(
      Text,
      { style: styles.body },
      'A second tab to exercise tab switching.'
    )
  );
}

module.exports = { ITEMS, HomeScreen, DetailsScreen, ProfileScreen };
