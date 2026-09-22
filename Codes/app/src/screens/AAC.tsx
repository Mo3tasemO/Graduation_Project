import React, { useRef, useState } from 'react';
import { Animated, ScrollView, View } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { FadeIn, Icon, IconButton, Press, Screen, ND, useToast } from '../components/ui';
import { T, useTheme } from '../theme';
import { useApp } from '../store';
import { CATEGORIES, Word } from '../vocab';

function Tile({ w, onPress, index, cat }: { w: Word; onPress: () => void; index: number; cat: string }) {
  const { isDark, hc, c } = useTheme();
  return (
    <FadeIn key={cat + w.label} delay={index * 45} from={14} duration={320} style={{ width: '31.5%' }}>
      <Press onPress={onPress} accessibilityLabel={w.label} scaleTo={0.9}>
        <View
          style={{
            aspectRatio: 1,
            borderRadius: 18,
            backgroundColor: w.color + (isDark ? '2E' : '18'),
            borderWidth: hc ? 2 : 1,
            borderColor: hc ? c.border : w.color + '33',
            alignItems: 'center',
            justifyContent: 'center',
            gap: 8,
          }}
        >
          <Icon name={w.icon} size={34} color={w.color} />
          <T v="caption" color={hc ? c.text : w.color} weight="semi">
            {w.label}
          </T>
        </View>
      </Press>
    </FadeIn>
  );
}

export default function AAC() {
  const nav = useNavigation<any>();
  const { c } = useTheme();
  const { speak, addHistory } = useApp();
  const toast = useToast();
  const [cat, setCat] = useState('Medical');

  const tap = (w: Word) => {
    if (w.label === 'Help') return nav.navigate('Emergency');
    speak(w.say ?? w.label);
    addHistory(w.say ?? w.label, 100, 'aac');
    toast(`Speaking: "${w.say ?? w.label}"`, 'success');
  };

  return (
    <Screen title="AAC" back={false} right={<IconButton name="keyboard-outline" label="Type a message" onPress={() => nav.navigate('Message', { text: '' })} />}>
      <View>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 10, paddingVertical: 6 }}>
          {Object.keys(CATEGORIES).map((k) => {
            const on = k === cat;
            return (
              <Press key={k} onPress={() => setCat(k)} scaleTo={0.94} accessibilityRole="tab" accessibilityState={{ selected: on }}>
                <View
                  style={{
                    paddingHorizontal: 18,
                    paddingVertical: 9,
                    borderRadius: 20,
                    backgroundColor: on ? c.primary : c.surface,
                    borderWidth: 1.5,
                    borderColor: on ? c.primary : c.border,
                  }}
                >
                  <T v="bodyM" color={on ? '#fff' : c.textMuted}>
                    {k}
                  </T>
                </View>
              </Press>
            );
          })}
        </ScrollView>
      </View>
      <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={{ paddingTop: 14, paddingBottom: 24 }}>
        <View style={{ flexDirection: 'row', flexWrap: 'wrap', justifyContent: 'space-between', rowGap: 12 }}>
          {CATEGORIES[cat].map((w, i) => (
            <Tile key={cat + w.label} w={w} index={i} cat={cat} onPress={() => tap(w)} />
          ))}
        </View>
        <T v="caption" muted center style={{ marginTop: 20 }}>
          Tap a tile to speak it aloud
        </T>
      </ScrollView>
    </Screen>
  );
}
