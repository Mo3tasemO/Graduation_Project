import React, { useEffect, useRef, useState } from 'react';
import { Animated, Easing, View } from 'react-native';
import Svg, { Circle } from 'react-native-svg';
import { useNavigation } from '@react-navigation/native';
import { BrainLogo } from '../components/Logo';
import { Button, Card, FadeIn, Icon, ProgressBar, PulseRing, Screen, ND } from '../components/ui';
import { T, palette, useTheme } from '../theme';
import { DECODE_STEPS, api } from '../services/api';

export default function Decoding() {
  const nav = useNavigation<any>();
  const { c } = useTheme();
  const [progress, setProgress] = useState(0);
  const [step, setStep] = useState(0);
  const spin = useRef(new Animated.Value(0)).current;
  const signal = useRef({ cancelled: false }).current;

  useEffect(() => {
    const a = Animated.loop(Animated.timing(spin, { toValue: 1, duration: 2200, easing: Easing.linear, useNativeDriver: ND }));
    a.start();
    api
      .decode((p, s) => {
        setProgress(p);
        setStep(s);
      }, signal)
      .then((res) => {
        if (res) nav.replace('Prediction', { prediction: res });
      });
    return () => {
      signal.cancelled = true;
      a.stop();
    };
  }, []);

  return (
    <Screen title="Decoding" scroll>
      <FadeIn>
        <Card style={{ alignItems: 'center', paddingVertical: 28, marginTop: 8 }}>
          <View style={{ width: 150, height: 150, alignItems: 'center', justifyContent: 'center' }}>
            <PulseRing size={130} color={c.primary} />
            <PulseRing size={130} color={c.secondary} delay={1000} />
            <Animated.View style={{ position: 'absolute', transform: [{ rotate: spin.interpolate({ inputRange: [0, 1], outputRange: ['0deg', '360deg'] }) }] }}>
              <Svg width={130} height={130}>
                <Circle cx={65} cy={65} r={60} stroke={c.primary} strokeWidth={4} strokeDasharray="90 290" strokeLinecap="round" fill="none" />
                <Circle cx={65} cy={65} r={60} stroke={c.secondary} strokeWidth={4} strokeDasharray="30 350" strokeDashoffset={-180} strokeLinecap="round" fill="none" />
              </Svg>
            </Animated.View>
            <View style={{ width: 98, height: 98, borderRadius: 49, backgroundColor: c.primarySoft, alignItems: 'center', justifyContent: 'center' }}>
              <BrainLogo size={62} color={c.primary} />
            </View>
          </View>
          <T v="title" style={{ marginTop: 18 }}>
            Processing EEG signals...
          </T>
          <T v="caption" muted>
            Reading your imagined word
          </T>

          <View style={{ alignSelf: 'stretch', marginTop: 22, gap: 12 }}>
            {DECODE_STEPS.map((s, i) => {
              const done = step > i || progress === 100;
              const active = step === i && progress < 100;
              return (
                <View key={s} style={{ flexDirection: 'row', alignItems: 'center', gap: 10, opacity: done || active ? 1 : 0.45 }}>
                  <Icon name={done ? 'check-circle' : active ? 'progress-clock' : 'circle-outline'} size={20} color={done ? palette.success : active ? c.primary : c.textMuted} />
                  <T v="bodyM">{s}</T>
                </View>
              );
            })}
          </View>

          <View style={{ alignSelf: 'stretch', marginTop: 20 }}>
            <T v="caption" muted style={{ marginBottom: 6 }}>
              Progress {progress}%
            </T>
            <ProgressBar value={progress} />
          </View>
        </Card>
      </FadeIn>
      <Button title="Cancel" variant="secondary" onPress={() => nav.goBack()} style={{ marginTop: 20 }} />
    </Screen>
  );
}
