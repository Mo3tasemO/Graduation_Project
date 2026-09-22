import React, { useState } from 'react';
import { Image, TextInput, TextInputProps, View } from 'react-native';
import { Icon, Press } from './ui';
import { T, fonts, palette, useTheme } from '../theme';
import { passwordChecks } from '../services/auth';

type Props = TextInputProps & { icon: string; right?: React.ReactNode; error?: string; label?: string };

export function Field({ icon, right, error, label, ...props }: Props) {
  const { c, scale } = useTheme();
  const [focus, setFocus] = useState(false);
  return (
    <View>
      {!!label && (
        <T v="caption" muted style={{ marginBottom: 4 }}>
          {label}
        </T>
      )}
      <View
        style={{
          flexDirection: 'row',
          alignItems: 'center',
          backgroundColor: c.input,
          borderWidth: 1.5,
          borderColor: error ? c.error : focus ? c.primary : c.border,
          borderRadius: 14,
          paddingHorizontal: 14,
          minHeight: 52,
          gap: 10,
        }}
      >
        <Icon name={icon} size={20} color={error ? c.error : focus ? c.primary : c.textMuted} />
        <TextInput
          {...props}
          onFocus={(e) => {
            setFocus(true);
            props.onFocus?.(e);
          }}
          onBlur={(e) => {
            setFocus(false);
            props.onBlur?.(e);
          }}
          placeholderTextColor={c.textMuted}
          accessibilityLabel={label ?? props.placeholder}
          style={[{ flex: 1, color: c.text, fontFamily: fonts.regular, fontSize: 14 * scale, paddingVertical: 12 }, { outlineStyle: 'none' } as any]}
        />
        {right}
      </View>
      {!!error && (
        <T v="caption" color={c.error} style={{ marginTop: 4 }}>
          {error}
        </T>
      )}
    </View>
  );
}

/** Password field with a show/hide eye. */
export function PasswordField(props: Omit<Props, 'icon' | 'right' | 'secureTextEntry'>) {
  const { c } = useTheme();
  const [show, setShow] = useState(false);
  return (
    <Field
      {...props}
      icon="lock-outline"
      secureTextEntry={!show}
      autoCapitalize="none"
      right={
        <Press onPress={() => setShow(!show)} accessibilityLabel="Toggle password visibility">
          <Icon name={show ? 'eye-outline' : 'eye-off-outline'} size={20} color={c.textMuted} />
        </Press>
      }
    />
  );
}

/** Live checklist for the password rules. */
export function PasswordRules({ password }: { password: string }) {
  const { c } = useTheme();
  const k = passwordChecks(password);
  const rows: [boolean, string][] = [
    [k.length, 'At least 8 characters'],
    [k.number, 'At least one number'],
    [k.special, 'At least one special character (! @ # $ …)'],
  ];
  return (
    <View style={{ gap: 4, marginTop: 8 }}>
      {rows.map(([ok, text]) => (
        <View key={text} style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
          <Icon name={ok ? 'check-circle' : 'circle-outline'} size={16} color={ok ? palette.success : c.textMuted} />
          <T v="caption" color={ok ? palette.success : c.textMuted}>
            {text}
          </T>
        </View>
      ))}
    </View>
  );
}

export function Avatar({ photo, name, size = 48 }: { photo?: string; name: string; size?: number }) {
  const { c } = useTheme();
  if (photo) return <Image source={{ uri: photo }} style={{ width: size, height: size, borderRadius: size / 2, backgroundColor: c.primarySoft }} accessibilityLabel="Profile photo" />;
  return (
    <View style={{ width: size, height: size, borderRadius: size / 2, backgroundColor: c.primarySoft, alignItems: 'center', justifyContent: 'center' }}>
      <T v="h2" color={c.primary} size={size * 0.42}>
        {name?.[0]?.toUpperCase() ?? '?'}
      </T>
    </View>
  );
}

/** Dev-only banner: shows the code that a real backend would email. */
export function DevCodeBanner({ code }: { code?: string }) {
  const { c } = useTheme();
  if (!code) return null;
  return (
    <View style={{ backgroundColor: palette.warning + '22', borderRadius: 12, padding: 12, borderWidth: 1, borderColor: palette.warning + '66' }}>
      <T v="caption" color={c.text}>
        Dev mode: no email server is connected yet, so your code is shown here:
      </T>
      <T v="h2" color={palette.warning} style={{ letterSpacing: 4 }}>
        {code}
      </T>
    </View>
  );
}
