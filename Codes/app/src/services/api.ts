/**
 * MindSpeak service layer.
 *
 * Everything the UI needs from a "backend" goes through this file. Right now every
 * function is a MOCK (simulated latency + fake EEG data) so the app is fully usable
 * without a server. When the real backend / AI model is ready, replace the body of
 * each function (keep the signatures) and the UI does not need to change.
 *
 * Suggested real endpoints are listed in README.md.
 */
import type { Device } from '../store';
import { PREDICTABLE } from '../vocab';

const delay = (ms: number) => new Promise<void>((r) => setTimeout(r, ms));

export const EEG_CHANNELS = 8;
export const EEG_POINTS = 70;

export type Prediction = {
  word: string;
  confidence: number;
  alternatives: { word: string; confidence: number }[];
};

export const DECODE_STEPS = ['Noise Reduction', 'Feature Extraction', 'AI Inference'];

export const api = {
  /** BLE scan. Calls onFound as devices are discovered; returns a cancel function. */
  scanDevices(onFound: (d: Device) => void): () => void {
    const devices: Device[] = [
      { id: 'ms-eeg-01', name: 'MindSpeak EEG', rssi: -45 },
      { id: 'ms-eeg-02', name: 'MindSpeak 2', rssi: -78 },
      { id: 'other-01', name: 'Other Device', rssi: -90 },
    ];
    const timers = devices.map((d, i) => setTimeout(() => onFound(d), 900 + i * 900));
    return () => timers.forEach(clearTimeout);
  },

  /** Pair with a headset. */
  async connect(_d: Device): Promise<{ battery: number; signal: 'Good' | 'Fair' | 'Poor' }> {
    await delay(1500);
    return { battery: 82, signal: 'Good' };
  },

  /** Live EEG stream: 8 channels in microvolts. Returns a stop function. */
  streamEEG(onFrame: (uV: number[]) => void, everyMs = 70): () => void {
    let t = 0;
    const phases = Array.from({ length: EEG_CHANNELS }, (_, i) => i * 1.3);
    const id = setInterval(() => {
      t += everyMs / 1000;
      onFrame(
        phases.map((p, i) => {
          const alpha = Math.sin(2 * Math.PI * (9 + i * 0.4) * t + p);
          const beta = 0.5 * Math.sin(2 * Math.PI * (20 + i) * t + p * 2);
          const drift = 0.6 * Math.sin(2 * Math.PI * 0.6 * t + i);
          const noise = (Math.random() - 0.5) * 0.6;
          return (alpha + beta + drift + noise) * (18 + i * 3);
        }),
      );
    }, everyMs);
    return () => clearInterval(id);
  },

  /** Run the model on the latest EEG window. Reports progress 0-100 and the current step. */
  async decode(onProgress: (progress: number, step: number) => void, signal?: { cancelled: boolean }): Promise<Prediction | null> {
    const total = 3600;
    const tick = 60;
    for (let elapsed = 0; elapsed <= total; elapsed += tick) {
      if (signal?.cancelled) return null;
      const p = Math.min(100, Math.round((elapsed / total) * 100));
      onProgress(p, Math.min(2, Math.floor((elapsed / total) * 3)));
      await delay(tick);
    }
    const pool = [...PREDICTABLE].sort(() => Math.random() - 0.5);
    const conf = () => 60 + Math.floor(Math.random() * 20);
    const top = 82 + Math.floor(Math.random() * 16);
    return {
      word: pool[0].label,
      confidence: top,
      alternatives: [
        { word: pool[1].label, confidence: Math.min(conf(), top - 8) },
        { word: pool[2].label, confidence: Math.min(conf() - 10, top - 18) },
      ],
    };
  },

  /** POST /calibration/sample — record EEG for one calibration word. */
  async recordCalibration(_word: string, onProgress: (p: number) => void, signal?: { cancelled: boolean }): Promise<boolean> {
    for (let i = 0; i <= 100; i += 4) {
      if (signal?.cancelled) return false;
      onProgress(i);
      await delay(90);
    }
    return true;
  },

  /** POST /alerts/emergency — notify the caregiver. */
  async sendEmergencyAlert(): Promise<void> {
    await delay(1400);
  },
};
