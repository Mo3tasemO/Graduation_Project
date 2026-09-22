import React, { useState } from 'react';
import { View } from 'react-native';
import { useNavigation, useRoute } from '@react-navigation/native';
import { Button, FadeIn, Icon, Screen, useToast } from '../components/ui';
import { PasswordField, PasswordRules } from '../components/Field';
import { T, palette, useTheme } from '../theme';
import { AuthError, auth, passwordOk } from '../services/auth';

export default function ResetPassword() {
  const nav = useNavigation<any>();
  const { email, token } = useRoute<any>().params;
  const { c } = useTheme();
  const toast = useToast();
  const [pw, setPw] = useState('');
  const [pw2, setPw2] = useState('');
  const [err, setErr] = useState('');
  const [busy, setBusy] = useState(false);

  const submit = async () => {
    if (!passwordOk(pw)) return setErr('Password does not meet all the rules');
    if (pw !== pw2) return setErr('Passwords do not match');
    setErr('');
    setBusy(true);
    try {
      await auth.resetPassword(email, token, pw);
      toast('Password changed. Please log in.', 'success');
      nav.reset({ index: 0, routes: [{ name: 'Login', params: { email } }] });
    } catch (e) {
      setErr((e as AuthError).message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <Screen title="New password" scroll back={false}>
      <FadeIn style={{ alignItems: 'center', marginTop: 16 }}>
        <View style={{ width: 84, height: 84, borderRadius: 42, backgroundColor: palette.success + '22', alignItems: 'center', justifyContent: 'center' }}>
          <Icon name="shield-check" size={42} color={palette.success} />
        </View>
        <T v="h2" style={{ marginTop: 14 }}>
          Identity confirmed
        </T>
        <T v="body" muted center style={{ marginTop: 4, marginBottom: 24 }}>
          Choose a new password for {email}
        </T>
      </FadeIn>
      <FadeIn delay={100} style={{ gap: 14 }}>
        <View>
          <PasswordField label="New password" placeholder="New password" value={pw} onChangeText={setPw} />
          <PasswordRules password={pw} />
        </View>
        <PasswordField label="Confirm password" placeholder="Repeat the password" value={pw2} onChangeText={setPw2} onSubmitEditing={submit} error={err} />
        <Button title="Change password" onPress={submit} loading={busy} />
      </FadeIn>
    </Screen>
  );
}
