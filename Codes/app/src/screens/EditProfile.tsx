import React, { useState } from 'react';
import { TextInput, View } from 'react-native';
import { useNavigation, useRoute } from '@react-navigation/native';
import { Button, FadeIn, Screen, useToast } from '../components/ui';
import { T, fonts, useTheme } from '../theme';
import { Profile, useApp } from '../store';

type Field = { key: keyof Profile; label: string; keyboard?: any };

const SECTIONS: Record<string, { title: string; fields: Field[] }[]> = {
  personal: [{ title: 'Personal Information', fields: [{ key: 'phone', label: 'Phone number', keyboard: 'phone-pad' }] }],
  medical: [{ title: 'Medical Info', fields: [{ key: 'condition', label: 'Condition' }, { key: 'allergies', label: 'Allergies' }, { key: 'bloodType', label: 'Blood type' }] }],
  caregiver: [{ title: 'Caregiver', fields: [{ key: 'caregiver', label: 'Caregiver name' }, { key: 'caregiverRelation', label: 'Relation' }, { key: 'caregiverPhone', label: 'Emergency phone', keyboard: 'phone-pad' }] }],
};
SECTIONS.all = [...SECTIONS.personal, ...SECTIONS.medical, ...SECTIONS.caregiver];

export default function EditProfile() {
  const nav = useNavigation<any>();
  const route = useRoute<any>();
  const { c, scale } = useTheme();
  const { profile, updateProfile } = useApp();
  const toast = useToast();
  const [draft, setDraft] = useState<Profile>(profile);
  const section = SECTIONS[route.params?.section ?? 'all'];

  const save = () => {
    if (draft.phone && draft.phone.replace(/\D/g, '').length < 11) return toast('Phone number must have at least 11 digits', 'error');
    updateProfile(draft);
    toast('Profile updated', 'success');
    nav.goBack();
  };

  return (
    <Screen title={section.length === 1 ? section[0].title : 'Edit Profile'} scroll>
      {section.map((s, si) => (
        <FadeIn key={s.title} delay={si * 80} style={{ marginTop: 8 }}>
          {section.length > 1 && (
            <T v="title" style={{ marginTop: 12, marginBottom: 8 }}>
              {s.title}
            </T>
          )}
          <View style={{ gap: 12 }}>
            {s.fields.map((f) => (
              <View key={f.key}>
                <T v="caption" muted style={{ marginBottom: 4 }}>
                  {f.label}
                </T>
                <TextInput
                  value={draft[f.key]}
                  onChangeText={(v) => setDraft({ ...draft, [f.key]: v })}
                  keyboardType={f.keyboard}
                  placeholder={f.label}
                  placeholderTextColor={c.textMuted}
                  style={[
                    { backgroundColor: c.input, borderWidth: 1.5, borderColor: c.border, borderRadius: 12, paddingHorizontal: 14, paddingVertical: 12, color: c.text, fontFamily: fonts.regular, fontSize: 14 * scale },
                    { outlineStyle: 'none' } as any,
                  ]}
                />
              </View>
            ))}
          </View>
        </FadeIn>
      ))}
      <Button title="Save changes" onPress={save} style={{ marginTop: 24 }} />
    </Screen>
  );
}
