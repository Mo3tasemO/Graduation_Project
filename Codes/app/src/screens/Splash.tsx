import React, { useEffect, useRef } from 'react';
import { Animated, Easing, View, useWindowDimensions } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import Svg, { Path } from 'react-native-svg';
import { useNavigation } from '@react-navigation/native';
import { BrainLogo } from '../components/Logo';
import { ND } from '../components/ui';
import { T, useTheme } from '../theme';
import { useApp } from '../store';

export default function Splash() {
  const nav = useNavigation<any>();
  const { c, isDark } = useTheme();
  const { onboarded, signedIn } = useApp();
  const { width } = useWindowDimensions();
  const logo = useRef(new Animated.Value(0)).current;
  const text = useRef(new Animated.Value(0)).current;
  const bar = useRef(new Animated.Value(0)).current;
  const wave = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    Animated.sequence([
      Animated.spring(logo, { toValue: 1, speed: 6, bounciness: 12, useNativeDriver: ND }),
      Animated.timing(text, { toValue: 1, duration: 500, useNativeDriver: ND }),
    ]).start();
    Animated.timing(bar, { toValue: 1, duration: 2300, easing: Easing.inOut(Easing.quad), useNativeDriver: false }).start();
    const w = Animated.loop(Animated.timing(wave, { toValue: 1, duration: 5000, easing: Easing.linear, useNativeDriver: ND }));
    w.start();
    const t = setTimeout(() => nav.replace(signedIn ? 'Main' : onboarded ? 'Login' : 'Onboarding'), 2700);
    return () => {
      clearTimeout(t);
      w.stop();
    };
  }, []);

  const grad = isDark ? ['#0B1220', '#0F1B33'] : ['#EAF2FF', '#F8FAFC'];
  const waveW = width * 2;
  return (
    <LinearGradient colors={grad as any} style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
      <Animated.View style={{ alignItems: 'center', opacity: logo, transform: [{ scale: logo.interpolate({ inputRange: [0, 1], outputRange: [0.4, 1] }) }] }}>
        <View style={{ width: 130, height: 130, borderRadius: 65, backgroundColor: c.surface, alignItems: 'center', justifyContent: 'center', boxShadow: `0 12px 40px ${c.shadow}` }}>
          <BrainLogo size={84} color={c.primary} />
        </View>
      </Animated.View>
      <Animated.View style={{ alignItems: 'center', marginTop: 22, opacity: text, transform: [{ translateY: text.interpolate({ inputRange: [0, 1], outputRange: [12, 0] }) }] }}>
        <T v="display" color={c.primary}>
          MindSpeak
        </T>
        <T v="body" muted center>
          Bridging Thoughts to Words
        </T>
        <T v="caption" muted center>
          Think It... We Speak It
        </T>
      </Animated.View>

      <View style={{ position: 'absolute', bottom: 60, left: 0, right: 0, height: 120, overflow: 'hidden' }} pointerEvents="none">
        <Animated.View style={{ width: waveW, transform: [{ translateX: wave.interpolate({ inputRange: [0, 1], outputRange: [0, -width] }) }] }}>
          <Svg width={waveW} height={120} viewBox={`0 0 ${waveW} 120`}>
            <Path
              d={`M0 60 ${Array.from({ length: 8 }, (_, i) => `Q${(i * 2 + 0.5) * (waveW / 16)} ${i % 2 ? 100 : 20} ${(i * 2 + 1) * (waveW / 16)} 60 T${(i * 2 + 2) * (waveW / 16)} 60`).join(' ')}`}
              stroke={c.primary}
              strokeOpacity={0.25}
              strokeWidth={3}
              fill="none"
            />
          </Svg>
        </Animated.View>
      </View>

      <View style={{ position: 'absolute', bottom: 40, width: 90, height: 4, borderRadius: 2, backgroundColor: c.border, overflow: 'hidden' }}>
        <Animated.View style={{ height: 4, borderRadius: 2, backgroundColor: c.primary, width: bar.interpolate({ inputRange: [0, 1], outputRange: ['0%', '100%'] }) }} />
      </View>
    </LinearGradient>
  );
}
