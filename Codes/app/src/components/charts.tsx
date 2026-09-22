import React, { useEffect, useRef, useState } from 'react';
import { Animated, Easing, View } from 'react-native';
import Svg, { Path } from 'react-native-svg';
import { T, useTheme } from '../theme';
import { EEG_POINTS } from '../services/api';
import { ND } from './ui';

export const CHANNEL_COLORS = ['#2563EB', '#06B6D4', '#10B981', '#F59E0B', '#EF4444', '#7C3AED', '#EC4899', '#0EA5E9'];

/** Multi-channel EEG trace. `buffers[ch]` holds the most recent samples in µV. */
export function EEGWaveform({ buffers, rowHeight = 34, live = true }: { buffers: number[][]; rowHeight?: number; live?: boolean }) {
  const { c } = useTheme();
  const [w, setW] = useState(0);
  return (
    <View onLayout={(e) => setW(e.nativeEvent.layout.width)}>
      {buffers.map((buf, i) => {
        const labelW = 34;
        const valW = 56;
        const plotW = Math.max(0, w - labelW - valW);
        const step = plotW / (EEG_POINTS - 1);
        let d = '';
        buf.forEach((v, k) => {
          const y = rowHeight / 2 - Math.max(-1, Math.min(1, v / 90)) * (rowHeight / 2 - 3);
          d += `${k === 0 ? 'M' : 'L'}${(k * step).toFixed(1)} ${y.toFixed(1)} `;
        });
        const last = buf[buf.length - 1] ?? 0;
        return (
          <View key={i} style={{ flexDirection: 'row', alignItems: 'center', height: rowHeight }}>
            <T v="caption" muted style={{ width: labelW, fontSize: 10 }}>
              Ch{i + 1}
            </T>
            <Svg width={plotW} height={rowHeight}>
              <Path d={`M0 ${rowHeight / 2} H${plotW}`} stroke={c.border} strokeWidth={1} strokeDasharray="3 4" />
              {live && d ? <Path d={d} stroke={CHANNEL_COLORS[i]} strokeWidth={1.6} fill="none" strokeLinejoin="round" /> : null}
            </Svg>
            <T v="caption" muted style={{ width: valW, textAlign: 'right', fontSize: 10 }}>
              {live ? `${Math.round(Math.abs(last)) + 40} µV` : '-- µV'}
            </T>
          </View>
        );
      })}
    </View>
  );
}

/** Audio-style bars. When `active`, heights animate. */
export function SoundBars({ active, count = 34, color, height = 44 }: { active: boolean; count?: number; color?: string; height?: number }) {
  const { c } = useTheme();
  const base = useRef(Array.from({ length: count }, (_, i) => 0.25 + 0.55 * Math.abs(Math.sin(i * 0.55) * Math.cos(i * 0.21)))).current;
  const [h, setH] = useState(base);
  useEffect(() => {
    if (!active) {
      setH(base);
      return;
    }
    const id = setInterval(() => setH(base.map((b) => Math.min(1, Math.max(0.12, b * (0.5 + Math.random()))))), 110);
    return () => clearInterval(id);
  }, [active]);
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', height }}>
      {h.map((v, i) => (
        <View key={i} style={{ width: 3, height: v * height, borderRadius: 2, backgroundColor: color ?? c.secondary, opacity: active ? 1 : 0.7 }} />
      ))}
    </View>
  );
}

/** Count-up number animation. */
export function useCountUp(target: number, duration = 900) {
  const [n, setN] = useState(0);
  useEffect(() => {
    const v = new Animated.Value(0);
    const id = v.addListener(({ value }) => setN(Math.round(value)));
    Animated.timing(v, { toValue: target, duration, easing: Easing.out(Easing.cubic), useNativeDriver: false }).start();
    return () => v.removeListener(id);
  }, [target]);
  return n;
}
