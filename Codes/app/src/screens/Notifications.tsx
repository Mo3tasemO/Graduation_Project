import React from 'react';
import { ScrollView, View } from 'react-native';
import { Card, FadeIn, Icon, Press, Screen } from '../components/ui';
import { T, palette, useTheme } from '../theme';
import { useApp } from '../store';
import { timeAgo } from '../utils';

const META: Record<string, { icon: string; color: string }> = {
  headset: { icon: 'headphones', color: palette.success },
  message: { icon: 'message-text-outline', color: palette.error },
  emergency: { icon: 'alert-outline', color: palette.warning },
  battery: { icon: 'battery-20', color: palette.primary },
  model: { icon: 'brain', color: palette.purple },
};

export default function Notifications() {
  const { c } = useTheme();
  const { notifications, markRead, markAllRead, unread } = useApp();
  return (
    <Screen
      title="Notifications"
      right={
        unread > 0 ? (
          <Press onPress={markAllRead}>
            <T v="caption" color={c.primary}>
              Mark all read
            </T>
          </Press>
        ) : undefined
      }
    >
      <ScrollView contentContainerStyle={{ gap: 10, paddingBottom: 24 }} showsVerticalScrollIndicator={false}>
        {notifications.length === 0 && (
          <View style={{ alignItems: 'center', marginTop: 80, gap: 8 }}>
            <Icon name="bell-check-outline" size={56} color={c.textMuted} />
            <T v="title">You're all caught up</T>
          </View>
        )}
        {notifications.map((n, i) => {
          const m = META[n.type];
          return (
            <FadeIn key={n.id} delay={i * 50} from={12} duration={320}>
              <Press onPress={() => markRead(n.id)} scaleTo={0.98}>
                <Card pad={14} style={!n.read ? { borderColor: c.primary } : undefined}>
                  <View style={{ flexDirection: 'row', gap: 12, alignItems: 'center' }}>
                    <View style={{ width: 44, height: 44, borderRadius: 22, backgroundColor: m.color + '22', alignItems: 'center', justifyContent: 'center' }}>
                      <Icon name={m.icon} color={m.color} />
                    </View>
                    <View style={{ flex: 1 }}>
                      <T v="bodyM">{n.title}</T>
                      <T v="caption" muted>
                        {n.body}
                      </T>
                      <T v="caption" muted style={{ fontSize: 10 }}>
                        {timeAgo(n.time)}
                      </T>
                    </View>
                    {!n.read && <View style={{ width: 10, height: 10, borderRadius: 5, backgroundColor: c.primary }} />}
                  </View>
                </Card>
              </Press>
            </FadeIn>
          );
        })}
      </ScrollView>
    </Screen>
  );
}
