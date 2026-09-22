import React, { useMemo, useRef, useState } from 'react';
import { Animated, Alert, Platform, ScrollView, View } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { Card, FadeIn, Icon, IconButton, Press, Screen, ProgressBar } from '../components/ui';
import { useCountUp } from '../components/charts';
import { T, palette, useTheme } from '../theme';
import { HistoryItem, useApp } from '../store';
import { wordMeta } from '../vocab';
import { clock, dayLabel } from '../utils';

function Row({ item, index }: { item: HistoryItem; index: number }) {
  const nav = useNavigation<any>();
  const { c } = useTheme();
  const m = wordMeta(item.text);
  return (
    <FadeIn delay={index * 50} from={12} duration={320}>
      <Press onPress={() => nav.navigate('Message', { text: item.text })} scaleTo={0.98}>
        <Card pad={12} style={{ marginBottom: 10 }}>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
            <View style={{ width: 42, height: 42, borderRadius: 21, backgroundColor: m.color + '22', alignItems: 'center', justifyContent: 'center' }}>
              <Icon name={m.icon} size={22} color={m.color} />
            </View>
            <View style={{ flex: 1 }}>
              <T v="bodyM">{item.text}</T>
              <T v="caption" muted>
                {clock(item.time)} · {item.source === 'eeg' ? 'Thought' : 'AAC'}
              </T>
            </View>
            <T v="caption" muted>
              {item.confidence}%
            </T>
            <Icon name="chevron-right" size={20} color={c.textMuted} />
          </View>
        </Card>
      </Press>
    </FadeIn>
  );
}

function Stats({ history }: { history: HistoryItem[] }) {
  const { c } = useTheme();
  const eeg = history.filter((h) => h.source === 'eeg');
  const avg = eeg.length ? Math.round(eeg.reduce((a, h) => a + h.confidence, 0) / eeg.length) : 0;
  const total = useCountUp(history.length);
  const avgC = useCountUp(avg);
  const top = useMemo(() => {
    const m: Record<string, number> = {};
    history.forEach((h) => (m[h.text] = (m[h.text] ?? 0) + 1));
    return Object.entries(m)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5);
  }, [history]);
  const max = top[0]?.[1] ?? 1;
  return (
    <View style={{ gap: 14 }}>
      <View style={{ flexDirection: 'row', gap: 12 }}>
        {[
          { label: 'Messages', value: `${total}`, icon: 'message-text-outline', color: c.primary },
          { label: 'Avg. confidence', value: `${avgC}%`, icon: 'target', color: palette.success },
          { label: 'From thoughts', value: `${eeg.length}`, icon: 'brain', color: palette.secondary },
        ].map((s, i) => (
          <FadeIn key={s.label} delay={i * 80} style={{ flex: 1 }}>
            <Card pad={12} style={{ alignItems: 'center', gap: 4 }}>
              <Icon name={s.icon} color={s.color} />
              <T v="h2">{s.value}</T>
              <T v="caption" muted center style={{ fontSize: 10, lineHeight: 14 }}>
                {s.label}
              </T>
            </Card>
          </FadeIn>
        ))}
      </View>
      <FadeIn delay={250}>
        <Card>
          <T v="title" style={{ marginBottom: 12 }}>
            Most used words
          </T>
          {top.length === 0 && (
            <T v="body" muted>
              Nothing yet.
            </T>
          )}
          {top.map(([w, n]) => (
            <View key={w} style={{ marginBottom: 12 }}>
              <View style={{ flexDirection: 'row', justifyContent: 'space-between', marginBottom: 4 }}>
                <T v="bodyM">{w}</T>
                <T v="caption" muted>
                  {n}×
                </T>
              </View>
              <ProgressBar value={(n / max) * 100} color={wordMeta(w).color} />
            </View>
          ))}
        </Card>
      </FadeIn>
    </View>
  );
}

export default function History() {
  const { c } = useTheme();
  const { history, clearHistory } = useApp();
  const [tab, setTab] = useState<'Messages' | 'Statistics'>('Messages');
  const [w, setW] = useState(0);
  const x = useRef(new Animated.Value(0)).current;

  const select = (t: 'Messages' | 'Statistics') => {
    setTab(t);
    Animated.spring(x, { toValue: t === 'Messages' ? 0 : 1, speed: 18, bounciness: 6, useNativeDriver: Platform.OS !== 'web' }).start();
  };

  const groups = useMemo(() => {
    const g: { label: string; items: HistoryItem[] }[] = [];
    history.forEach((h) => {
      const l = dayLabel(h.time);
      const last = g[g.length - 1];
      if (last && last.label === l) last.items.push(h);
      else g.push({ label: l, items: [h] });
    });
    return g;
  }, [history]);

  const confirmClear = () => {
    if (Platform.OS === 'web') return clearHistory();
    Alert.alert('Clear history', 'Delete all saved messages?', [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Delete', style: 'destructive', onPress: clearHistory },
    ]);
  };

  let idx = 0;
  return (
    <Screen title="History" back={false} right={<IconButton name="delete-outline" label="Clear history" onPress={confirmClear} />}>
      <View onLayout={(e) => setW(e.nativeEvent.layout.width)} style={{ flexDirection: 'row', backgroundColor: c.surfaceAlt, borderRadius: 14, padding: 4, marginBottom: 14 }}>
        <Animated.View
          style={{
            position: 'absolute',
            top: 4,
            left: 4,
            width: (w - 8) / 2,
            bottom: 4,
            borderRadius: 11,
            backgroundColor: c.surface,
            boxShadow: `0 2px 8px ${c.shadow}`,
            transform: [{ translateX: x.interpolate({ inputRange: [0, 1], outputRange: [0, (w - 8) / 2] }) }],
          }}
        />
        {(['Messages', 'Statistics'] as const).map((t) => (
          <Press key={t} onPress={() => select(t)} style={{ flex: 1, alignItems: 'center', paddingVertical: 9 }} scaleTo={0.97} accessibilityRole="tab">
            <T v="bodyM" color={tab === t ? c.primary : c.textMuted}>
              {t}
            </T>
          </Press>
        ))}
      </View>

      <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={{ paddingBottom: 24 }}>
        {tab === 'Statistics' ? (
          <Stats history={history} />
        ) : history.length === 0 ? (
          <View style={{ alignItems: 'center', marginTop: 60, gap: 8 }}>
            <Icon name="message-text-clock-outline" size={56} color={c.textMuted} />
            <T v="title">No messages yet</T>
            <T v="body" muted center>
              Words you speak or decode will appear here.
            </T>
          </View>
        ) : (
          groups.map((g) => (
            <View key={g.label}>
              <T v="bodyM" muted style={{ marginBottom: 8, marginTop: 4 }}>
                {g.label}
              </T>
              {g.items.map((it) => (
                <Row key={it.id} item={it} index={idx++} />
              ))}
            </View>
          ))
        )}
      </ScrollView>
    </Screen>
  );
}
