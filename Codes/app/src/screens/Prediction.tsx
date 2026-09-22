import React, { useEffect, useRef, useState } from 'react';
import { Animated, View } from 'react-native';
import { useNavigation, useRoute } from '@react-navigation/native';
import { Button, Card, FadeIn, Icon, Press, Screen, ND, useToast } from '../components/ui';
import { SoundBars, useCountUp } from '../components/charts';
import { T, palette, useTheme } from '../theme';
import { useApp, haptic } from '../store';
import { Prediction as P } from '../services/api';
import { wordMeta } from '../vocab';

export default function Prediction() {
  const nav = useNavigation<any>();
  const route = useRoute<any>();
  const { c } = useTheme();
  const { speak, addHistory, addNotification } = useApp();
  const toast = useToast();
  const initial: P = route.params.prediction;
  const [pred, setPred] = useState<{ word: string; confidence: number }>(initial);
  const [playing, setPlaying] = useState(false);
  const pop = useRef(new Animated.Value(0)).current;
  const conf = useCountUp(pred.confidence);
  const meta = wordMeta(pred.word);

  useEffect(() => {
    haptic('success');
  }, []);
  useEffect(() => {
    pop.setValue(0);
    Animated.spring(pop, { toValue: 1, speed: 8, bounciness: 14, useNativeDriver: ND }).start();
  }, [pred.word]);

  const play = () => {
    setPlaying(true);
    speak(meta.say ?? pred.word, { onDone: () => setPlaying(false) });
    setTimeout(() => setPlaying(false), 2500);
  };

  const save = () => {
    addHistory(pred.word, pred.confidence, 'eeg');
    addNotification({ type: 'message', title: 'New Message', body: `"${pred.word}" was saved to your history.` });
    toast('Saved to history', 'success');
    nav.navigate('Main', { screen: 'History' });
  };

  const confColor = pred.confidence >= 85 ? palette.success : pred.confidence >= 70 ? palette.warning : palette.error;

  return (
    <Screen title="Prediction" scroll>
      <FadeIn>
        <Card style={{ alignItems: 'center', paddingVertical: 26, marginTop: 8 }}>
          <View style={{ width: 96, height: 96, borderRadius: 48, backgroundColor: meta.color + '20', alignItems: 'center', justifyContent: 'center' }}>
            <Icon name={meta.icon} size={48} color={meta.color} />
          </View>
          <T v="caption" muted style={{ marginTop: 16 }}>
            Detected Word
          </T>
          <Animated.View style={{ transform: [{ scale: pop.interpolate({ inputRange: [0, 1], outputRange: [0.6, 1] }) }], opacity: pop }}>
            <T v="display" style={{ fontSize: 40, lineHeight: 52 }}>
              {pred.word.toUpperCase()}
            </T>
          </Animated.View>
          <T v="title" color={confColor}>
            Confidence: {conf}%
          </T>
          <View style={{ alignSelf: 'stretch', marginTop: 18, paddingHorizontal: 8 }}>
            <SoundBars active={playing} color={c.secondary} />
          </View>
        </Card>
      </FadeIn>

      <FadeIn delay={150} style={{ marginTop: 18 }}>
        <T v="bodyM" muted style={{ marginBottom: 8 }}>
          Not right? Other possibilities
        </T>
        <View style={{ flexDirection: 'row', gap: 10, flexWrap: 'wrap' }}>
          {initial.alternatives.map((a) => (
            <Press key={a.word} onPress={() => setPred({ word: a.word, confidence: Math.max(a.confidence, 50) })} scaleTo={0.94}>
              <View style={{ flexDirection: 'row', gap: 6, alignItems: 'center', paddingHorizontal: 14, paddingVertical: 8, borderRadius: 20, borderWidth: 1.5, borderColor: c.border, backgroundColor: c.surface }}>
                <T v="bodyM">{a.word}</T>
                <T v="caption" muted>
                  {a.confidence}%
                </T>
              </View>
            </Press>
          ))}
          {pred.word !== initial.word && (
            <Press onPress={() => setPred({ word: initial.word, confidence: initial.confidence })} scaleTo={0.94}>
              <View style={{ paddingHorizontal: 14, paddingVertical: 8, borderRadius: 20, backgroundColor: c.primarySoft }}>
                <T v="bodyM" color={c.primary}>
                  Reset
                </T>
              </View>
            </Press>
          )}
        </View>
      </FadeIn>

      <FadeIn delay={250} style={{ flexDirection: 'row', gap: 12, marginTop: 24 }}>
        <Button title="Play Audio" icon="play" onPress={play} style={{ flex: 1 }} />
        <Button title="Save" variant="secondary" icon="content-save-outline" onPress={save} style={{ flex: 1 }} />
      </FadeIn>
      <Button title="Try again" variant="ghost" icon="refresh" onPress={() => nav.replace('Decoding')} style={{ marginTop: 12 }} />
    </Screen>
  );
}
