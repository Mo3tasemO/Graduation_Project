import React, { useState } from 'react';
import { View } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { Button, Card, Divider, FadeIn, Icon, Picker, Press, Screen, Toggle, useToast } from '../components/ui';
import { T, useTheme } from '../theme';
import { useApp } from '../store';
import { biometricInfo, biometricPrompt } from '../biometric';
import { auth } from '../services/auth';
import { session } from '../session';
import { Platform } from 'react-native';

function Row({ icon, label, value, right, onPress }: { icon: string; label: string; value?: string; right?: React.ReactNode; onPress?: () => void }) {
  const { c } = useTheme();
  const inner = (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12, paddingVertical: 14, minHeight: 52 }}>
      <Icon name={icon} size={20} color={c.textMuted} />
      <T v="body" style={{ flex: 1 }}>
        {label}
      </T>
      {value ? (
        <T v="caption" muted>
          {value}
        </T>
      ) : null}
      {right ?? (onPress ? <Icon name="chevron-right" size={20} color={c.textMuted} /> : null)}
    </View>
  );
  return onPress ? (
    <Press onPress={onPress} scaleTo={0.98} accessibilityRole="button" accessibilityLabel={label}>
      {inner}
    </Press>
  ) : (
    inner
  );
}

type Sheet = null | 'voice' | 'rate' | 'volume' | 'language';

export default function Settings() {
  const nav = useNavigation<any>();
  const { settings, setSetting, signOut, speak, biometricEmail, setBiometricEmail, profile } = useApp();
  const toast = useToast();
  const [sheet, setSheet] = useState<Sheet>(null);
  const s = settings;
  const toggleBio = async (on: boolean) => {
    if (!on) {
      const t = await session.getDeviceToken(profile.email);
      if (t) auth.disableBiometric(t).catch(() => {});
      await session.removeDeviceToken(profile.email);
      setBiometricEmail('');
      return toast('Quick login turned off', 'info');
    }
    if (Platform.OS === 'web') return toast('Fingerprint / Face ID works in the phone app, not in the web preview', 'info');
    const info = await biometricInfo();
    if (!info.available) return toast('Set up a fingerprint or Face ID in your phone settings first', 'error');
    if (!(await biometricPrompt(`Confirm ${info.label} to enable quick login`))) return;
    try {
      await session.setDeviceToken(profile.email, await auth.enableBiometric());
      setBiometricEmail(profile.email);
      toast(`${info.label} login enabled`, 'success');
    } catch (e) {
      toast((e as Error).message, 'error');
    }
  };
  const rateName = s.speechRate < 0.85 ? 'Slow' : s.speechRate > 1.15 ? 'Fast' : 'Normal';

  return (
    <Screen title="Settings" scroll>
      <FadeIn>
        <Card pad={4} style={{ paddingHorizontal: 16, marginTop: 8 }}>
          <Row icon="fingerprint" label="Fingerprint / Face ID login" right={<Toggle label="Biometric login" value={!!biometricEmail && biometricEmail === profile.email} onChange={toggleBio} />} />
          <Divider />
          <Row icon="weather-night" label="Dark Mode" right={<Toggle label="Dark mode" value={s.darkMode} onChange={(v) => setSetting('darkMode', v)} />} />
          <Divider />
          <Row icon="contrast-circle" label="High Contrast Mode" right={<Toggle label="High contrast" value={s.highContrast} onChange={(v) => setSetting('highContrast', v)} />} />
          <Divider />
          <Row icon="format-size" label="Large Text" right={<Toggle label="Large text" value={s.largeText} onChange={(v) => setSetting('largeText', v)} />} />
        </Card>
      </FadeIn>
      <FadeIn delay={100} style={{ marginTop: 14 }}>
        <Card pad={4} style={{ paddingHorizontal: 16 }}>
          <Row icon="account-voice" label="Voice Profile" value={s.voice} onPress={() => setSheet('voice')} />
          <Divider />
          <Row icon="speedometer" label="Speech Rate" value={rateName} onPress={() => setSheet('rate')} />
          <Divider />
          <Row icon="volume-high" label="Volume" value={`${Math.round(s.volume)}%`} onPress={() => setSheet('volume')} />
          <Divider />
          <Row icon="bell-outline" label="Notifications" right={<Toggle label="Notifications" value={s.notifications} onChange={(v) => setSetting('notifications', v)} />} />
        </Card>
      </FadeIn>
      <FadeIn delay={200} style={{ marginTop: 14 }}>
        <Card pad={4} style={{ paddingHorizontal: 16 }}>
          <Row icon="account-heart-outline" label="Caregiver Settings" onPress={() => nav.navigate('EditProfile', { section: 'caregiver' })} />
          <Divider />
          <Row icon="human" label="Accessibility" onPress={() => nav.navigate('Accessibility')} />
          <Divider />
          <Row icon="translate" label="Language" value={s.language} onPress={() => setSheet('language')} />
        </Card>
      </FadeIn>
      <FadeIn delay={280} style={{ marginTop: 22 }}>
        <Button
          title="Log out"
          variant="ghost"
          icon="logout"
          onPress={() => {
            signOut();
            nav.reset({ index: 0, routes: [{ name: 'Login' }] });
          }}
        />
        <T v="caption" muted center style={{ marginTop: 14 }}>
          MindSpeak v1.0.0
        </T>
      </FadeIn>

      <Picker
        visible={sheet === 'voice'}
        title="Voice Profile"
        value={s.voice}
        options={[
          { label: 'Female', value: 'Female' },
          { label: 'Male', value: 'Male' },
        ]}
        onSelect={(v) => {
          setSetting('voice', v);
          speak('Hello, this is my voice.', { voice: v });
        }}
        onClose={() => setSheet(null)}
      />
      <Picker
        visible={sheet === 'rate'}
        title="Speech Rate"
        value={rateName}
        options={[
          { label: 'Slow', value: 'Slow' },
          { label: 'Normal', value: 'Normal' },
          { label: 'Fast', value: 'Fast' },
        ]}
        onSelect={(v) => setSetting('speechRate', v === 'Slow' ? 0.7 : v === 'Fast' ? 1.3 : 1)}
        onClose={() => setSheet(null)}
      />
      <Picker
        visible={sheet === 'volume'}
        title="Volume"
        value={Math.round(s.volume)}
        options={[30, 50, 70, 100].map((v) => ({ label: `${v}%`, value: v }))}
        onSelect={(v) => setSetting('volume', v)}
        onClose={() => setSheet(null)}
      />
      <Picker
        visible={sheet === 'language'}
        title="Language"
        value={s.language}
        options={[
          { label: 'English', value: 'English' },
          { label: 'العربية (Arabic)', value: 'Arabic', disabled: true, hint: 'Coming soon' },
        ]}
        onSelect={(v) => setSetting('language', v)}
        onClose={() => setSheet(null)}
      />
    </Screen>
  );
}
