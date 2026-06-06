module.exports = {
  presets: ['module:@react-native/babel-preset'],
  // Reanimated 4 requires the Worklets babel plugin (must be last).
  plugins: ['react-native-worklets/plugin'],
};
