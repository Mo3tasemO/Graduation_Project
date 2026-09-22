import React, { useEffect, useRef, useState } from 'react';
import { Animated, Easing, View } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Button, FadeIn, Icon, PulseRing, ND } from '../components/ui';
import { T, palette, useTheme } from '../theme';
import { haptic, useApp } from '../store';
import { api } from '../services/api';

export default function Emergency() {
  const nav = useNavigation<any>();
  const { c, isDark } = useTheme();
  const { profile, speak, addHistory, addNotification } = useApp();
  const [state, setState] = useState<'idle' | 'sending' | 'sent'>('idle');
  const beat = useRef(new Animated.Value(0)).current;
  const check = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    const a = Animated.loop(
      Animated.sequence([
        Animated.timing(beat, { toValue: 1, duration: 600, easing: Easing.out(Easing.quad), useNativeDriver: ND }),
        Animated.timing(beat, { toValue: 0, duration: 600, easing: Easing.in(Easing.quad), useNativeDriver: ND }),
      ]),
    );
    a.start();
    return () => a.stop();
  }, []);

  const send = async () => {
    setState('sending');
    haptic('warning');
    try {
      await api.sendEmergencyAlert();
      setState('sent');
      haptic('success');
      speak('Emergency. I need help.');
      addHistory('Help me', 100, 'aac');
      addNotification({ type: 'emergency', title: 'Emergency Alert', body: `${profile.caregiver || 'Your caregiver'} has been notified.` });
      Animated.spring(check, { toValue: 1, speed: 8, bounciness: 14, useNativeDriver: ND }).start();
    } catch {
      setState('idle');
    }
  };

  const bg = isDark ? '#2A0F16' : '#FEE9E9';
  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: bg }}>
      <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 28 }}>
        <View style={{ width: 200, height: 200, alignItems: 'center', justifyContent: 'center', marginBottom: 20 }}>
          {state !== 'sent' && (
            <>
              <PulseRing size={150} color={palette.error} duration={1400} />
              <PulseRing size={150} color={palette.error} duration={1400} delay={700} />
            </>
          )}
          <Animated.View
            style={{
              width: 130,
              height: 130,
              borderRadius: 65,
              backgroundColor: state === 'sent' ? palette.success : palette.error,
              alignItems: 'center',
              justifyContent: 'center',
              boxShadow: `0 10px 34px ${state === 'sent' ? palette.success : palette.error}88`,
              transform: [{ scale: state === 'sent' ? check.interpolate({ inputRange: [0, 1], outputRange: [0.7, 1] }) : beat.interpolate({ inputRange: [0, 1], outputRange: [1, 1.08] }) }],
            }}
          >
            {state === 'sent' ? <Icon name="check" size={70} color="#fff" /> : <T v="display" color="#fff" style={{ fontSize: 40 }}>SOS</T>}
          </Animated.View>
        </View>

        <FadeIn key={state} from={10} style={{ alignItems: 'center' }}>
          <T v="h1" color={state === 'sent' ? palette.success : palette.error}>
            {state === 'sent' ? 'Alert Sent' : 'Emergency Alert'}
          </T>
          <T v="body" center style={{ marginTop: 8, color: c.textMuted }}>
            {state === 'sent'
              ? `${profile.caregiver || 'Your caregiver'} and your emergency contacts have been notified.`
              : 'Send an alert to your caregiver and emergency contacts.'}
          </T>
        </FadeIn>

        <View style={{ alignSelf: 'stretch', marginTop: 32, gap: 12 }}>
          {state !== 'sent' && <Button title={state === 'sending' ? 'Sending…' : 'Send Alert'} variant="danger" loading={state === 'sending'} onPress={send} />}
          <Button title={state === 'sent' ? 'Done' : 'Cancel'} variant={state === 'sent' ? 'primary' : 'ghost'} disabled={state === 'sending'} onPress={() => nav.goBack()} style={state === 'sent' ? undefined : { backgroundColor: c.surface }} />
        </View>
      </View>
    </SafeAreaView>
  );
}
