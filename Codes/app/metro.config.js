const { getDefaultConfig } = require('expo/metro-config');

const config = getDefaultConfig(__dirname);
// the Node server lives in ./server and must not be bundled into the app
config.resolver.blockList = [/[\/]server[\/].*/];

module.exports = config;
