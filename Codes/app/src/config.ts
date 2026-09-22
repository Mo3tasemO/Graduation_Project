import { Platform } from 'react-native';
import Constants from 'expo-constants';

/**
 * Where the MindSpeak server (E:\app\server) lives.
 * - web preview: same machine as the page -> http://<page host>:4000
 * - phone in Expo Go: the PC that serves the app (found from the Expo dev-server address) -> http://<PC ip>:4000
 * - production: set EXPO_PUBLIC_API_URL=https://your-server.example.com
 */
function defaultUrl() {
  if (Platform.OS === 'web') return `http://${typeof window !== 'undefined' && window.location.hostname ? window.location.hostname : 'localhost'}:4000`;
  const host = Constants.expoConfig?.hostUri?.split(':')[0];
  return `http://${host ?? 'localhost'}:4000`;
}

export const API_URL = (process.env.EXPO_PUBLIC_API_URL || defaultUrl()).replace(/\/$/, '');
