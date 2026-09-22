import React, { useEffect, useRef, useState } from 'react';
import { Animated, Easing, TextInput, View } from 'react-native';
import { useRoute } from '@react-navigation/native';
import { Button, Card, FadeIn, Icon, Picker, Press, PulseRing, Screen, Slider, ND, useToast } from '../components/ui';
import { T, fonts, palette, useTheme } from '../theme';
import { useApp } from '../store';

const rateLabel = (r: number) => (r < 0.85 ? 'Slow' : r > 1.15 ? 'Fast' : 'Normal');

export default function Message() {
  const route = useRoute<any>();
  const { c, scale } = useTheme();
  const { settings, setSetting, speak, stopSpeaking, addHistory } = useApp();
  const toast = useToast();
  const [text, setText] = useState<string>(route.params?.text ?? '');
  const [voice, setVoice] = useState(settings.voice);
  const [rate, setRate] = useState(settings.speechRate);
  const [volume, setVolume] = useState(settings.volume);
  const [pick, setPick] = useState(false);
  const [speaking, setSpeaking] = useState(false);
  const bump = useRef(new Animated.Value(1)).current;

  useEffect(() => {
    return () => stopSpeaking();
  }, []);

  const say = (t: string) => {
    if (!t.trim()) return toast('Type a message first', 'info');
    setSpeaking(true);
    Animated.sequence([
      Animated.timing(bump, { toValue: 1.15, duration: 120, easing: Easing.out(Easing.quad), useNativeDriver: ND }),
      Animated.spring(bump, { toValue: 1, useNativeDriver: ND }),
    ]).start();
    speak(t, { rate, volume, voice, onDone: () => setSpeaking(false) });
    setTimeout(() => setSpeaking(false), 3000);
  };

  const save = () => {
    setSetting('voice', voice);
    setSetting('speechRate', rate);
    setSetting('volume', volume);
    toast('Voice settings saved', 'success');
  };

  return (
    <Screen title="Message" scroll>
      <FadeIn>
        <View style={{ backgroundColor: c.primarySoft, borderRadius: 22, borderBottomLeftRadius: 6, padding: 22, minHeight: 130, justifyContent: 'center', marginTop: 8 }}>
          <TextInput
            value={text}
            onChangeText={setText}
            multiline
            placeholder="Type what you want to say…"
            placeholderTextColor={c.textMuted}
            accessibilityLabel="Message text"
            style={[
              { color: c.primary, fontFamily: fonts.semi, fontSize: 24 * scale, textAlign: 'center', minHeight: 60 },
              { outlineStyle: 'none' } as any,
            ]}
          />
        </View>
      </FadeIn>

      <View style={{ alignItems: 'center', height: 130, justifyContent: 'center' }}>
        {speaking && (
          <>
            <PulseRing size={84} color={c.primary} duration={1200} />
            <PulseRing size={84} color={c.primary} duration={1200} delay={500} />
          </>
        )}
        <Animated.View style={{ transform: [{ scale: bump }] }}>
          <Press onPress={() => say(text)} accessibilityLabel="Speak message" scaleTo={0.9}>
            <View style={{ width: 84, height: 84, borderRadius: 42, backgroundColor: c.primary, alignItems: 'center', justifyContent: 'center', boxShadow: `0 8px 22px ${c.primary}66` }}>
              <Icon name={speaking ? 'volume-high' : 'volume-medium'} size={38} color="#fff" />
            </View>
          </Press>
        </Animated.View>
      </View>

      <FadeIn delay={120}>
        <Card>
          <T v="title" style={{ marginBottom: 10 }}>
            Voice Settings
          </T>
          <Press onPress={() => setPick(true)} scaleTo={0.99} style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingVertical: 8 }}>
            <T v="body" muted>
              Voice
            </T>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6, backgroundColor: c.surfaceAlt, borderRadius: 10, paddingHorizontal: 12, paddingVertical: 6, minWidth: 110, justifyContent: 'space-between' }}>
              <T v="bodyM">{voice}</T>
              <Icon name="chevron-down" size={18} color={c.textMuted} />
            </View>
          </Press>
          <View style={{ paddingVertical: 6 }}>
            <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
              <T v="body" muted>
                Speech Rate
              </T>
              <T v="caption" muted>
                {rateLabel(rate)}
              </T>
            </View>
            <Slider value={rate} min={0.5} max={1.5} onChange={setRate} />
          </View>
          <View style={{ paddingVertical: 6 }}>
            <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
              <T v="body" muted>
                Volume
              </T>
              <T v="caption" muted>
                {Math.round(volume)}%
              </T>
            </View>
            <Slider value={volume} min={0} max={100} onChange={setVolume} />
          </View>
          <View style={{ flexDirection: 'row', gap: 12, marginTop: 10 }}>
            <Button title="Test" variant="secondary" icon="play" onPress={() => say('Hello, this is how I sound.')} style={{ flex: 1 }} />
            <Button title="Save" onPress={save} style={{ flex: 1 }} />
          </View>
        </Card>
      </FadeIn>
      <Button
        title="Speak & save to history"
        variant="ghost"
        icon="history"
        style={{ marginTop: 14 }}
        onPress={() => {
          say(text);
          if (text.trim()) {
            addHistory(text.trim(), 100, 'aac');
            toast('Saved to history', 'success');
          }
        }}
      />
      <Picker
        visible={pick}
        title="Voice"
        value={voice}
        options={[
          { label: 'Female', value: 'Female' },
          { label: 'Male', value: 'Male' },
        ]}
        onSelect={(v) => setVoice(v)}
        onClose={() => setPick(false)}
      />
    </Screen>
  );
}
