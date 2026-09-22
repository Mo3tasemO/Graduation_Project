import React, { useEffect, useRef, useState } from 'react';
import { Animated, Easing, View } from 'react-native';
import { useNavigation, useRoute } from '@react-navigation/native';
import { Button, Card, FadeIn, Icon, PulseRing, Screen, ND, useToast } from '../components/ui';
import { T, palette, useTheme } from '../theme';
import { Device, useApp } from '../store';
import { api } from '../services/api';

export default function ConnectHeadset() {
  const nav = useNavigation<any>();
  const route = useRoute<any>();
  const { c } = useTheme();
  const { connection, setConnection, addNotification, disconnect } = useApp();
  const toast = useToast();
  const [devices, setDevices] = useState<Device[]>([]);
  const [scanning, setScanning] = useState(true);
  const [busyId, setBusyId] = useState<string | null>(null);
  const stop = useRef<() => void>(() => {});
  const bob = useRef(new Animated.Value(0)).current;

  const scan = () => {
    stop.current();
    setDevices([]);
    setScanning(true);
    const cancel = api.scanDevices((d) => setDevices((p) => (p.find((x) => x.id === d.id) ? p : [...p, d])));
    const done = setTimeout(() => setScanning(false), 4200);
    stop.current = () => {
      cancel();
      clearTimeout(done);
    };
  };

  useEffect(() => {
    scan();
    const a = Animated.loop(
      Animated.sequence([
        Animated.timing(bob, { toValue: 1, duration: 1400, easing: Easing.inOut(Easing.quad), useNativeDriver: ND }),
        Animated.timing(bob, { toValue: 0, duration: 1400, easing: Easing.inOut(Easing.quad), useNativeDriver: ND }),
      ]),
    );
    a.start();
    return () => {
      stop.current();
      a.stop();
    };
  }, []);

  const connect = async (d: Device) => {
    setBusyId(d.id);
    setConnection({ status: 'connecting' });
    try {
      const info = await api.connect(d);
      setConnection({ status: 'connected', device: d, ...info });
      addNotification({ type: 'headset', title: 'Headset Connected', body: `Your ${d.name} headset is now connected.` });
      toast(`Connected to ${d.name}`, 'success');
      setTimeout(() => {
        if (route.params?.next === 'communicate') nav.replace('Main', { screen: 'Communicate', params: { autoStart: Date.now() } });
        else nav.goBack();
      }, 700);
    } catch {
      setConnection({ status: 'disconnected' });
      toast('Could not connect. Try again.', 'error');
    } finally {
      setBusyId(null);
    }
  };

  const rssiIcon = (r: number) => (r > -60 ? 'signal-cellular-3' : r > -80 ? 'signal-cellular-2' : 'signal-cellular-1');

  return (
    <Screen title="Connect Headset" scroll>
      <View style={{ alignItems: 'center', justifyContent: 'center', height: 240, marginTop: 8 }}>
        {scanning && (
          <>
            <PulseRing size={150} color={c.primary} />
            <PulseRing size={150} color={c.primary} delay={700} />
            <PulseRing size={150} color={c.primary} delay={1400} />
          </>
        )}
        <Animated.View
          style={{
            width: 120,
            height: 120,
            borderRadius: 60,
            backgroundColor: c.surface,
            alignItems: 'center',
            justifyContent: 'center',
            borderWidth: 3,
            borderColor: connection.status === 'connected' ? palette.success : c.primary,
            boxShadow: `0 10px 30px ${c.shadow}`,
            transform: [{ translateY: bob.interpolate({ inputRange: [0, 1], outputRange: [-4, 4] }) }],
          }}
        >
          <Icon name={connection.status === 'connected' ? 'headphones' : 'headphones'} size={58} color={connection.status === 'connected' ? palette.success : c.primary} />
        </Animated.View>
      </View>
      <T v="bodyM" center muted style={{ marginBottom: 20 }}>
        {connection.status === 'connected' ? `Connected to ${connection.device?.name}` : scanning ? 'Searching for MindSpeak devices...' : devices.length ? 'Choose your headset' : 'No devices found'}
      </T>

      <T v="bodyM" style={{ marginBottom: 10 }}>
        Available Devices
      </T>
      <View style={{ gap: 12 }}>
        {devices.map((d, i) => {
          const isCurrent = connection.status === 'connected' && connection.device?.id === d.id;
          return (
            <FadeIn key={d.id} from={20} duration={350}>
              <Card pad={12}>
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12 }}>
                  <View style={{ width: 42, height: 42, borderRadius: 21, backgroundColor: c.primarySoft, alignItems: 'center', justifyContent: 'center' }}>
                    <Icon name="brain" size={22} color={c.primary} />
                  </View>
                  <View style={{ flex: 1 }}>
                    <T v="bodyM">{d.name}</T>
                    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 4 }}>
                      <Icon name={rssiIcon(d.rssi)} size={14} color={c.textMuted} />
                      <T v="caption" muted>
                        RSSI {d.rssi} dBm
                      </T>
                    </View>
                  </View>
                  {isCurrent ? (
                    <Button title="Disconnect" variant="ghost" small onPress={disconnect} />
                  ) : (
                    <Button
                      title="Connect"
                      small
                      loading={busyId === d.id}
                      disabled={!!busyId || connection.status === 'connecting'}
                      onPress={() => connect(d)}
                      style={{ minWidth: 96 }}
                    />
                  )}
                </View>
              </Card>
            </FadeIn>
          );
        })}
      </View>
      <Button title="Scan Again" variant="secondary" icon="refresh" onPress={scan} disabled={scanning} style={{ marginTop: 18 }} />
    </Screen>
  );
}
