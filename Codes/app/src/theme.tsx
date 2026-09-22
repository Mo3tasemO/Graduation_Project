import React from 'react';
import { Text, TextProps, TextStyle } from 'react-native';
import { useApp } from './store';

// Design-system palette (from the MindSpeak design board)
export const palette = {
  primary: '#2563EB',
  primaryDark: '#1D4ED8',
  secondary: '#06B6D4',
  success: '#10B981',
  warning: '#F59E0B',
  error: '#EF4444',
  purple: '#7C3AED',
};

export type Colors = {
  bg: string;
  surface: string;
  surfaceAlt: string;
  text: string;
  textMuted: string;
  border: string;
  primary: string;
  primarySoft: string;
  secondary: string;
  success: string;
  warning: string;
  error: string;
  errorSoft: string;
  input: string;
  shadow: string;
};

const light: Colors = {
  bg: '#F8FAFC',
  surface: '#FFFFFF',
  surfaceAlt: '#F1F5F9',
  text: '#1E293B',
  textMuted: '#64748B',
  border: '#E2E8F0',
  primary: palette.primary,
  primarySoft: '#DBEAFE',
  secondary: palette.secondary,
  success: palette.success,
  warning: palette.warning,
  error: palette.error,
  errorSoft: '#FEE2E2',
  input: '#FFFFFF',
  shadow: 'rgba(37,99,235,0.10)',
};

const dark: Colors = {
  bg: '#0B1220',
  surface: '#111B2E',
  surfaceAlt: '#17233B',
  text: '#F1F5F9',
  textMuted: '#94A3B8',
  border: '#1F2E4A',
  primary: '#3B82F6',
  primarySoft: '#16264A',
  secondary: palette.secondary,
  success: palette.success,
  warning: palette.warning,
  error: '#F87171',
  errorSoft: '#3B1A22',
  input: '#111B2E',
  shadow: 'rgba(0,0,0,0.35)',
};

export function useTheme() {
  const { settings } = useApp();
  const isDark = settings.darkMode;
  let c = isDark ? dark : light;
  if (settings.highContrast) {
    c = isDark
      ? { ...c, text: '#FFFFFF', textMuted: '#E2E8F0', border: '#94A3B8', bg: '#000000', surface: '#0A0F1C' }
      : { ...c, text: '#000000', textMuted: '#1E293B', border: '#0F172A', primary: '#1D4ED8' };
  }
  const scale = settings.largeText ? 1.2 : 1;
  return { c, isDark, hc: settings.highContrast, scale };
}

export const fonts = {
  regular: 'Poppins_400Regular',
  medium: 'Poppins_500Medium',
  semi: 'Poppins_600SemiBold',
  bold: 'Poppins_700Bold',
};

// Typography from the design board: H1 24/32 Bold, H2 20/28 Semibold, Body 14/22 Regular, Caption 12/20 Medium
const VARIANTS = {
  display: { size: 34, lh: 44, font: fonts.bold },
  h1: { size: 24, lh: 32, font: fonts.bold },
  h2: { size: 20, lh: 28, font: fonts.semi },
  title: { size: 16, lh: 24, font: fonts.semi },
  body: { size: 14, lh: 22, font: fonts.regular },
  bodyM: { size: 14, lh: 22, font: fonts.medium },
  caption: { size: 12, lh: 20, font: fonts.medium },
};

export type Variant = keyof typeof VARIANTS;

type TProps = TextProps & {
  v?: Variant;
  color?: string;
  muted?: boolean;
  center?: boolean;
  size?: number;
  weight?: keyof typeof fonts;
};

export function T({ v = 'body', color, muted, center, size, weight, style, ...rest }: TProps) {
  const { c, scale } = useTheme();
  const spec = VARIANTS[v];
  const s: TextStyle = {
    fontFamily: weight ? fonts[weight] : spec.font,
    fontSize: (size ?? spec.size) * scale,
    lineHeight: (size ? size * 1.4 : spec.lh) * scale,
    color: color ?? (muted ? c.textMuted : c.text),
    textAlign: center ? 'center' : undefined,
  };
  return <Text {...rest} style={[s, style]} />;
}
