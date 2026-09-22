import React, { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import * as Speech from 'expo-speech';
import * as Haptics from 'expo-haptics';
import { Platform } from 'react-native';
import { auth as authApi, ServerData } from './services/auth';
import { session } from './session';

export type Settings = {
  darkMode: boolean;
  highContrast: boolean;
  largeText: boolean;
  voice: 'Female' | 'Male';
  speechRate: number; // 0.5 - 1.5
  volume: number; // 0 - 100
  notifications: boolean;
  language: string;
};

export type Profile = {
  name: string;
  email: string;
  id: string;
  age: string;
  caregiver: string;
  caregiverRelation: string;
  caregiverPhone: string;
  condition: string;
  allergies: string;
  bloodType: string;
  birthDate: string; // ISO yyyy-mm-dd
  phone: string;
  photo: string; // uri, '' when none
};

const BLANK_PROFILE: Profile = {
  name: '',
  email: '',
  id: '',
  age: '',
  caregiver: '',
  caregiverRelation: '',
  caregiverPhone: '',
  condition: '',
  allergies: '',
  bloodType: '',
  birthDate: '',
  phone: '',
  photo: '',
};

export type HistoryItem = {
  id: string;
  text: string;
  confidence: number;
  time: number;
  source: 'eeg' | 'aac';
};

export type AppNotification = {
  id: string;
  type: 'headset' | 'message' | 'emergency' | 'battery' | 'model';
  title: string;
  body: string;
  time: number;
  read: boolean;
};

export type Device = { id: string; name: string; rssi: number };

export type Connection = {
  status: 'disconnected' | 'connecting' | 'connected';
  device?: Device;
  battery: number;
  signal: 'Good' | 'Fair' | 'Poor';
};

type Persisted = {
  settings: Settings;
  profile: Profile;
  history: HistoryItem[];
  notifications: AppNotification[];
  signedIn: boolean;
  onboarded: boolean;
  calibrated: boolean;
  biometricEmail: string; // account that enabled fingerprint / Face ID login, '' when off
};

const KEY = 'mindspeak:v1';
const now = Date.now();
const min = 60000;

const DEFAULT: Persisted = {
  settings: {
    darkMode: false,
    highContrast: false,
    largeText: false,
    voice: 'Female',
    speechRate: 1,
    volume: 70,
    notifications: true,
    language: 'English',
  },
  profile: {
    name: 'Sara Ahmed',
    email: '',
    id: '202206401',
    age: '22',
    caregiver: 'Mona Ahmed',
    caregiverRelation: 'Mother',
    caregiverPhone: '',
    condition: '',
    allergies: '',
    bloodType: '',
    birthDate: '',
    phone: '',
    photo: '',
  },
  history: [
    { id: 'h1', text: 'I need water', confidence: 94, time: now - 45 * min, source: 'eeg' },
    { id: 'h2', text: 'Help me', confidence: 91, time: now - 80 * min, source: 'eeg' },
    { id: 'h3', text: 'Yes', confidence: 88, time: now - 150 * min, source: 'eeg' },
    { id: 'h4', text: 'No', confidence: 85, time: now - 200 * min, source: 'eeg' },
    { id: 'h5', text: 'Thank you', confidence: 90, time: now - 26 * 60 * min, source: 'eeg' },
    { id: 'h6', text: 'Pain', confidence: 87, time: now - 27 * 60 * min, source: 'eeg' },
  ],
  notifications: [
    { id: 'n1', type: 'model', title: 'Model Updated', body: 'Your AI model has been updated.', time: now - 3 * 24 * 60 * min, read: true },
    { id: 'n2', type: 'battery', title: 'Low Battery', body: 'Headset battery is 15%.', time: now - 26 * 60 * min, read: true },
    { id: 'n3', type: 'emergency', title: 'Emergency Alert', body: 'Your caregiver has been notified.', time: now - 28 * 60 * min, read: true },
  ],
  signedIn: false,
  onboarded: false,
  calibrated: false,
  biometricEmail: '',
};

type SpeakOpts = {
  rate?: number;
  volume?: number;
  voice?: 'Female' | 'Male';
  onStart?: () => void;
  onDone?: () => void;
};

type Ctx = {
  ready: boolean;
  settings: Settings;
  setSetting: <K extends keyof Settings>(k: K, v: Settings[K]) => void;
  profile: Profile;
  updateProfile: (p: Partial<Profile>) => void;
  signedIn: boolean;
  onboarded: boolean;
  finishOnboarding: () => void;
  signIn: (user: Partial<Profile>, srv?: ServerData | null) => void;
  signOut: () => void;
  biometricEmail: string;
  setBiometricEmail: (e: string) => void;
  history: HistoryItem[];
  addHistory: (text: string, confidence: number, source: 'eeg' | 'aac') => void;
  clearHistory: () => void;
  notifications: AppNotification[];
  addNotification: (n: Omit<AppNotification, 'id' | 'time' | 'read'>) => void;
  markRead: (id: string) => void;
  markAllRead: () => void;
  unread: number;
  connection: Connection;
  setConnection: (c: Partial<Connection>) => void;
  disconnect: () => void;
  calibrated: boolean;
  setCalibrated: (v: boolean) => void;
  speak: (text: string, o?: SpeakOpts) => void;
  stopSpeaking: () => void;
};

const AppContext = createContext<Ctx>(null as any);
export const useApp = () => useContext(AppContext);

export function haptic(kind: 'light' | 'success' | 'warning' = 'light') {
  if (Platform.OS === 'web') return;
  try {
    if (kind === 'light') Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    else Haptics.notificationAsync(kind === 'success' ? Haptics.NotificationFeedbackType.Success : Haptics.NotificationFeedbackType.Warning);
  } catch {}
}

const uid = () => Math.random().toString(36).slice(2, 10);

export function AppProvider({ children }: { children: React.ReactNode }) {
  const [ready, setReady] = useState(false);
  const [data, setData] = useState<Persisted>(DEFAULT);
  const [connection, setConn] = useState<Connection>({ status: 'disconnected', battery: 0, signal: 'Good' });

  useEffect(() => {
    (async () => {
      try {
        await session.load();
        const raw = await AsyncStorage.getItem(KEY);
        if (raw) {
          const saved = JSON.parse(raw) as Partial<Persisted>;
          setData({
            ...DEFAULT,
            ...saved,
            signedIn: !!saved.signedIn && !!session.token, // no login token -> must log in again
            settings: { ...DEFAULT.settings, ...saved.settings },
            profile: { ...DEFAULT.profile, ...saved.profile },
          });
        }
      } catch {}
      setReady(true);
    })();
  }, []);

  useEffect(() => {
    if (ready) AsyncStorage.setItem(KEY, JSON.stringify(data)).catch(() => {});
  }, [data, ready]);

  // cloud sync: whenever the patient's data changes, save it to the server (debounced)
  useEffect(() => {
    if (!ready || !data.signedIn || !session.token) return;
    const t = setTimeout(() => {
      authApi.pushData({ profile: data.profile, settings: data.settings, history: data.history, notifications: data.notifications, calibrated: data.calibrated }).catch(() => {});
    }, 1500);
    return () => clearTimeout(t);
  }, [data.profile, data.settings, data.history, data.notifications, data.calibrated, data.signedIn, ready]);

  const patch = useCallback((p: Partial<Persisted>) => setData((d) => ({ ...d, ...p })), []);

  const addNotification: Ctx['addNotification'] = useCallback((n) => {
    setData((d) => ({ ...d, notifications: [{ ...n, id: uid(), time: Date.now(), read: false }, ...d.notifications] }));
  }, []);

  const speak: Ctx['speak'] = useCallback(
    (text, o = {}) => {
      const s = data.settings;
      const voice = o.voice ?? s.voice;
      try {
        Speech.stop();
        Speech.speak(text, {
          rate: o.rate ?? s.speechRate,
          pitch: voice === 'Female' ? 1.15 : 0.85,
          volume: (o.volume ?? s.volume) / 100,
          onStart: o.onStart,
          onDone: o.onDone,
          onStopped: o.onDone,
          onError: o.onDone,
        });
        // some platforms never fire onStart/onDone; make sure UI can't get stuck
        if (o.onStart) o.onStart();
      } catch {
        o.onDone?.();
      }
    },
    [data.settings],
  );

  const value = useMemo<Ctx>(
    () => ({
      ready,
      settings: data.settings,
      setSetting: (k, v) => setData((d) => ({ ...d, settings: { ...d.settings, [k]: v } })),
      profile: data.profile,
      updateProfile: (p) => setData((d) => ({ ...d, profile: { ...d.profile, ...p } })),
      signedIn: data.signedIn,
      onboarded: data.onboarded,
      finishOnboarding: () => patch({ onboarded: true }),
      signIn: (user, srv) =>
        setData((d) => ({
          ...d,
          signedIn: true,
          // the server is the source of truth for the account; a brand-new patient starts clean
          profile: { ...BLANK_PROFILE, ...(srv?.profile ?? {}), ...user },
          settings: srv?.settings ? { ...DEFAULT.settings, ...srv.settings } : d.settings,
          history: srv?.history ?? [],
          calibrated: srv?.calibrated ?? false,
          notifications: srv?.notifications?.length
            ? srv.notifications
            : [{ id: uid(), type: 'model', title: 'Welcome to MindSpeak', body: 'Connect your headset and run a calibration to personalise your model.', time: Date.now(), read: false }],
        })),
      biometricEmail: data.biometricEmail,
      setBiometricEmail: (e) => patch({ biometricEmail: e }),
      signOut: () => {
        setConn({ status: 'disconnected', battery: 0, signal: 'Good' });
        session.clear();
        patch({ signedIn: false });
      },
      history: data.history,
      addHistory: (text, confidence, source) =>
        setData((d) => ({ ...d, history: [{ id: uid(), text, confidence, time: Date.now(), source }, ...d.history] })),
      clearHistory: () => patch({ history: [] }),
      notifications: data.notifications,
      addNotification,
      markRead: (id) => setData((d) => ({ ...d, notifications: d.notifications.map((n) => (n.id === id ? { ...n, read: true } : n)) })),
      markAllRead: () => setData((d) => ({ ...d, notifications: d.notifications.map((n) => ({ ...n, read: true })) })),
      unread: data.notifications.filter((n) => !n.read).length,
      connection,
      setConnection: (c) => setConn((p) => ({ ...p, ...c })),
      disconnect: () => setConn({ status: 'disconnected', battery: 0, signal: 'Good' }),
      calibrated: data.calibrated,
      setCalibrated: (v) => patch({ calibrated: v }),
      speak,
      stopSpeaking: () => {
        try {
          Speech.stop();
        } catch {}
      },
    }),
    [ready, data, connection, speak, addNotification, patch],
  );

  return <AppContext.Provider value={value}>{children}</AppContext.Provider>;
}
