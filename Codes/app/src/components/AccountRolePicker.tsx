import React from 'react';
import { View } from 'react-native';
import { Icon, Press } from './ui';
import { T, useTheme } from '../theme';
import type { AccountRole } from '../store';

export default function AccountRolePicker({ value, onChange }: { value: AccountRole; onChange: (role: AccountRole) => void }) {
  const { c } = useTheme();
  return (
    <View style={{ gap: 8 }}>
      <T v="caption" muted>Account type</T>
      <View style={{ flexDirection: 'row', gap: 12 }}>
        {(['patient', 'caregiver'] as const).map((role) => (
          <Press
            key={role}
            onPress={() => onChange(role)}
            accessibilityRole="radio"
            accessibilityState={{ checked: value === role }}
            accessibilityLabel={role === 'patient' ? 'Patient' : 'Caregiver'}
            style={{ flex: 1, padding: 14, borderRadius: 12, borderWidth: 2, borderColor: value === role ? c.primary : c.border, backgroundColor: value === role ? c.primarySoft : c.surface, alignItems: 'center', gap: 6 }}
          >
            <Icon name={role === 'patient' ? 'account-outline' : 'account-heart-outline'} color={value === role ? c.primary : c.textMuted} />
            <T v="bodyM" color={value === role ? c.primary : c.text}>{role === 'patient' ? 'Patient' : 'Caregiver'}</T>
          </Press>
        ))}
      </View>
    </View>
  );
}
