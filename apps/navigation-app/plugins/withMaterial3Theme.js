const { withAndroidStyles } = require('@expo/config-plugins');

/**
 * navigation-react-native renders native Material components (TabLayout /
 * BottomNavigationView, Toolbar, etc). Those require the app's Android theme
 * to descend from a Material3 theme; Expo's default AppTheme is
 * `Theme.AppCompat.DayNight.NoActionBar`, under which the Material tab bar
 * silently fails to render. This switches the parent to Material3.
 */
module.exports = function withMaterial3Theme(config) {
  return withAndroidStyles(config, (cfg) => {
    const styles = cfg.modResults;
    for (const style of styles.resources.style || []) {
      if (style.$.name === 'AppTheme') {
        style.$.parent = 'Theme.Material3.DayNight.NoActionBar';
      }
    }
    return cfg;
  });
};
