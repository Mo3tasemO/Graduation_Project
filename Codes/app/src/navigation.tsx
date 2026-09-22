import React, { useEffect, useRef } from 'react';
import { Animated, View } from 'react-native';
import { DarkTheme, DefaultTheme, NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { createBottomTabNavigator, BottomTabBarProps } from '@react-navigation/bottom-tabs';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Icon, Press, ND } from './components/ui';
import { T, useTheme } from './theme';

import Splash from './screens/Splash';
import Onboarding from './screens/Onboarding';
import Login from './screens/Login';
import Signup from './screens/Signup';
import VerifyCode from './screens/VerifyCode';
import ForgotPassword from './screens/ForgotPassword';
import ResetPassword from './screens/ResetPassword';
import Home from './screens/Home';
import EEGMonitor from './screens/EEGMonitor';
import AAC from './screens/AAC';
import History from './screens/History';
import Profile from './screens/Profile';
import ConnectHeadset from './screens/ConnectHeadset';
import Decoding from './screens/Decoding';
import Prediction from './screens/Prediction';
import Message from './screens/Message';
import Settings from './screens/Settings';
import Emergency from './screens/Emergency';
import Calibration from './screens/Calibration';
import Notifications from './screens/Notifications';
import EditProfile from './screens/EditProfile';
import Accessibility from './screens/Accessibility';

const Stack = createNativeStackNavigator();
const Tab = createBottomTabNavigator();

const TABS: Record<string, { label: string; icon: string }> = {
  Home: { label: 'Home', icon: 'home' },
  Communicate: { label: 'Communicate', icon: 'brain' },
  AAC: { label: 'AAC', icon: 'view-grid' },
  History: { label: 'History', icon: 'history' },
  Profile: { label: 'Profile', icon: 'account' },
};

function TabItem({ name, focused, onPress }: { name: string; focused: boolean; onPress: () => void }) {
  const { c } = useTheme();
  const v = useRef(new Animated.Value(focused ? 1 : 0)).current;
  useEffect(() => {
    Animated.spring(v, { toValue: focused ? 1 : 0, speed: 16, bounciness: 12, useNativeDriver: ND }).start();
  }, [focused]);
  const t = TABS[name];
  return (
    <Press onPress={onPress} feedback={!focused} accessibilityRole="tab" accessibilityLabel={t.label} accessibilityState={{ selected: focused }} style={{ flex: 1, alignItems: 'center', paddingTop: 8, paddingBottom: 4 }} scaleTo={0.9}>
      <Animated.View style={{ position: 'absolute', top: 0, width: 28, height: 3, borderRadius: 2, backgroundColor: c.primary, opacity: v, transform: [{ scaleX: v }] }} />
      <Animated.View style={{ transform: [{ translateY: v.interpolate({ inputRange: [0, 1], outputRange: [0, -2] }) }, { scale: v.interpolate({ inputRange: [0, 1], outputRange: [1, 1.15] }) }] }}>
        <Icon name={t.icon} size={24} color={focused ? c.primary : c.textMuted} />
      </Animated.View>
      <T v="caption" color={focused ? c.primary : c.textMuted} style={{ fontSize: 10, lineHeight: 14 }}>
        {t.label}
      </T>
    </Press>
  );
}

function TabBar({ state, navigation }: BottomTabBarProps) {
  const { c } = useTheme();
  const insets = useSafeAreaInsets();
  return (
    <View style={{ flexDirection: 'row', backgroundColor: c.surface, borderTopWidth: 1, borderTopColor: c.border, paddingBottom: Math.max(insets.bottom, 6) }}>
      {state.routes.map((r, i) => (
        <TabItem
          key={r.key}
          name={r.name}
          focused={state.index === i}
          onPress={() => {
            const e = navigation.emit({ type: 'tabPress', target: r.key, canPreventDefault: true });
            if (state.index !== i && !e.defaultPrevented) navigation.navigate(r.name);
          }}
        />
      ))}
    </View>
  );
}

function Main() {
  return (
    <Tab.Navigator tabBar={(p) => <TabBar {...p} />} screenOptions={{ headerShown: false, animation: 'fade' } as any}>
      <Tab.Screen name="Home" component={Home} />
      <Tab.Screen name="Communicate" component={EEGMonitor} />
      <Tab.Screen name="AAC" component={AAC} />
      <Tab.Screen name="History" component={History} />
      <Tab.Screen name="Profile" component={Profile} />
    </Tab.Navigator>
  );
}

export default function Navigation() {
  const { c, isDark } = useTheme();
  const base = isDark ? DarkTheme : DefaultTheme;
  const theme = { ...base, colors: { ...base.colors, background: c.bg, card: c.surface, text: c.text, border: c.border, primary: c.primary } };
  return (
    <NavigationContainer theme={theme}>
      <Stack.Navigator screenOptions={{ headerShown: false, animation: 'slide_from_right', contentStyle: { backgroundColor: c.bg } }}>
        <Stack.Screen name="Splash" component={Splash} options={{ animation: 'fade' }} />
        <Stack.Screen name="Onboarding" component={Onboarding} options={{ animation: 'fade' }} />
        <Stack.Screen name="Login" component={Login} options={{ animation: 'fade' }} />
        <Stack.Screen name="Signup" component={Signup} />
        <Stack.Screen name="VerifyCode" component={VerifyCode} />
        <Stack.Screen name="ForgotPassword" component={ForgotPassword} />
        <Stack.Screen name="ResetPassword" component={ResetPassword} options={{ gestureEnabled: false }} />
        <Stack.Screen name="Main" component={Main} options={{ animation: 'fade', gestureEnabled: false }} />
        <Stack.Screen name="ConnectHeadset" component={ConnectHeadset} />
        <Stack.Screen name="Decoding" component={Decoding} options={{ animation: 'fade_from_bottom' }} />
        <Stack.Screen name="Prediction" component={Prediction} options={{ animation: 'fade_from_bottom' }} />
        <Stack.Screen name="Message" component={Message} options={{ animation: 'slide_from_bottom' }} />
        <Stack.Screen name="Settings" component={Settings} />
        <Stack.Screen name="EditProfile" component={EditProfile} />
        <Stack.Screen name="Accessibility" component={Accessibility} />
        <Stack.Screen name="Calibration" component={Calibration} />
        <Stack.Screen name="Notifications" component={Notifications} />
        <Stack.Screen name="Emergency" component={Emergency} options={{ animation: 'slide_from_bottom', presentation: 'fullScreenModal' }} />
      </Stack.Navigator>
    </NavigationContainer>
  );
}
