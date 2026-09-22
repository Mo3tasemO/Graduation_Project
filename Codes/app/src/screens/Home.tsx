import React, { useEffect, useRef } from 'react';
import { Animated, Easing, ScrollView, View } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { useNavigation } from '@react-navigation/native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Badge, Card, FadeIn, Icon, IconButton, Press, ND, useToast } from '../components/ui';
import { T, palette, useTheme } from '../theme';
import { useApp } from '../store';
import { Avatar } from '../components/Field';
import { QUICK, wordMeta } from '../vocab';
import { clock } from '../utils';

export default function Home() {
  const nav = useNavigation<any>();
  const { c, isDark } = useTheme();
  const { profile, connection, history, speak, unread, addHistory } = useApp();
  const toast = useToast();
  const glow = useRef(new Animated.Value(0)).current;
  const connected = connection.status === 'connected';
  const last = history[0];

  useEffect(() => {
    const a = Animated.loop(
      Animated.sequence([
        Animated.timing(glow, { toValue: 1, duration: 1600, easing: Easing.inOut(Easing.quad), useNativeDriver: ND }),
        Animated.timing(glow, { toValue: 0, duration: 1600, easing: Easing.inOut(Easing.quad), useNativeDriver: ND }),
      ]),
    );
    a.start();
    return () => a.stop();
  }, []);

  const start = () => {
    if (!connected) nav.navigate('ConnectHeadset', { next: 'communicate' });
    else nav.navigate('Main', { screen: 'Communicate', params: { autoStart: Date.now() } });
  };

  const quick = (label: string) => {
    if (label === 'Help') return nav.navigate('Emergency');
    speak(label);
    addHistory(label, 100, 'aac');
    toast(`Speaking: "${label}"`, 'success');
  };

  const first = profile.name || 'there'; // the username chosen at sign-up
  const meta = last ? wordMeta(last.text) : null;

  return (
    <SafeAreaView edges={['top']} style={{ flex: 1, backgroundColor: c.bg }}>
      <ScrollView contentContainerStyle={{ padding: 20, paddingBottom: 30, gap: 18 }} showsVerticalScrollIndicator={false}>
        <FadeIn style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
          <Press onPress={() => nav.navigate('Main', { screen: 'Profile' })} accessibilityLabel="Profile">
            <Avatar photo={profile.photo} name={profile.name} size={48} />
          </Press>
          <View style={{ flex: 1 }}>
            <T v="h2">Hello, {first}</T>
            <T v="caption" muted>
              Ready to communicate?
            </T>
          </View>
          <IconButton name="bell-outline" badge={unread} onPress={() => nav.navigate('Notifications')} label="Notifications" />
        </FadeIn>

        <FadeIn delay={80}>
          <Press onPress={() => nav.navigate('ConnectHeadset')} scaleTo={0.98} accessibilityLabel="Headset status">
            <Card>
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
                <View style={{ width: 44, height: 44, borderRadius: 22, backgroundColor: c.primarySoft, alignItems: 'center', justifyContent: 'center' }}>
                  <Icon name="headphones" size={24} color={c.primary} />
                </View>
                <View style={{ flex: 1, gap: 2 }}>
                  <T v="bodyM">{connected ? connection.device?.name ?? 'MindSpeak Headset' : 'MindSpeak Headset'}</T>
                  {connected ? <Badge text="Connected" color={palette.success} /> : <Badge text="Not connected" color={palette.warning} />}
                </View>
                <Icon name="chevron-right" color={c.textMuted} />
              </View>
              <View style={{ flexDirection: 'row', marginTop: 14, gap: 12 }}>
                <View style={{ flex: 1, flexDirection: 'row', alignItems: 'center', gap: 8, backgroundColor: c.surfaceAlt, borderRadius: 12, padding: 10 }}>
                  <Icon name="signal-cellular-3" size={20} color={connected ? palette.success : c.textMuted} />
                  <View>
                    <T v="caption" muted style={{ lineHeight: 16 }}>
                      Signal Quality
                    </T>
                    <T v="bodyM" color={connected ? palette.success : c.textMuted} style={{ lineHeight: 20 }}>
                      {connected ? connection.signal : '--'}
                    </T>
                  </View>
                </View>
                <View style={{ flex: 1, flexDirection: 'row', alignItems: 'center', gap: 8, backgroundColor: c.surfaceAlt, borderRadius: 12, padding: 10 }}>
                  <Icon name="battery-80" size={20} color={connected ? palette.success : c.textMuted} />
                  <View>
                    <T v="caption" muted style={{ lineHeight: 16 }}>
                      Battery
                    </T>
                    <T v="bodyM" color={connected ? palette.success : c.textMuted} style={{ lineHeight: 20 }}>
                      {connected ? `${connection.battery}%` : '--'}
                    </T>
                  </View>
                </View>
              </View>
            </Card>
          </Press>
        </FadeIn>

        <FadeIn delay={160}>
          <Press onPress={start} scaleTo={0.97} accessibilityLabel="Start communication">
            <LinearGradient
              colors={[palette.primary, isDark ? '#1E40AF' : '#1D4ED8']}
              start={{ x: 0, y: 0 }}
              end={{ x: 1, y: 1 }}
              style={{ borderRadius: 20, padding: 20, flexDirection: 'row', alignItems: 'center', gap: 14, overflow: 'hidden', boxShadow: '0 10px 24px rgba(37,99,235,0.35)' }}
            >
              <Animated.View
                style={{
                  position: 'absolute',
                  right: -30,
                  top: -30,
                  width: 130,
                  height: 130,
                  borderRadius: 65,
                  backgroundColor: 'rgba(255,255,255,0.12)',
                  transform: [{ scale: glow.interpolate({ inputRange: [0, 1], outputRange: [1, 1.25] }) }],
                }}
              />
              <View style={{ width: 52, height: 52, borderRadius: 26, backgroundColor: 'rgba(255,255,255,0.2)', alignItems: 'center', justifyContent: 'center' }}>
                <Icon name="brain" size={30} color="#fff" />
              </View>
              <View style={{ flex: 1 }}>
                <T v="title" color="#fff" size={16}>
                  Start Communication
                </T>
                <T v="caption" color="rgba(255,255,255,0.85)">
                  Use your imagined speech
                </T>
              </View>
              <Icon name="arrow-right" color="#fff" />
            </LinearGradient>
          </Press>
        </FadeIn>

        <FadeIn delay={240}>
          <T v="bodyM" muted style={{ marginBottom: 10 }}>
            Quick Communication
          </T>
          <View style={{ flexDirection: 'row', gap: 12 }}>
            {QUICK.map((w) => (
              <Press key={w.label} onPress={() => quick(w.label)} style={{ flex: 1 }} accessibilityLabel={w.label}>
                <View
                  style={{
                    backgroundColor: w.color + (isDark ? '2E' : '1A'),
                    borderRadius: 18,
                    paddingVertical: 18,
                    alignItems: 'center',
                    gap: 6,
                    borderWidth: 1,
                    borderColor: w.color + '44',
                  }}
                >
                  <Icon name={w.icon} size={30} color={w.color} />
                  <T v="bodyM" color={w.color} weight="semi">
                    {w.label.toUpperCase()}
                  </T>
                </View>
              </Press>
            ))}
          </View>
        </FadeIn>

        {last && meta && (
          <FadeIn delay={320}>
            <Card>
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
                <View style={{ width: 44, height: 44, borderRadius: 22, backgroundColor: meta.color + '22', alignItems: 'center', justifyContent: 'center' }}>
                  <Icon name={meta.icon} color={meta.color} />
                </View>
                <View style={{ flex: 1 }}>
                  <T v="caption" muted>
                    Last Message
                  </T>
                  <T v="title">"{last.text}"</T>
                  <T v="caption" muted>
                    {clock(last.time)}
                  </T>
                </View>
                <IconButton name="volume-high" onPress={() => speak(last.text)} label="Play last message" />
              </View>
            </Card>
          </FadeIn>
        )}
      </ScrollView>
    </SafeAreaView>
  );
}
