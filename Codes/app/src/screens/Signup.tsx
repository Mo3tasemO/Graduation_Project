import React, { useState } from 'react';
import { KeyboardAvoidingView, Platform, View } from 'react-native';
import * as ImagePicker from 'expo-image-picker';
import { useNavigation } from '@react-navigation/native';
import { Button, FadeIn, Icon, Press, Screen, useToast } from '../components/ui';
import { Avatar, Field, PasswordField, PasswordRules } from '../components/Field';
import { T, useTheme } from '../theme';
import { AuthError, auth, isGmail, parseBirthDate, passwordOk, phoneOk } from '../services/auth';

/** Auto-inserts slashes: 12052001 -> 12/05/2001 */
const maskDate = (s: string) => {
  const d = s.replace(/\D/g, '').slice(0, 8);
  return [d.slice(0, 2), d.slice(2, 4), d.slice(4)].filter(Boolean).join('/');
};

export default function Signup() {
  const nav = useNavigation<any>();
  const { c } = useTheme();
  const toast = useToast();
  const [username, setUsername] = useState('');
  const [email, setEmail] = useState('');
  const [pw, setPw] = useState('');
  const [birth, setBirth] = useState('');
  const [phone, setPhone] = useState('');
  const [photo, setPhoto] = useState('');
  const [errs, setErrs] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState(false);

  const pick = async () => {
    try {
      const r = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ['images'], allowsEditing: true, aspect: [1, 1], quality: 0.4, base64: true });
      if (!r.canceled) {
        const a = r.assets[0];
        setPhoto(a.base64 ? `data:image/jpeg;base64,${a.base64}` : a.uri); // sent to the server, so keep the data itself
      }
    } catch {
      toast('Could not open your photos', 'error');
    }
  };

  const validate = () => {
    const e: Record<string, string> = {};
    if (!/^[A-Za-z0-9_.]{3,20}$/.test(username.trim())) e.username = '3-20 characters: letters, numbers, . or _';
    if (!isGmail(email)) e.email = 'Use a Gmail address (name@gmail.com)';
    if (!passwordOk(pw)) e.pw = 'Password does not meet all the rules below';
    if (!parseBirthDate(birth)) e.birth = 'Enter a valid date as DD/MM/YYYY';
    if (!phoneOk(phone)) e.phone = 'Phone number must have at least 11 digits';
    setErrs(e);
    return Object.keys(e).length === 0;
  };

  const submit = async () => {
    if (!validate()) return;
    setBusy(true);
    try {
      const r = await auth.register({ username, email, password: pw, birthDate: birth, phone, photo: photo || undefined });
      nav.navigate('VerifyCode', { mode: 'register', email: r.email, devCode: r.devCode });
    } catch (e) {
      const err = e as AuthError;
      const key = err.code === 'EXISTS' || err.code === 'BAD_EMAIL' ? 'email' : err.code === 'USERNAME_TAKEN' || err.code === 'BAD_USERNAME' ? 'username' : '';
      if (key) setErrs({ [key]: err.message });
      else toast(err.message, 'error');
    } finally {
      setBusy(false);
    }
  };

  return (
    <Screen title="Create account" scroll>
      <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        <FadeIn style={{ alignItems: 'center', marginVertical: 12 }}>
          <Press onPress={pick} accessibilityLabel="Choose profile photo (optional)">
            <View>
              <Avatar photo={photo} name="?" size={96} />
              {!photo && (
                <View style={{ position: 'absolute', inset: 0, alignItems: 'center', justifyContent: 'center' } as any}>
                  <Icon name="account" size={44} color={c.primary} />
                </View>
              )}
              <View style={{ position: 'absolute', right: -2, bottom: -2, width: 32, height: 32, borderRadius: 16, backgroundColor: c.primary, alignItems: 'center', justifyContent: 'center', borderWidth: 3, borderColor: c.bg }}>
                <Icon name="camera" size={16} color="#fff" />
              </View>
            </View>
          </Press>
          <T v="caption" muted style={{ marginTop: 8 }}>
            Profile photo (optional)
          </T>
        </FadeIn>

        <FadeIn delay={100} style={{ gap: 14 }}>
          <Field label="Username" icon="account-outline" placeholder="e.g. sara_ahmed" value={username} onChangeText={setUsername} autoCapitalize="none" autoCorrect={false} maxLength={20} error={errs.username} />
          <Field label="Email" icon="email-outline" placeholder="name@gmail.com" value={email} onChangeText={setEmail} autoCapitalize="none" autoCorrect={false} keyboardType="email-address" error={errs.email} />
          <View>
            <PasswordField label="Password" placeholder="Create a password" value={pw} onChangeText={setPw} error={errs.pw} />
            <PasswordRules password={pw} />
          </View>
          <Field
            label="Birth date"
            icon="calendar-outline"
            placeholder="DD/MM/YYYY"
            value={birth}
            onChangeText={(t) => setBirth(maskDate(t))}
            keyboardType="number-pad"
            maxLength={10}
            error={errs.birth}
          />
          <Field label="Phone number" icon="phone-outline" placeholder="01012345678" value={phone} onChangeText={(t) => setPhone(t.replace(/[^\d+]/g, ''))} keyboardType="phone-pad" maxLength={16} error={errs.phone} />
          <Button title="Create account" onPress={submit} loading={busy} style={{ marginTop: 6 }} />
          <Press onPress={() => nav.goBack()} style={{ alignSelf: 'center', padding: 8 }}>
            <T v="body" muted>
              Already have an account?{' '}
              <T v="bodyM" color={c.primary}>
                Log in
              </T>
            </T>
          </Press>
        </FadeIn>
      </KeyboardAvoidingView>
    </Screen>
  );
}
