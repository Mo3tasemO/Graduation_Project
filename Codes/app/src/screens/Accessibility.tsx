import React from 'react';
import { View } from 'react-native';
import { Card, FadeIn, Icon, Screen, Toggle } from '../components/ui';
import { T, palette, useTheme } from '../theme';
import { useApp } from '../store';

const FEATURES = [
  { icon: 'gesture-tap', label: 'Large Touch Targets', body: 'Every button is at least 44 × 44 pt so it is easy to hit.', color: palette.primary },
  { icon: 'contrast-circle', label: 'High Contrast', body: 'Stronger borders and text colors for low-vision users.', color: palette.secondary, key: 'highContrast' as const },
  { icon: 'format-size', label: 'Large Text', body: 'Scale all text by 20%.', color: palette.success, key: 'largeText' as const },
  { icon: 'account-voice', label: 'Voice Support', body: 'Every phrase can be spoken aloud with your chosen voice.', color: palette.purple },
  { icon: 'cellphone-text', label: 'Screen Reader Friendly', body: 'All controls have labels for TalkBack and VoiceOver.', color: palette.warning },
];

export default function Accessibility() {
  const { settings, setSetting } = useApp();
  return (
    <Screen title="Accessibility" scroll>
      <View style={{ gap: 12, marginTop: 8 }}>
        {FEATURES.map((f, i) => (
          <FadeIn key={f.label} delay={i * 70}>
            <Card pad={14}>
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
                <View style={{ width: 44, height: 44, borderRadius: 22, backgroundColor: f.color + '22', alignItems: 'center', justifyContent: 'center' }}>
                  <Icon name={f.icon} color={f.color} />
                </View>
                <View style={{ flex: 1 }}>
                  <T v="bodyM">{f.label}</T>
                  <T v="caption" muted>
                    {f.body}
                  </T>
                </View>
                {f.key && <Toggle label={f.label} value={settings[f.key]} onChange={(v) => setSetting(f.key!, v)} />}
              </View>
            </Card>
          </FadeIn>
        ))}
      </View>
    </Screen>
  );
}
