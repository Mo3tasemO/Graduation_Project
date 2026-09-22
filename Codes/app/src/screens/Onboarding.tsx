import React, { useEffect, useRef, useState } from 'react';
import { Animated, Easing, FlatList, View, useWindowDimensions } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useNavigation } from '@react-navigation/native';
import { Button, FadeIn, Icon, Press, ND } from '../components/ui';
import { T, palette, useTheme } from '../theme';
import { useApp } from '../store';

const SLIDES = [
  { icon: 'head-snowflake-outline', title: 'Your thoughts\ncan be heard', body: 'MindSpeak uses EEG signals to detect your imagined speech and turns it into text and voice.', color: palette.primary },
  { icon: 'headphones', title: 'Wear the\nMindSpeak headset', body: 'Connect the lightweight headset over Bluetooth. We check signal quality so every word is picked up clearly.', color: palette.secondary },
  { icon: 'account-voice', title: 'Speak with\nconfidence', body: 'Use quick AAC phrases, emergency alerts and your own personalised AI model to say what matters.', color: palette.success },
];

function Illustration({ icon, color }: { icon: string; color: string }) {
  const { c } = useTheme();
  const float = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    const a = Animated.loop(
      Animated.sequence([
        Animated.timing(float, { toValue: 1, duration: 1800, easing: Easing.inOut(Easing.quad), useNativeDriver: ND }),
        Animated.timing(float, { toValue: 0, duration: 1800, easing: Easing.inOut(Easing.quad), useNativeDriver: ND }),
      ]),
    );
    a.start();
    return () => a.stop();
  }, []);
  return (
    <View style={{ width: 240, height: 240, alignItems: 'center', justifyContent: 'center' }}>
      <View style={{ position: 'absolute', width: 240, height: 240, borderRadius: 120, backgroundColor: color + '14' }} />
      <View style={{ position: 'absolute', width: 180, height: 180, borderRadius: 90, backgroundColor: color + '1F' }} />
      <Animated.View
        style={{
          width: 120,
          height: 120,
          borderRadius: 60,
          backgroundColor: c.surface,
          alignItems: 'center',
          justifyContent: 'center',
          boxShadow: `0 10px 30px ${color}44`,
          transform: [{ translateY: float.interpolate({ inputRange: [0, 1], outputRange: [-8, 8] }) }],
        }}
      >
        <Icon name={icon} size={62} color={color} />
      </Animated.View>
    </View>
  );
}

export default function Onboarding() {
  const nav = useNavigation<any>();
  const { finishOnboarding } = useApp();
  const { c } = useTheme();
  const { width } = useWindowDimensions();
  const [i, setI] = useState(0);
  const x = useRef(new Animated.Value(0)).current;
  const list = useRef<FlatList>(null);

  useEffect(() => {
    const id = x.addListener(({ value }) => setI(Math.round(value / width)));
    return () => x.removeListener(id);
  }, [width]);

  const done = () => {
    finishOnboarding();
    nav.replace('Login');
  };
  const next = () => {
    if (i === SLIDES.length - 1) return done();
    list.current?.scrollToIndex({ index: i + 1, animated: true });
  };

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.bg }}>
      <View style={{ height: 48, alignItems: 'flex-end', justifyContent: 'center', paddingHorizontal: 20 }}>
        {i < SLIDES.length - 1 && (
          <Press onPress={done} accessibilityLabel="Skip">
            <T v="bodyM" color={c.textMuted}>
              Skip
            </T>
          </Press>
        )}
      </View>
      <Animated.FlatList
        ref={list as any}
        data={SLIDES}
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        keyExtractor={(s) => s.icon}
        onScroll={Animated.event([{ nativeEvent: { contentOffset: { x } } }], { useNativeDriver: false })}
        getItemLayout={(_, k) => ({ length: width, offset: width * k, index: k })}
        renderItem={({ item, index }) => {
          const scale = x.interpolate({ inputRange: [(index - 1) * width, index * width, (index + 1) * width], outputRange: [0.8, 1, 0.8], extrapolate: 'clamp' });
          const op = x.interpolate({ inputRange: [(index - 1) * width, index * width, (index + 1) * width], outputRange: [0, 1, 0], extrapolate: 'clamp' });
          return (
            <View style={{ width, alignItems: 'center', paddingHorizontal: 32, paddingTop: 16 }}>
              <Animated.View style={{ transform: [{ scale }], opacity: op }}>
                <Illustration icon={item.icon} color={item.color} />
              </Animated.View>
              <Animated.View style={{ opacity: op, marginTop: 36, alignItems: 'center' }}>
                <T v="h1" center style={{ fontSize: 28, lineHeight: 36 }}>
                  {item.title}
                </T>
                <T v="body" muted center style={{ marginTop: 12 }}>
                  {item.body}
                </T>
              </Animated.View>
            </View>
          );
        }}
      />
      <View style={{ paddingHorizontal: 24, paddingBottom: 24, gap: 20 }}>
        <View style={{ flexDirection: 'row', justifyContent: 'center', gap: 8 }}>
          {SLIDES.map((_, k) => {
            const w = x.interpolate({ inputRange: [(k - 1) * width, k * width, (k + 1) * width], outputRange: [8, 24, 8], extrapolate: 'clamp' });
            const o = x.interpolate({ inputRange: [(k - 1) * width, k * width, (k + 1) * width], outputRange: [0.3, 1, 0.3], extrapolate: 'clamp' });
            return <Animated.View key={k} style={{ width: w, height: 8, borderRadius: 4, backgroundColor: c.primary, opacity: o }} />;
          })}
        </View>
        <FadeIn>
          <Button title={i === SLIDES.length - 1 ? 'Get Started' : 'Next'} onPress={next} />
        </FadeIn>
      </View>
    </SafeAreaView>
  );
}
