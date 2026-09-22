import React, { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from 'react';
import {
  Animated,
  Easing,
  Modal,
  PanResponder,
  Platform,
  Pressable,
  PressableProps,
  StyleProp,
  StyleSheet,
  TouchableWithoutFeedback,
  View,
  ViewStyle,
  ActivityIndicator,
  ScrollView,
} from 'react-native';
import { SafeAreaView, useSafeAreaInsets } from 'react-native-safe-area-context';
import { MaterialCommunityIcons } from '@expo/vector-icons';
import { useNavigation } from '@react-navigation/native';
import { palette, T, useTheme } from '../theme';
import { haptic } from '../store';

export const ND = Platform.OS !== 'web';

export function Icon({ name, size = 22, color }: { name: string; size?: number; color?: string }) {
  const { c, scale } = useTheme();
  return <MaterialCommunityIcons name={name as any} size={size * (scale > 1 ? 1.1 : 1)} color={color ?? c.text} />;
}

/** Fade + slide-up entrance. */
export function FadeIn({
  children,
  delay = 0,
  from = 16,
  style,
  duration = 450,
}: {
  children: React.ReactNode;
  delay?: number;
  from?: number;
  style?: StyleProp<ViewStyle>;
  duration?: number;
}) {
  const v = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    Animated.timing(v, { toValue: 1, duration, delay, easing: Easing.out(Easing.cubic), useNativeDriver: ND }).start();
  }, []);
  return (
    <Animated.View style={[{ opacity: v, transform: [{ translateY: v.interpolate({ inputRange: [0, 1], outputRange: [from, 0] }) }] }, style]}>
      {children}
    </Animated.View>
  );
}

/** Pressable with a springy scale-down. */
export function Press({
  children,
  style,
  onPress,
  scaleTo = 0.96,
  feedback = true,
  ...rest
}: PressableProps & { style?: StyleProp<ViewStyle>; scaleTo?: number; feedback?: boolean; children: React.ReactNode }) {
  const s = useRef(new Animated.Value(1)).current;
  const to = (v: number) => Animated.spring(s, { toValue: v, speed: 40, bounciness: 6, useNativeDriver: ND }).start();
  // layout props belong on the outer Pressable so parents can size/position it
  const flat = (StyleSheet.flatten(style) ?? {}) as any;
  const outer: any = {};
  const inner: any = {};
  for (const k of Object.keys(flat)) (OUTER_KEYS.test(k) ? outer : inner)[k] = flat[k];
  return (
    <Pressable
      {...rest}
      style={outer}
      onPressIn={() => to(scaleTo)}
      onPressOut={() => to(1)}
      onPress={(e) => {
        if (feedback) haptic('light');
        onPress?.(e);
      }}
    >
      <Animated.View style={[{ transform: [{ scale: s }] }, inner]}>{children}</Animated.View>
    </Pressable>
  );
}

const OUTER_KEYS = /^(flex|flexGrow|flexShrink|flexBasis|width|alignSelf|margin.*|position|top|left|right|bottom|zIndex)$/;

export function Card({ children, style, pad = 16 }: { children: React.ReactNode; style?: StyleProp<ViewStyle>; pad?: number }) {
  const { c, hc } = useTheme();
  return (
    <View
      style={[
        {
          backgroundColor: c.surface,
          borderRadius: 18,
          padding: pad,
          borderWidth: hc ? 2 : 1,
          borderColor: hc ? c.border : c.border,
          boxShadow: `0 4px 14px ${c.shadow}`,
        },
        style,
      ]}
    >
      {children}
    </View>
  );
}

type BtnVariant = 'primary' | 'secondary' | 'success' | 'danger' | 'ghost';

export function Button({
  title,
  onPress,
  variant = 'primary',
  icon,
  loading,
  disabled,
  style,
  small,
}: {
  title: string;
  onPress?: () => void;
  variant?: BtnVariant;
  icon?: string;
  loading?: boolean;
  disabled?: boolean;
  style?: StyleProp<ViewStyle>;
  small?: boolean;
}) {
  const { c, hc } = useTheme();
  const map: Record<BtnVariant, { bg: string; fg: string; border?: string }> = {
    primary: { bg: c.primary, fg: '#fff' },
    secondary: { bg: 'transparent', fg: c.primary, border: c.primary },
    success: { bg: palette.success, fg: '#fff' },
    danger: { bg: palette.error, fg: '#fff' },
    ghost: { bg: 'transparent', fg: c.textMuted, border: c.border },
  };
  const m = map[variant];
  const off = disabled || loading;
  return (
    <Press
      accessibilityRole="button"
      accessibilityLabel={title}
      disabled={off}
      onPress={onPress}
      style={[
        {
          minHeight: small ? 44 : 52,
          borderRadius: small ? 12 : 14,
          backgroundColor: m.bg,
          borderWidth: m.border ? (hc ? 2 : 1.5) : 0,
          borderColor: m.border,
          alignItems: 'center',
          justifyContent: 'center',
          flexDirection: 'row',
          gap: 8,
          paddingHorizontal: 18,
          opacity: off ? 0.55 : 1,
          boxShadow: m.bg !== 'transparent' ? `0 6px 16px ${m.bg}44` : undefined,
        },
        style,
      ]}
    >
      {loading ? <ActivityIndicator color={m.fg} /> : icon ? <Icon name={icon} size={20} color={m.fg} /> : null}
      <T v="title" color={m.fg} size={small ? 14 : 16}>
        {title}
      </T>
    </Press>
  );
}

/** Screen container with safe-area and optional header. */
export function Screen({
  children,
  title,
  back = true,
  right,
  scroll = false,
  style,
  bg,
  edges = ['top'],
  padded = true,
}: {
  children: React.ReactNode;
  title?: string;
  back?: boolean;
  right?: React.ReactNode;
  scroll?: boolean;
  style?: StyleProp<ViewStyle>;
  bg?: string;
  edges?: ('top' | 'bottom')[];
  padded?: boolean;
}) {
  const { c } = useTheme();
  const nav = useNavigation<any>();
  const body = scroll ? (
    <ScrollView
      contentContainerStyle={[{ paddingHorizontal: padded ? 20 : 0, paddingBottom: 28 }, style]}
      showsVerticalScrollIndicator={false}
      keyboardShouldPersistTaps="handled"
    >
      {children}
    </ScrollView>
  ) : (
    <View style={[{ flex: 1, paddingHorizontal: padded ? 20 : 0 }, style]}>{children}</View>
  );
  return (
    <SafeAreaView edges={edges} style={{ flex: 1, backgroundColor: bg ?? c.bg }}>
      {title !== undefined && (
        <View style={{ flexDirection: 'row', alignItems: 'center', paddingHorizontal: 12, paddingVertical: 10, minHeight: 56 }}>
          {back && nav.canGoBack() ? (
            <Press onPress={() => nav.goBack()} accessibilityLabel="Go back" style={{ width: 44, height: 44, alignItems: 'center', justifyContent: 'center' }}>
              <Icon name="chevron-left" size={28} />
            </Press>
          ) : (
            <View style={{ width: 12 }} />
          )}
          <T v="title" style={{ flex: 1 }} numberOfLines={1}>
            {title}
          </T>
          <View style={{ minWidth: 44, alignItems: 'flex-end', paddingRight: 8 }}>{right}</View>
        </View>
      )}
      {body}
    </SafeAreaView>
  );
}

export function IconButton({ name, onPress, badge, label, size = 24 }: { name: string; onPress?: () => void; badge?: number; label?: string; size?: number }) {
  const { c } = useTheme();
  return (
    <Press onPress={onPress} accessibilityLabel={label ?? name} style={{ width: 44, height: 44, alignItems: 'center', justifyContent: 'center' }}>
      <Icon name={name} size={size} />
      {!!badge && (
        <View
          style={{
            position: 'absolute',
            top: 5,
            right: 5,
            minWidth: 18,
            height: 18,
            borderRadius: 9,
            backgroundColor: palette.error,
            alignItems: 'center',
            justifyContent: 'center',
            borderWidth: 2,
            borderColor: c.bg,
          }}
        >
          <T v="caption" color="#fff" size={10} style={{ lineHeight: 14 }}>
            {badge > 9 ? '9+' : badge}
          </T>
        </View>
      )}
    </Press>
  );
}

export function Toggle({ value, onChange, label }: { value: boolean; onChange: (v: boolean) => void; label: string }) {
  const { c } = useTheme();
  const v = useRef(new Animated.Value(value ? 1 : 0)).current;
  useEffect(() => {
    Animated.spring(v, { toValue: value ? 1 : 0, speed: 20, bounciness: 8, useNativeDriver: ND }).start();
  }, [value]);
  return (
    <Pressable
      accessibilityRole="switch"
      accessibilityLabel={label}
      accessibilityState={{ checked: value }}
      onPress={() => {
        haptic('light');
        onChange(!value);
      }}
      hitSlop={8}
    >
      <View style={{ width: 48, height: 28, borderRadius: 14, backgroundColor: c.border, justifyContent: 'center', overflow: 'hidden' }}>
        <Animated.View style={{ ...absFill, backgroundColor: c.primary, opacity: v }} />
        <Animated.View
          style={{
            width: 22,
            height: 22,
            borderRadius: 11,
            backgroundColor: '#fff',
            marginLeft: 3,
            transform: [{ translateX: v.interpolate({ inputRange: [0, 1], outputRange: [0, 20] }) }],
            boxShadow: '0 1px 3px rgba(0,0,0,0.3)',
          }}
        />
      </View>
    </Pressable>
  );
}

const absFill = { position: 'absolute' as const, top: 0, left: 0, right: 0, bottom: 0 };

export function Slider({ value, min, max, onChange }: { value: number; min: number; max: number; onChange: (v: number) => void }) {
  const { c } = useTheme();
  const [w, setW] = useState(0);
  const wRef = useRef(0);
  const cb = useRef(onChange);
  cb.current = onChange;
  const startX = useRef(0);
  const set = (x: number) => {
    if (!wRef.current) return;
    const r = Math.max(0, Math.min(1, x / wRef.current));
    cb.current(min + r * (max - min));
  };
  const pan = useMemo(
    () =>
      PanResponder.create({
        onStartShouldSetPanResponder: () => true,
        onMoveShouldSetPanResponder: () => true,
        onPanResponderTerminationRequest: () => false,
        onPanResponderGrant: (e) => {
          startX.current = e.nativeEvent.locationX;
          set(startX.current);
        },
        onPanResponderMove: (_e, g) => set(startX.current + g.dx),
      }),
    [min, max],
  );
  const pct = (value - min) / (max - min);
  return (
    <View
      {...pan.panHandlers}
      onLayout={(e) => {
        wRef.current = e.nativeEvent.layout.width;
        setW(e.nativeEvent.layout.width);
      }}
      style={{ height: 32, justifyContent: 'center' }}
      accessibilityRole="adjustable"
    >
      <View pointerEvents="none" style={{ height: 6, borderRadius: 3, backgroundColor: c.border }}>
        <View style={{ width: `${pct * 100}%`, height: 6, borderRadius: 3, backgroundColor: c.primary }} />
      </View>
      <View
        pointerEvents="none"
        style={{
          position: 'absolute',
          left: Math.max(0, pct * w - 10),
          width: 20,
          height: 20,
          borderRadius: 10,
          backgroundColor: '#fff',
          borderWidth: 3,
          borderColor: c.primary,
          boxShadow: '0 2px 6px rgba(0,0,0,0.25)',
        }}
      />
    </View>
  );
}

/** Animated horizontal progress bar. */
export function ProgressBar({ value, color, height = 8 }: { value: number; color?: string; height?: number }) {
  const { c } = useTheme();
  const v = useRef(new Animated.Value(value)).current;
  useEffect(() => {
    Animated.timing(v, { toValue: value, duration: 250, useNativeDriver: false }).start();
  }, [value]);
  return (
    <View style={{ height, borderRadius: height / 2, backgroundColor: c.border, overflow: 'hidden' }}>
      <Animated.View
        style={{
          height,
          borderRadius: height / 2,
          backgroundColor: color ?? c.primary,
          width: v.interpolate({ inputRange: [0, 100], outputRange: ['0%', '100%'] }),
        }}
      />
    </View>
  );
}

/** Bottom-sheet option picker. */
export function Picker<TV extends string | number>({
  visible,
  title,
  options,
  value,
  onSelect,
  onClose,
}: {
  visible: boolean;
  title: string;
  options: { label: string; value: TV; disabled?: boolean; hint?: string }[];
  value: TV;
  onSelect: (v: TV) => void;
  onClose: () => void;
}) {
  const { c } = useTheme();
  const insets = useSafeAreaInsets();
  return (
    <Modal visible={visible} transparent animationType="fade" onRequestClose={onClose} statusBarTranslucent>
      <TouchableWithoutFeedback onPress={onClose}>
        <View style={{ flex: 1, backgroundColor: 'rgba(2,6,23,0.5)', justifyContent: 'flex-end' }}>
          <TouchableWithoutFeedback>
            <FadeIn from={40} duration={280}>
              <View style={{ backgroundColor: c.surface, borderTopLeftRadius: 24, borderTopRightRadius: 24, padding: 20, paddingBottom: 20 + insets.bottom }}>
                <View style={{ alignSelf: 'center', width: 40, height: 4, borderRadius: 2, backgroundColor: c.border, marginBottom: 14 }} />
                <T v="h2" style={{ marginBottom: 8 }}>
                  {title}
                </T>
                {options.map((o) => {
                  const sel = o.value === value;
                  return (
                    <Press
                      key={String(o.value)}
                      disabled={o.disabled}
                      onPress={() => {
                        onSelect(o.value);
                        onClose();
                      }}
                      scaleTo={0.98}
                      style={{ flexDirection: 'row', alignItems: 'center', paddingVertical: 14, opacity: o.disabled ? 0.45 : 1 }}
                    >
                      <View style={{ flex: 1 }}>
                        <T v="bodyM" color={sel ? c.primary : c.text}>
                          {o.label}
                        </T>
                        {!!o.hint && (
                          <T v="caption" muted>
                            {o.hint}
                          </T>
                        )}
                      </View>
                      {sel && <Icon name="check-circle" color={c.primary} />}
                    </Press>
                  );
                })}
              </View>
            </FadeIn>
          </TouchableWithoutFeedback>
        </View>
      </TouchableWithoutFeedback>
    </Modal>
  );
}

// ---------------------------------------------------------------- Toast
type ToastKind = 'info' | 'success' | 'error';
const ToastCtx = createContext<(msg: string, kind?: ToastKind) => void>(() => {});
export const useToast = () => useContext(ToastCtx);

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const { c } = useTheme();
  const insets = useSafeAreaInsets();
  const [t, setT] = useState<{ msg: string; kind: ToastKind } | null>(null);
  const v = useRef(new Animated.Value(0)).current;
  const timer = useRef<any>(null);
  const show = useCallback((msg: string, kind: ToastKind = 'info') => {
    setT({ msg, kind });
    clearTimeout(timer.current);
    Animated.spring(v, { toValue: 1, speed: 18, bounciness: 8, useNativeDriver: ND }).start();
    timer.current = setTimeout(() => Animated.timing(v, { toValue: 0, duration: 220, useNativeDriver: ND }).start(() => setT(null)), 2200);
  }, []);
  const color = t?.kind === 'success' ? palette.success : t?.kind === 'error' ? palette.error : c.primary;
  const icon = t?.kind === 'success' ? 'check-circle' : t?.kind === 'error' ? 'alert-circle' : 'information';
  return (
    <ToastCtx.Provider value={show}>
      {children}
      {t && (
        <Animated.View
          pointerEvents="none"
          style={{
            position: 'absolute',
            top: insets.top + 10,
            left: 20,
            right: 20,
            opacity: v,
            transform: [{ translateY: v.interpolate({ inputRange: [0, 1], outputRange: [-30, 0] }) }],
          }}
        >
          <View
            style={{
              flexDirection: 'row',
              alignItems: 'center',
              gap: 10,
              backgroundColor: c.surface,
              borderRadius: 14,
              padding: 14,
              borderLeftWidth: 4,
              borderLeftColor: color,
              boxShadow: '0 8px 24px rgba(15,23,42,0.18)',
            }}
          >
            <Icon name={icon} color={color} />
            <T v="bodyM" style={{ flex: 1 }}>
              {t.msg}
            </T>
          </View>
        </Animated.View>
      )}
    </ToastCtx.Provider>
  );
}

/** Repeating pulse ring, used for radar / SOS / listening effects. */
export function PulseRing({ size, color, delay = 0, duration = 2000 }: { size: number; color: string; delay?: number; duration?: number }) {
  const v = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    const a = Animated.loop(
      Animated.sequence([
        Animated.delay(delay),
        Animated.timing(v, { toValue: 1, duration, easing: Easing.out(Easing.quad), useNativeDriver: ND }),
      ]),
    );
    a.start();
    return () => a.stop();
  }, []);
  return (
    <Animated.View
      pointerEvents="none"
      style={{
        position: 'absolute',
        width: size,
        height: size,
        borderRadius: size / 2,
        borderWidth: 2,
        borderColor: color,
        opacity: v.interpolate({ inputRange: [0, 1], outputRange: [0.6, 0] }),
        transform: [{ scale: v.interpolate({ inputRange: [0, 1], outputRange: [0.6, 1.5] }) }],
      }}
    />
  );
}

export function Divider() {
  const { c } = useTheme();
  return <View style={{ height: 1, backgroundColor: c.border }} />;
}

export function Badge({ text, color }: { text: string; color: string }) {
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6, backgroundColor: color + '22', borderRadius: 12, paddingHorizontal: 10, paddingVertical: 3 }}>
      <View style={{ width: 7, height: 7, borderRadius: 4, backgroundColor: color }} />
      <T v="caption" color={color}>
        {text}
      </T>
    </View>
  );
}
