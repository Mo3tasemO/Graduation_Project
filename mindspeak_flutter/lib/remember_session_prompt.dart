import 'package:flutter/material.dart';

import 'app_preferences.dart';
import 'auth_api.dart';
import 'biometric_service.dart';
import 'design_tokens.dart';

/// Asked once after each successful sign-in:
///  1. "Stay signed in on this device?" — yes saves the sign-in (never the password).
///  2. If yes and the device has fingerprint / face unlock: "Use it to open MindSpeak?"
/// Both answers can be changed later in Settings.
Future<void> askToRememberSession(BuildContext context) async {
  final arabic = Localizations.localeOf(context).languageCode == 'ar';
  String t(String en, String ar) => arabic ? ar : en;

  final remember = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      key: const Key('remember_session_dialog'),
      icon: const Icon(Icons.lock_person_rounded, color: blue, size: 34),
      title: Text(t('Stay signed in on this device?', 'تفضل مسجّل دخول على الجهاز ده؟')),
      content: Text(
        t(
          'MindSpeak will open without asking for your password next time. '
              'Your password itself is never saved. You can change this in Settings.',
          'المرة الجاية MindSpeak هيفتح من غير ما يطلب الباسورد. '
              'الباسورد نفسه مش بيتحفظ أبداً. وتقدر تغيّر ده من الإعدادات.',
        ),
      ),
      actions: [
        TextButton(
          key: const Key('remember_session_no'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(t('Not now', 'لأ، شكراً')),
        ),
        FilledButton(
          key: const Key('remember_session_yes'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(t('Stay signed in', 'أيوه، خلّيني مسجّل')),
        ),
      ],
    ),
  );

  await AuthApi.setRememberSession(remember ?? false);
  if (remember != true || !context.mounted) return;
  if (!await BiometricService.isAvailable() || !context.mounted) return;

  final useBiometrics = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      key: const Key('biometric_offer_dialog'),
      icon: const Icon(Icons.fingerprint_rounded, color: blue, size: 38),
      title: Text(t('Unlock with fingerprint or face?', 'تفتح بالبصمة أو بالوش؟')),
      content: Text(
        t(
          'For extra privacy, MindSpeak will ask for your fingerprint or face '
              'before opening your saved sign-in.',
          'عشان خصوصية أكتر، MindSpeak هيطلب بصمتك أو وشك قبل ما يفتح حسابك المحفوظ.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(t('Not now', 'لأ، شكراً')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(t('Use biometrics', 'استخدم البصمة')),
        ),
      ],
    ),
  );
  if (useBiometrics != true) return;
  // Confirm once now, so it is not turned on for a finger or face that fails.
  if (await BiometricService.authenticate()) {
    await MindSpeakPreferences.instance.setBiometrics(true);
  } else if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t(
            'Biometric unlock was not turned on. You can try again in Settings.',
            'البصمة متفعّلتش. تقدر تجرب تاني من الإعدادات.',
          ),
        ),
      ),
    );
  }
}
