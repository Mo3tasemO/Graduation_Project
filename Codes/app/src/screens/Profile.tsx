import React from 'react';
import { ScrollView, View } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { Badge, Card, Divider, FadeIn, Icon, IconButton, Press, Screen } from '../components/ui';
import { T, palette, useTheme } from '../theme';
import { useApp } from '../store';
import { Avatar } from '../components/Field';

function InfoRow({ icon, label, value, badge, badgeColor }: { icon: string; label: string; value?: string; badge?: string; badgeColor?: string }) {
  const { c } = useTheme();
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12, paddingVertical: 12 }}>
      <Icon name={icon} size={20} color={c.textMuted} />
      <T v="body" style={{ flex: 1 }}>
        {label}
      </T>
      {badge ? <Badge text={badge} color={badgeColor ?? palette.success} /> : <T v="bodyM">{value}</T>}
    </View>
  );
}

function Link({ icon, label, onPress }: { icon: string; label: string; onPress: () => void }) {
  const { c } = useTheme();
  return (
    <Press onPress={onPress} scaleTo={0.98} accessibilityRole="button" accessibilityLabel={label} style={{ flexDirection: 'row', alignItems: 'center', gap: 12, paddingVertical: 14 }}>
      <Icon name={icon} size={20} color={c.textMuted} />
      <T v="body" style={{ flex: 1 }}>
        {label}
      </T>
      <Icon name="chevron-right" size={20} color={c.textMuted} />
    </Press>
  );
}

export default function Profile() {
  const nav = useNavigation<any>();
  const { c } = useTheme();
  const { profile, calibrated } = useApp();
  return (
    <Screen title="Patient Profile" back={false} right={<IconButton name="cog-outline" label="Settings" onPress={() => nav.navigate('Settings')} />}>
      <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={{ gap: 14, paddingBottom: 24 }}>
        <FadeIn>
          <Card style={{ flexDirection: 'row', alignItems: 'center', gap: 14 }}>
            <Avatar photo={profile.photo} name={profile.name} size={64} />
            <View style={{ flex: 1 }}>
              <T v="title">{profile.name}</T>
              <T v="caption" muted>
                Patient ID: {profile.id}
              </T>
              <T v="caption" muted>
                {profile.email}
              </T>
            </View>
            <IconButton name="pencil-outline" label="Edit profile" onPress={() => nav.navigate('EditProfile', { section: 'personal' })} />
          </Card>
        </FadeIn>
        <FadeIn delay={80}>
          <Card pad={4} style={{ paddingHorizontal: 16 }}>
            <InfoRow icon="identifier" label="Patient ID" value={profile.id} />
            <Divider />
            <InfoRow icon="account-outline" label="Age" value={profile.age} />
            <Divider />
            <InfoRow icon="phone-outline" label="Phone" value={profile.phone} />
            <Divider />
            <InfoRow icon="pulse" label="EEG Calibration" badge={calibrated ? 'Completed' : 'Pending'} badgeColor={calibrated ? palette.success : palette.warning} />
            <Divider />
            <InfoRow icon="brain" label="AI Model" badge={calibrated ? 'Personalized' : 'Generic'} badgeColor={calibrated ? palette.success : palette.warning} />
            <Divider />
            <InfoRow icon="account-heart-outline" label="Caregiver" value={profile.caregiverRelation || profile.caregiver} />
          </Card>
        </FadeIn>
        <FadeIn delay={160}>
          <Card pad={4} style={{ paddingHorizontal: 16 }}>
            <Link icon="card-account-details-outline" label="Personal Information" onPress={() => nav.navigate('EditProfile', { section: 'personal' })} />
            <Divider />
            <Link icon="medical-bag" label="Medical Info" onPress={() => nav.navigate('EditProfile', { section: 'medical' })} />
            <Divider />
            <Link icon="tune-variant" label="Calibration Session" onPress={() => nav.navigate('Calibration')} />
            <Divider />
            <Link icon="account-edit-outline" label="Edit Profile" onPress={() => nav.navigate('EditProfile', { section: 'all' })} />
          </Card>
        </FadeIn>
      </ScrollView>
    </Screen>
  );
}
