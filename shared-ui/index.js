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
  secondaryBtn: {
    marginHorizontal: 16,
    marginBottom: 8,
    backgroundColor: '#11181C',
    paddingVertical: 14,
    borderRadius: 10,
    alignItems: 'center',
  },
  hRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
    paddingHorizontal: 16,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#E6E8EB',
  },
  hAvatar: { width: 44, height: 44, borderRadius: 22, marginRight: 12 },
  hCol: { flex: 1 },
  hTitle: { fontSize: 15, fontWeight: '600', color: '#11181C' },
  hSub: { fontSize: 13, color: '#687076', marginTop: 2 },
  hTags: { flexDirection: 'row', marginTop: 6 },
  hTag: {
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 6,
    backgroundColor: '#Eef1f3',
    marginRight: 6,
  },
  hTagText: { fontSize: 11, color: '#3a4a52' },
});

// Deterministic heavier dataset (two dozen rows).
const HEAVY_ITEMS = Array.from({ length: 24 }, (_, i) => ({
  id: i,
  title: `Record ${i} \u2014 ${['Alpha', 'Bravo', 'Charlie', 'Delta'][i % 4]}`,
  subtitle: `Updated ${i + 1}h ago \u00b7 ${1000 + i * 37} views`,
  color: `hsl(${(i * 37) % 360}, 60%, 62%)`,
  tags: [['new', 'sync', 'cloud'][i % 3], ['hi', 'med', 'low'][i % 3], `#${i}`],
}));

function HomeScreen({ onOpenDetails, onOpenHeavy }) {
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
    onOpenHeavy
      ? React.createElement(Pressable, {
          testID: 'open-heavy',
          style: styles.secondaryBtn,
          onPress: () => onOpenHeavy(0),
          children: React.createElement(
            Text,
            { style: styles.primaryBtnText },
            'Open Heavy (24-row list)'
          ),
        })
      : null,
    React.createElement(FlatList, {
      data: ITEMS,
      keyExtractor: (item) => String(item.id),
      renderItem,
      initialNumToRender: 12,
    })
  );
}

// Heavier destination: a 24-row FlatList rendered synchronously (all rows on
// mount), each row ~11 native nodes. Stresses React reconciliation + the Fabric
// commit (createNode/appendChild) far more than the trivial DetailsScreen.
function HeavyDetailsScreen({ id, onBack }) {
  const renderItem = ({ item }) =>
    React.createElement(
      View,
      { style: styles.hRow },
      React.createElement(View, { style: [styles.hAvatar, { backgroundColor: item.color }] }),
      React.createElement(
        View,
        { style: styles.hCol },
        React.createElement(Text, { style: styles.hTitle }, item.title),
        React.createElement(Text, { style: styles.hSub }, item.subtitle),
        React.createElement(
          View,
          { style: styles.hTags },
          ...item.tags.map((t, i) =>
            React.createElement(
              View,
              { key: i, style: styles.hTag },
              React.createElement(Text, { style: styles.hTagText }, t)
            )
          )
        )
      )
    );

  return React.createElement(
    View,
    { testID: 'heavy-screen', style: styles.screen },
    React.createElement(
      View,
      { style: styles.header },
      React.createElement(Text, { style: styles.title }, `Heavy #${id ?? 0}`),
      React.createElement(Text, { style: styles.subtitle }, '24 rows mounted at once')
    ),
    React.createElement(Pressable, {
      testID: 'heavy-back',
      style: styles.primaryBtn,
      onPress: onBack,
      children: React.createElement(Text, { style: styles.primaryBtnText }, 'Go Back'),
    }),
    React.createElement(FlatList, {
      data: HEAVY_ITEMS,
      keyExtractor: (item) => String(item.id),
      renderItem,
      initialNumToRender: 24,
      windowSize: 25,
      removeClippedSubviews: false,
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

module.exports = {
  ITEMS,
  HEAVY_ITEMS,
  HomeScreen,
  DetailsScreen,
  HeavyDetailsScreen,
  ProfileScreen,
};
