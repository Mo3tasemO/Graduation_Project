import React, { useEffect, useRef, useState } from 'react';
import { Animated, Easing, View } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { BrainLogo } from '../components/Logo';
import { Button, Card, FadeIn, Icon, ProgressBar, PulseRing, Screen, ND, useToast } from '../components/ui';
import { T, palette, useTheme } from '../theme';
import { haptic, useApp } from '../store';
import { api } from '../services/api';
import { CALIBRATION_WORDS } from '../vocab';

export default function Calibration() {
  const nav = useNavigation<any>();
  const { c } = useTheme();
  const { connection, setCalibrated, addNotification } = useApp();
  const toast = useToast();
  const [done, setDone] = useState(0);
  const [rec, setRec] = useState(false);
  const [p, setP] = useState(0);
  const signal = useRef({ cancelled: false }).current;
  const pop = useRef(new Animated.Value(1)).current;
  const finished = done >= CALIBRATION_WORDS.length;

  useEffect(() => () => void (signal.cancelled = true), []);

  const start = async () => {
    if (connection.status !== 'connected') {
      toast('Connect your headset first', 'error');
      return nav.navigate('ConnectHeadset');
    }
    setRec(true);
    setP(0);
    const ok = await api.recordCalibration(CALIBRATION_WORDS[done], setP, signal);
    if (!ok) return;
    setRec(false);
    haptic('success');
    Animated.sequence([
      Animated.timing(pop, { toValue: 1.06, duration: 140, useNativeDriver: ND }),
      Animated.spring(pop, { toValue: 1, useNativeDriver: ND }),
    ]).start();
    const n = done + 1;
    setDone(n);
    if (n === CALIBRATION_WORDS.length) {
      setCalibrated(true);
      addNotification({ type: 'model', title: 'Calibration complete', body: 'Your AI model has been personalised.' });
      toast('Calibration complete!', 'success');
    }
  };

  const word = CALIBRATION_WORDS[Math.min(done, CALIBRATION_WORDS.length - 1)];
  const overall = (done / CALIBRATION_WORDS.length) * 100;

  return (
    <Screen title="Calibration" scroll>
      <FadeIn style={{ alignItems: 'center', marginTop: 8 }}>
        <View style={{ width: 130, height: 130, alignItems: 'center', justifyContent: 'center' }}>
          {rec && <PulseRing size={110} color={c.primary} duration={1200} />}
          <View style={{ width: 96, height: 96, borderRadius: 48, backgroundColor: finished ? palette.success + '22' : c.primarySoft, alignItems: 'center', justifyContent: 'center' }}>
            {finished ? <Icon name="check-circle" size={54} color={palette.success} /> : <BrainLogo size={62} color={c.primary} />}
          </View>
        </View>
        <T v="title" center style={{ marginTop: 10 }}>
          {finished ? 'All set!' : 'Help us personalise your model'}
        </T>
        {!finished && (
          <>
            <T v="caption" muted style={{ marginTop: 6 }}>
              Focus on the word:
            </T>
            <Animated.View style={{ transform: [{ scale: pop }] }}>
              <T v="display" color={c.primary}>
                {word}
              </T>
            </Animated.View>
          </>
        )}
      </FadeIn>

      <View style={{ marginTop: 18 }}>
        <ProgressBar value={rec ? overall + p / CALIBRATION_WORDS.length : overall} />
        <T v="caption" muted center style={{ marginTop: 6 }}>
          {Math.min(done + (rec ? 1 : 0), 5)} / {CALIBRATION_WORDS.length}
          {rec ? `  ·  Recording ${p}%` : ''}
        </T>
      </View>

      <Button
        title={finished ? 'Done' : rec ? 'Recording…' : done === 0 ? 'Start' : 'Next word'}
        onPress={finished ? () => nav.goBack() : start}
        loading={rec}
        style={{ marginTop: 18 }}
      />
      {!finished && !rec && done === 0 && (
        <T v="caption" muted center style={{ marginTop: 10 }}>
          Think of the word clearly for a few seconds while the headset records.
        </T>
      )}

      <Card style={{ marginTop: 20 }} pad={8}>
        {CALIBRATION_WORDS.map((w, i) => {
          const ok = i < done;
          const cur = i === done && rec;
          return (
            <View key={w} style={{ flexDirection: 'row', alignItems: 'center', paddingVertical: 10, paddingHorizontal: 8 }}>
              <T v="body" muted style={{ width: 28 }}>
                {i + 1}.
              </T>
              <T v="bodyM" style={{ flex: 1 }} color={ok ? c.text : c.textMuted}>
                {w}
              </T>
              <Icon name={ok ? 'check-circle' : cur ? 'progress-clock' : 'circle-outline'} size={22} color={ok ? palette.success : cur ? c.primary : c.textMuted} />
            </View>
          );
        })}
      </Card>
    </Screen>
  );
}
