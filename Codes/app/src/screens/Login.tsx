import React, { useEffect, useRef, useState } from 'react';
import { Animated, KeyboardAvoidingView, Platform, ScrollView, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useNavigation, useRoute } from '@react-navigation/native';
import { BrainLogo } from '../components/Logo';
import { Button, FadeIn, Icon, Picker, Press, ND, useToast } from '../components/ui';
import { Field, PasswordField } from '../components/Field';
import { T, useTheme } from '../theme';
import { useApp } from '../store';
import { AuthError, LoginResult, auth } from '../services/auth';
import { session } from '../session';
import { biometricInfo, biometricPrompt } from '../biometric';

export default function Login() {
  const nav = useNavigation<any>();
  const route = useRoute<any>();
  const { c } = useTheme();
  const toast = useToast();
  const { signIn, biometricEmail, setBiometricEmail } = useApp();
  const [email, setEmail] = useState<string>(route.params?.email ?? biometricEmail ?? '');
  const [pw, setPw] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState('');
  const [bio, setBio] = useState({ available: false, label: 'Biometrics' });
  const [offer, setOffer] = useState<{ email: string; res: LoginResult } | null>(null);
  const shake = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    biometricInfo().then(setBio);
  }, []);

  useEffect(() => {
    if (route.params?.email) setEmail(route.params.email);
  }, [route.params?.email]);

  const fail = (m: string) => {
    setErr(m);
    Animated.sequence([-10, 10, -8, 8, 0].map((v) => Animated.timing(shake, { toValue: v, duration: 60, useNativeDriver: ND }))).start();
  };

  const enter = (res: LoginResult) => {
    signIn(res.user, res.data);
    nav.reset({ index: 0, routes: [{ name: 'Main' }] });
  };

  const submit = async () => {
    setErr('');
    setBusy(true);
    try {
      const res = await auth.login(email, pw);
      await session.setToken(res.token);
      // first login on a phone that has biometrics: offer quick login for next time
      const mail = email.trim().toLowerCase();
      if (bio.available && biometricEmail.toLowerCase() !== mail) {
        answered.current = false;
        setOffer({ email: mail, res });
      } else enter(res);
    } catch (e) {
      const er = e as AuthError;
      if (er.code === 'UNVERIFIED') nav.navigate('VerifyCode', { mode: 'register', email: email.trim().toLowerCase(), devCode: er.devCode });
      else fail(er.message ?? 'Something went wrong');
    } finally {
      setBusy(false);
    }
  };

  const bioLogin = async () => {
    if (!(await biometricPrompt(`Log in to MindSpeak with ${bio.label}`))) return;
    try {
      const deviceToken = await session.getDeviceToken(biometricEmail);
      if (!deviceToken) throw new AuthError('Quick login expired. Please log in with your password.', 'INVALID');
      const res = await auth.loginBiometric(biometricEmail, deviceToken);
      await session.setToken(res.token);
      enter(res);
    } catch (e) {
      fail((e as AuthError).message);
    }
  };

  const answered = useRef(false);
  const answerOffer = async (yes: boolean) => {
    if (!offer || answered.current) return; // Picker fires onSelect and onClose
    answered.current = true;
    const o = offer;
    setOffer(null);
    if (yes && (await biometricPrompt(`Confirm ${bio.label} to enable quick login`))) {
      try {
        await session.setDeviceToken(o.email, await auth.enableBiometric());
        setBiometricEmail(o.email);
        toast(`${bio.label} login enabled`, 'success');
      } catch (e) {
        toast((e as AuthError).message, 'error');
      }
    }
    enter(o.res);
  };

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.bg }}>
      <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        <ScrollView contentContainerStyle={{ padding: 24, flexGrow: 1, justifyContent: 'center' }} keyboardShouldPersistTaps="handled">
          <FadeIn style={{ alignItems: 'center', marginBottom: 28 }}>
            <BrainLogo size={72} color={c.primary} />
            <T v="h1" color={c.primary} style={{ marginTop: 8 }}>
              MindSpeak
            </T>
          </FadeIn>
          <FadeIn delay={120}>
            <T v="h2" center>
              Welcome back!
            </T>
            <T v="body" muted center style={{ marginBottom: 22 }}>
              Sign in to continue
            </T>
          </FadeIn>
          <Animated.View style={{ gap: 14, transform: [{ translateX: shake }] }}>
            <Field icon="email-outline" placeholder="Gmail address" value={email} onChangeText={setEmail} autoCapitalize="none" autoCorrect={false} keyboardType="email-address" />
            <PasswordField placeholder="Password" value={pw} onChangeText={setPw} onSubmitEditing={submit} />
            {!!err && (
              <FadeIn from={-6} duration={200}>
                <T v="caption" color={c.error}>
                  {err}
                </T>
              </FadeIn>
            )}
            <Press onPress={() => nav.navigate('ForgotPassword')} style={{ alignSelf: 'flex-end' }} accessibilityRole="link">
              <T v="caption" color={c.primary}>
                Forgot password?
              </T>
            </Press>
            <Button title="Login" onPress={submit} loading={busy} />
            {bio.available && !!biometricEmail && (
              <Button title={`Login with ${bio.label}`} variant="secondary" icon={bio.label === 'Face ID' ? 'face-recognition' : 'fingerprint'} onPress={bioLogin} />
            )}
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
              <View style={{ flex: 1, height: 1, backgroundColor: c.border }} />
              <T v="caption" muted>
                or
              </T>
              <View style={{ flex: 1, height: 1, backgroundColor: c.border }} />
            </View>
            <Button title="Create new account" variant="secondary" onPress={() => nav.navigate('Signup')} />
          </Animated.View>
        </ScrollView>
      </KeyboardAvoidingView>
      <Picker
        visible={!!offer}
        title={`Enable ${bio.label} login?`}
        value=""
        options={[
          { label: `Yes, use ${bio.label}`, value: 'yes', hint: 'Log in faster next time without typing your password' },
          { label: 'Not now', value: 'no' },
        ]}
        onSelect={(v) => answerOffer(v === 'yes')}
        onClose={() => answerOffer(false)}
      />
    </SafeAreaView>
  );
}
