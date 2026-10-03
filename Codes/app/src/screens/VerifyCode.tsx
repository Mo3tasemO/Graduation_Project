import React, { useEffect, useRef, useState } from 'react';
import { Animated, TextInput, View } from 'react-native';
import { useNavigation, useRoute } from '@react-navigation/native';
import { Button, FadeIn, Icon, Press, Screen, ND, useToast } from '../components/ui';
import { DevCodeBanner } from '../components/Field';
import { T, useTheme } from '../theme';
import { AuthError, auth } from '../services/auth';

export default function VerifyCode() {
  const nav = useNavigation<any>();
  const { params } = useRoute<any>();
  const { mode, email } = params as { mode: 'register' | 'reset'; email: string };
  const { c, scale } = useTheme();
  const toast = useToast();
  const [code, setCode] = useState('');
  const [devCode, setDevCode] = useState<string | undefined>(params.devCode);
  const [err, setErr] = useState('');
  const [accountExpired, setAccountExpired] = useState(false);
  const [busy, setBusy] = useState(false);
  const [resending, setResending] = useState(false);
  const inFlight = useRef(false);
  const [wait, setWait] = useState(30);
  const input = useRef<TextInput>(null);
  const shake = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    if (wait <= 0) return;
    const t = setTimeout(() => setWait(wait - 1), 1000);
    return () => clearTimeout(t);
  }, [wait]);

  const verify = async (value = code) => {
    if (inFlight.current || accountExpired) return;
    if (value.length !== 6) return setErr('Enter the 6-digit code');
    inFlight.current = true;
    setBusy(true);
    setErr('');
    try {
      if (mode === 'register') {
        const verified = await auth.verifyEmail(email, value);
        toast('Email verified! You can log in now.', 'success');
        nav.reset({ index: 0, routes: [{ name: 'Login', params: { email, role: verified.role } }] });
      } else {
        const token = await auth.verifyResetCode(email, value);
        nav.replace('ResetPassword', { email, token });
      }
    } catch (e) {
      setErr((e as AuthError).message);
      setAccountExpired((e as AuthError).code === 'ACCOUNT_EXPIRED');
      setCode('');
      Animated.sequence([-10, 10, -8, 8, 0].map((v) => Animated.timing(shake, { toValue: v, duration: 60, useNativeDriver: ND }))).start();
    } finally {
      inFlight.current = false;
      setBusy(false);
    }
  };

  const resend = async () => {
    if (inFlight.current || wait > 0 || accountExpired) return;
    inFlight.current = true;
    setResending(true);
    try {
      const r = await auth.resendCode(mode, email);
      setDevCode(r.devCode);
      setCode('');
      setWait(30);
      setErr('');
      toast(r.devCode ? 'A new test code is ready' : 'If your account is eligible, a new code was emailed. Check your spam folder too.', 'success');
    } catch (error) {
      setErr((error as AuthError).message);
      setAccountExpired((error as AuthError).code === 'ACCOUNT_EXPIRED');
    } finally {
      inFlight.current = false;
      setResending(false);
    }
  };

  return (
    <Screen title={mode === 'register' ? 'Verify your email' : 'Enter reset code'} scroll>
      <FadeIn style={{ alignItems: 'center', marginTop: 16 }}>
        <View style={{ width: 84, height: 84, borderRadius: 42, backgroundColor: c.primarySoft, alignItems: 'center', justifyContent: 'center' }}>
          <Icon name="email-fast-outline" size={42} color={c.primary} />
        </View>
        <T v="h2" style={{ marginTop: 14 }}>
          {devCode ? 'Test verification code' : 'Check your email'}
        </T>
        <T v="body" muted center style={{ marginTop: 4 }}>
          {devCode ? 'Use the test code below for' : mode === 'reset' ? 'If this email has a verified account, a 6-digit code was sent to' : 'Enter the 6-digit code emailed to'}
        </T>
        <T v="bodyM" center>
          {email}
        </T>
        {!devCode && <T v="caption" muted center style={{ marginTop: 8 }}>Check your inbox and spam folder.</T>}
        <T v="caption" muted center style={{ marginTop: 8 }}>
          {mode === 'register' ? 'Verify within 10 minutes of creating your account. Unverified accounts are removed automatically; resending a code does not extend this time.' : 'The code expires in 10 minutes.'}
        </T>
      </FadeIn>

      <Animated.View style={{ marginTop: 26, transform: [{ translateX: shake }] }}>
        <Press onPress={() => input.current?.focus()} scaleTo={1} feedback={false} accessibilityLabel="Enter verification code">
          <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
            {Array.from({ length: 6 }, (_, i) => {
              const active = i === code.length && !busy;
              return (
                <View
                  key={i}
                  style={{
                    width: 46,
                    height: 56,
                    borderRadius: 12,
                    borderWidth: 2,
                    borderColor: err ? c.error : active ? c.primary : code[i] ? c.primary + '88' : c.border,
                    backgroundColor: c.input,
                    alignItems: 'center',
                    justifyContent: 'center',
                  }}
                >
                  <T v="h1">{code[i] ?? ''}</T>
                </View>
              );
            })}
          </View>
        </Press>
        <TextInput
          ref={input}
          value={code}
          autoFocus
          editable={!busy && !resending && !accountExpired}
          onChangeText={(t) => {
            const v = t.replace(/\D/g, '').slice(0, 6);
            setCode(v);
            setErr('');
            if (v.length === 6) verify(v);
          }}
          keyboardType="number-pad"
          textContentType="oneTimeCode"
          autoComplete="one-time-code"
          maxLength={6}
          style={{ position: 'absolute', opacity: 0, width: 1, height: 1, fontSize: 16 * scale }}
        />
        {!!err && (
          <T v="caption" color={c.error} center style={{ marginTop: 10 }}>
            {err}
          </T>
        )}
      </Animated.View>

      <View style={{ marginTop: 18 }}>
        <DevCodeBanner code={devCode} />
      </View>

      {accountExpired ? <Button title="Create account again" onPress={() => nav.replace('Signup')} style={{ marginTop: 22 }} /> :
        <Button title="Verify" onPress={() => verify()} loading={busy} disabled={code.length !== 6 || resending} style={{ marginTop: 22 }} />}
      <Press onPress={resend} disabled={wait > 0 || busy || resending || accountExpired} style={{ alignSelf: 'center', padding: 12 }}>
        <T v="bodyM" color={wait > 0 ? c.textMuted : c.primary}>
          {resending ? 'Sending code...' : wait > 0 ? `Resend code in ${wait}s` : 'Resend code'}
        </T>
      </Press>
    </Screen>
  );
}
