import React, { useCallback, useEffect, useRef, useState } from 'react';
import { Animated, Easing, View } from 'react-native';
import { useFocusEffect, useNavigation, useRoute } from '@react-navigation/native';
import { Button, Card, FadeIn, Icon, Screen, ND } from '../components/ui';
import { CHANNEL_COLORS, EEGWaveform } from '../components/charts';
import { T, palette, useTheme } from '../theme';
import { useApp } from '../store';
import { EEG_CHANNELS, EEG_POINTS, api } from '../services/api';

const empty = () => Array.from({ length: EEG_CHANNELS }, () => Array(EEG_POINTS).fill(0));

export default function EEGMonitor() {
  const nav = useNavigation<any>();
  const route = useRoute<any>();
  const { c } = useTheme();
  const { connection } = useApp();
  const connected = connection.status === 'connected';
  const [live, setLive] = useState(false);
  const [, setTick] = useState(0);
  const buf = useRef<number[][]>(empty());
  const stop = useRef<() => void>(() => {});
  const dot = useRef(new Animated.Value(1)).current;

  const start = useCallback(() => {
    stop.current();
    buf.current = empty();
    setLive(true);
    stop.current = api.streamEEG((f) => {
      buf.current = buf.current.map((b, i) => [...b.slice(1), f[i]]);
      setTick((t) => t + 1);
    });
  }, []);

  const end = useCallback(() => {
    stop.current();
    setLive(false);
  }, []);

  // auto-start when navigated from Home, stop when leaving the tab
  const auto = route.params?.autoStart;
  useFocusEffect(
    useCallback(() => {
      if (auto && connected) start();
      return () => end();
    }, [auto, connected]),
  );

  useEffect(() => {
    const a = Animated.loop(
      Animated.sequence([
        Animated.timing(dot, { toValue: 0.25, duration: 700, easing: Easing.inOut(Easing.quad), useNativeDriver: ND }),
        Animated.timing(dot, { toValue: 1, duration: 700, easing: Easing.inOut(Easing.quad), useNativeDriver: ND }),
      ]),
    );
    a.start();
    return () => a.stop();
  }, []);

  const decode = () => {
    end();
    nav.navigate('Decoding');
  };

  // electrode contact demo: all good except a fair one
  const contact = (i: number) => (i === 4 ? palette.warning : palette.success);

  return (
    <Screen
      title="EEG Monitor"
      back={false}
      scroll
      right={
        live ? (
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
            <Animated.View style={{ width: 8, height: 8, borderRadius: 4, backgroundColor: palette.success, opacity: dot }} />
            <T v="caption" color={palette.success}>
              Live
            </T>
          </View>
        ) : (
          <T v="caption" muted>
            Idle
          </T>
        )
      }
    >
      {!connected && (
        <FadeIn>
          <Card style={{ marginBottom: 14, borderColor: palette.warning }}>
            <View style={{ flexDirection: 'row', gap: 12, alignItems: 'center' }}>
              <Icon name="headphones-off" size={28} color={palette.warning} />
              <View style={{ flex: 1 }}>
                <T v="bodyM">Headset not connected</T>
                <T v="caption" muted>
                  Connect your MindSpeak headset to start reading EEG.
                </T>
              </View>
            </View>
            <Button title="Connect Headset" small onPress={() => nav.navigate('ConnectHeadset', { next: 'communicate' })} style={{ marginTop: 12 }} />
          </Card>
        </FadeIn>
      )}

      <FadeIn delay={60}>
        <Card>
          <T v="bodyM" style={{ marginBottom: 8 }}>
            8-Channel EEG Waveform
          </T>
          <EEGWaveform buffers={buf.current} live={live} />
        </Card>
      </FadeIn>

      <FadeIn delay={140} style={{ marginTop: 14 }}>
        <Card pad={12}>
          <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
            {[
              { icon: 'signal-cellular-3', label: 'Signal Quality', value: live ? 'Good' : '--', color: palette.success },
              { icon: 'swap-vertical', label: 'Packet Loss', value: live ? '0%' : '--', color: palette.success },
              { icon: 'flash-alert', label: 'Artifacts', value: live ? 'Low' : '--', color: palette.warning },
            ].map((s) => (
              <View key={s.label} style={{ flex: 1, alignItems: 'center', gap: 2 }}>
                <Icon name={s.icon} size={20} color={live ? s.color : c.textMuted} />
                <T v="caption" muted style={{ fontSize: 10, lineHeight: 14 }}>
                  {s.label}
                </T>
                <T v="bodyM" color={live ? s.color : c.textMuted}>
                  {s.value}
                </T>
              </View>
            ))}
          </View>
        </Card>
      </FadeIn>

      <FadeIn delay={220} style={{ marginTop: 14 }}>
        <T v="bodyM" style={{ marginBottom: 10 }}>
          Electrode Contact
        </T>
        <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
          {Array.from({ length: EEG_CHANNELS }, (_, i) => (
            <View key={i} style={{ alignItems: 'center', gap: 4 }}>
              <View style={{ width: 14, height: 14, borderRadius: 7, backgroundColor: connected ? contact(i) : c.border, boxShadow: connected ? `0 0 8px ${contact(i)}` : undefined }} />
              <T v="caption" muted style={{ fontSize: 9, lineHeight: 12 }}>
                CH{i + 1}
              </T>
            </View>
          ))}
        </View>
      </FadeIn>

      <FadeIn delay={300} style={{ marginTop: 22, gap: 12 }}>
        {live ? (
          <>
            <Button title="Decode Thought" icon="brain" onPress={decode} />
            <Button title="Stop Session" variant="danger" icon="stop-circle-outline" onPress={end} />
          </>
        ) : (
          <Button title="Start Session" icon="play-circle-outline" onPress={start} disabled={!connected} />
        )}
      </FadeIn>
    </Screen>
  );
}
