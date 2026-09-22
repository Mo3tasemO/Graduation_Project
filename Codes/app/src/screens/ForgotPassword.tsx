import React, { useState } from 'react';
import { View } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { Button, FadeIn, Icon, Screen } from '../components/ui';
import { Field } from '../components/Field';
import { T, useTheme } from '../theme';
import { AuthError, auth, isGmail } from '../services/auth';

export default function ForgotPassword() {
  const nav = useNavigation<any>();
  const { c } = useTheme();
  const [email, setEmail] = useState('');
  const [err, setErr] = useState('');
  const [busy, setBusy] = useState(false);

  const send = async () => {
    if (!isGmail(email)) return setErr('Use your Gmail address (name@gmail.com)');
    setErr('');
    setBusy(true);
    try {
      const r = await auth.requestPasswordReset(email);
      nav.navigate('VerifyCode', { mode: 'reset', email: r.email, devCode: (r as any).devCode });
    } catch (e) {
      setErr((e as AuthError).message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <Screen title="Forgot password" scroll>
      <FadeIn style={{ alignItems: 'center', marginTop: 16 }}>
        <View style={{ width: 84, height: 84, borderRadius: 42, backgroundColor: c.primarySoft, alignItems: 'center', justifyContent: 'center' }}>
          <Icon name="lock-reset" size={42} color={c.primary} />
        </View>
        <T v="h2" style={{ marginTop: 14 }}>
          Reset your password
        </T>
        <T v="body" muted center style={{ marginTop: 4, marginBottom: 24 }}>
          Enter your Gmail address. We'll email you a code to confirm it's really you.
        </T>
      </FadeIn>
      <FadeIn delay={100} style={{ gap: 16 }}>
        <Field icon="email-outline" placeholder="name@gmail.com" value={email} onChangeText={setEmail} autoCapitalize="none" autoCorrect={false} keyboardType="email-address" error={err} onSubmitEditing={send} />
        <Button title="Send code" onPress={send} loading={busy} />
      </FadeIn>
    </Screen>
  );
}
