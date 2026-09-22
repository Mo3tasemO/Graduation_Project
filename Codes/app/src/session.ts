import * as SecureStore from 'expo-secure-store';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { Platform } from 'react-native';

/** Secrets (login token, biometric device token): Keychain / Keystore on phones, localStorage on web. */
const native = Platform.OS !== 'web';
const safe = (k: string) => k.replace(/[^A-Za-z0-9._-]/g, '_');

async function get(k: string) {
  try {
    return native ? await SecureStore.getItemAsync(safe(k)) : await AsyncStorage.getItem(k);
  } catch {
    return null;
  }
}
async function set(k: string, v: string) {
  try {
    if (native) await SecureStore.setItemAsync(safe(k), v);
    else await AsyncStorage.setItem(k, v);
  } catch {}
}
async function del(k: string) {
  try {
    if (native) await SecureStore.deleteItemAsync(safe(k));
    else await AsyncStorage.removeItem(k);
  } catch {}
}

let token: string | null = null;

export const session = {
  get token() {
    return token;
  },
  async load() {
    token = await get('ms.token');
  },
  async setToken(t: string) {
    token = t;
    await set('ms.token', t);
  },
  async clear() {
    token = null;
    await del('ms.token');
  },
  getDeviceToken: (email: string) => get(`ms.device.${email.toLowerCase()}`),
  setDeviceToken: (email: string, t: string) => set(`ms.device.${email.toLowerCase()}`, t),
  removeDeviceToken: (email: string) => del(`ms.device.${email.toLowerCase()}`),
};
