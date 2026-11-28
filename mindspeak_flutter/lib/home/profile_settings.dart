import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../animated_waves.dart';
import '../app_preferences.dart';
import '../auth_api.dart';
import '../biometric_service.dart';
import '../design_tokens.dart';
import '../bluetooth/headset_bluetooth.dart';
import 'home_repository.dart';
import 'speech_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.gateway,
    required this.repository,
    required this.speech,
    required this.onLogout,
    required this.onReconnect,
    required this.onCalibration,
    super.key,
  });

  final HeadsetBluetoothGateway gateway;
  final HomeRepository repository;
  final SpeechController speech;
  final VoidCallback onLogout;
  final VoidCallback onReconnect;
  final VoidCallback onCalibration;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _medical = TextEditingController();
  final _picker = ImagePicker();
  Map<String, dynamic>? _profile;
  String? _avatarData;
  bool _avatarChanged = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _medical.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profile = await widget.repository.loadProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _name.text = profile['name']?.toString() ?? '';
        _age.text = profile['age']?.toString() ?? '';
        _medical.text = profile['medical_information']?.toString() ?? '';
        _avatarData = profile['avatar_data']?.toString();
      });
    } catch (error) {
      if (mounted) setState(() => _error = _friendly(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectAvatar() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 640,
        maxHeight: 640,
        imageQuality: 82,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.length > 1_000_000) {
        _message('Choose an image smaller than 1 MB.');
        return;
      }
      final extension = image.name.toLowerCase().split('.').last;
      final mime = switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      setState(() {
        _avatarData = 'data:$mime;base64,${base64Encode(bytes)}';
        _avatarChanged = true;
      });
    } catch (_) {
      _message('The profile picture could not be selected. Try another image.');
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final ageText = _age.text.trim();
    final age = ageText.isEmpty ? null : int.tryParse(ageText);
    if (name.isEmpty) {
      _message('Enter your display name.');
      return;
    }
    if (ageText.isNotEmpty && (age == null || age < 1 || age > 120)) {
      _message('Enter an age from 1 to 120, or leave it blank.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final changes = <String, Object?>{
        'name': name,
        'age': age,
        'medical_information': _medical.text.trim().isEmpty
            ? null
            : _medical.text.trim(),
      };
      if (_avatarChanged) changes['avatar_data'] = _avatarData;
      final saved = await widget.repository.saveProfile(changes);
      if (mounted) {
        setState(() {
          _profile = saved;
          _avatarData = saved['avatar_data']?.toString();
          _avatarChanged = false;
        });
        _message('Profile saved.');
      }
    } catch (error) {
      if (mounted) setState(() => _error = _friendly(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t(context, 'Log out?', 'تسجيل الخروج؟')),
        content: Text(
          _t(
            context,
            'Your saved account data will remain available when you sign in again.',
            'ستظل بيانات حسابك محفوظة عند تسجيل الدخول مرة أخرى.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_t(context, 'Cancel', 'إلغاء')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_t(context, 'Log out', 'تسجيل الخروج')),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.onLogout();
  }

  void _message(String value) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));

  String _friendly(Object error) => error is AuthApiException
      ? error.message
      : 'Your profile could not be saved. Check your connection and try again.';

  @override
  Widget build(BuildContext context) {
    final palette = MindSpeakPalette.of(context);
    final profile = _profile;
    return _ProfilePage(
      title: _t(context, 'Profile', 'الملف الشخصي'),
      actions: [
        IconButton(
          tooltip: _t(context, 'Settings', 'الإعدادات'),
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SettingsScreen(
                repository: widget.repository,
                speech: widget.speech,
              ),
            ),
          ),
        ),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : profile == null
          ? _LoadError(message: _error ?? 'Profile could not be loaded.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: palette.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        _Avatar(data: _avatarData, onTap: _selectAvatar),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile['name']?.toString() ?? '',
                                style: TextStyle(
                                  color: palette.primaryText,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                profile['email']?.toString() ?? '',
                                style: TextStyle(color: palette.secondaryText),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                profile['email_verified_at'] == null
                                    ? _t(
                                        context,
                                        'Email not verified',
                                        'البريد غير مؤكد',
                                      )
                                    : _t(
                                        context,
                                        'Email verified',
                                        'البريد مؤكد',
                                      ),
                                style: const TextStyle(
                                  color: green,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Card(
                  color: palette.surface,
                  child: ListTile(
                    leading: const Icon(Icons.badge_outlined, color: blue),
                    title: Text(
                      _t(context, 'Unique User ID', 'معرّف المستخدم'),
                    ),
                    subtitle: SelectableText('${profile['user_code'] ?? profile['id']}'),
                    trailing: IconButton(
                      tooltip: _t(context, 'Copy ID', 'نسخ المعرّف'),
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: '${profile['user_code'] ?? profile['id']}'),
                        );
                        if (mounted) _message('User ID copied.');
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _SectionTitle(
                  _t(context, 'Personal information', 'المعلومات الشخصية'),
                ),
                const SizedBox(height: 8),
                Card(
                  color: palette.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: _t(context, 'Display name', 'الاسم'),
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _age,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: _t(
                              context,
                              'Age (optional)',
                              'العمر (اختياري)',
                            ),
                            prefixIcon: const Icon(Icons.cake_outlined),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: _selectAvatar,
                              icon: const Icon(Icons.photo_library_outlined),
                              label: Text(
                                _t(context, 'Change photo', 'تغيير الصورة'),
                              ),
                            ),
                            if (_avatarData != null)
                              TextButton(
                                onPressed: () => setState(() {
                                  _avatarData = null;
                                  _avatarChanged = true;
                                }),
                                child: Text(_t(context, 'Remove', 'إزالة')),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _SectionTitle(
                  _t(context, 'Medical information', 'المعلومات الطبية'),
                ),
                const SizedBox(height: 4),
                Text(
                  _t(
                    context,
                    'Private to your account. Add only information you choose to share with your care team.',
                    'هذه المعلومات خاصة بحسابك. أضف فقط ما تختار مشاركته مع فريق الرعاية.',
                  ),
                  style: TextStyle(color: palette.secondaryText, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Card(
                  color: palette.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _medical,
                      maxLines: 4,
                      maxLength: 5000,
                      decoration: InputDecoration(
                        labelText: _t(
                          context,
                          'Medical notes (optional)',
                          'ملاحظات طبية (اختياري)',
                        ),
                        alignLabelWithHint: true,
                        hintText: _t(
                          context,
                          'Add relevant details or leave blank.',
                          'أضف التفاصيل المناسبة أو اتركه فارغاً.',
                        ),
                      ),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('save_profile_button'),
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_t(context, 'Save profile', 'حفظ الملف الشخصي')),
                ),
                const SizedBox(height: 12),
                Card(
                  color: palette.surface,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.tune_rounded, color: blue),
                        title: Text(
                          _t(context, 'Calibration session', 'جلسة المعايرة'),
                        ),
                        subtitle: Text(
                          _t(
                            context,
                            'Open the existing calibration flow.',
                            'فتح شاشة المعايرة الحالية.',
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: widget.onCalibration,
                      ),
                      Divider(height: 1, color: palette.border),
                      ListTile(
                        leading: const Icon(
                          Icons.bluetooth_rounded,
                          color: blue,
                        ),
                        title: Text(
                          _t(context, 'Headset connection', 'اتصال السماعة'),
                        ),
                        subtitle: Text(
                          _t(
                            context,
                            'Manage your BLE connection.',
                            'إدارة اتصال البلوتوث.',
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: widget.onReconnect,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  key: const Key('logout_button'),
                  onPressed: _confirmLogout,
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(_t(context, 'Log out', 'تسجيل الخروج')),
                ),
              ],
            ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.repository,
    required this.speech,
    super.key,
  });
  final HomeRepository repository;
  final SpeechController speech;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _savingSpeech = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.speech.addListener(_changed);
  }

  @override
  void dispose() {
    widget.speech.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _saveSpeech() async {
    setState(() => _savingSpeech = true);
    try {
      await widget.repository.savePreferences({
        'language': widget.speech.language,
        'voice_name': widget.speech.voice?.name,
        'voice_locale': widget.speech.voice?.locale,
        'rate': widget.speech.rate,
        'volume': widget.speech.volume,
      });
      if (mounted) _message('Speech settings saved.');
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Speech settings could not be saved.');
    } finally {
      if (mounted) setState(() => _savingSpeech = false);
    }
  }

  Future<void> _setStaySignedIn(bool enabled) async {
    await AuthApi.setRememberSession(enabled);
    if (mounted) setState(() {});
  }

  Future<void> _setBiometrics(bool enabled) async {
    final prefs = MindSpeakPreferences.instance;
    if (!enabled) {
      await prefs.setBiometrics(false);
      return;
    }
    if (!await BiometricService.isAvailable()) {
      _message('Biometric authentication is not available on this device.');
      return;
    }
    if (!await AuthApi.hasSavedToken()) {
      _message('Turn on "Stay signed in on this device" first.');
      return;
    }
    if (!await BiometricService.authenticate()) {
      _message('Biometric verification was not completed.');
      return;
    }
    await prefs.setBiometrics(true);
    if (mounted) setState(() {});
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final prefs = MindSpeakPreferences.instance;
    final palette = MindSpeakPalette.of(context);
    return _ProfilePage(
      title: _t(context, 'Settings', 'الإعدادات'),
      child: AnimatedBuilder(
        animation: prefs,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionTitle(_t(context, 'Language', 'اللغة')),
            const SizedBox(height: 6),
            Card(
              color: palette.surface,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: DropdownButtonFormField<String>(
                  key: ValueKey(
                    'ui_language_dropdown_${prefs.locale.languageCode}',
                  ),
                  initialValue: prefs.locale.languageCode,
                  decoration: InputDecoration(
                    labelText: _t(
                      context,
                      'Application language',
                      'لغة التطبيق',
                    ),
                    border: InputBorder.none,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'ar', child: Text('العربية')),
                  ],
                  onChanged: (value) {
                    if (value != null) prefs.setLanguage(value);
                  },
                ),
              ),
            ),
            const SizedBox(height: 18),
            _SectionTitle(_t(context, 'Appearance', 'المظهر')),
            const SizedBox(height: 6),
            Card(
              color: palette.surface,
              child: RadioGroup<ThemeMode>(
                groupValue: prefs.themeMode,
                onChanged: (value) {
                  if (value != null) prefs.setTheme(value);
                },
                child: Column(
                  children: [
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.light,
                      title: Text(_t(context, 'Light mode', 'الوضع الفاتح')),
                    ),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.dark,
                      title: Text(_t(context, 'Dark mode', 'الوضع الداكن')),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            _SectionTitle(
              _t(context, 'Sign-in & biometrics', 'تسجيل الدخول والبصمة'),
            ),
            Card(
              color: palette.surface,
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    key: const Key('settings_stay_signed_in'),
                    value: AuthApi.isSessionRemembered,
                    title: Text(
                      _t(
                        context,
                        'Stay signed in on this device',
                        'افضل مسجّل دخول على الجهاز ده',
                      ),
                    ),
                    subtitle: Text(
                      _t(
                        context,
                        'Open MindSpeak without typing your password. The password itself is never saved.',
                        'افتح MindSpeak من غير ما تكتب الباسورد. الباسورد نفسه مش بيتحفظ.',
                      ),
                    ),
                    onChanged: _setStaySignedIn,
                  ),
                  const Divider(height: 1),
                  SwitchListTile.adaptive(
                    value: prefs.biometricsEnabled,
                    title: Text(
                      _t(context, 'Use biometrics', 'استخدام المصادقة الحيوية'),
                    ),
                    subtitle: Text(
                      _t(
                        context,
                        'Ask for your fingerprint or face before opening your saved sign-in.',
                        'اطلب البصمة أو الوش قبل فتح حسابك المحفوظ.',
                      ),
                    ),
                    onChanged: _setBiometrics,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SectionTitle(_t(context, 'Speech', 'النطق')),
            const SizedBox(height: 6),
            Card(
              color: palette.surface,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (widget.speech.languages.isEmpty)
                      Text(
                        _t(
                          context,
                          'The device will use its default speech language.',
                          'سيستخدم الجهاز لغة النطق الافتراضية.',
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        key: const Key('speech_language_dropdown'),
                        initialValue:
                            widget.speech.languages.contains(
                              widget.speech.language,
                            )
                            ? widget.speech.language
                            : widget.speech.languages.first,
                        items: [
                          for (final language in widget.speech.languages)
                            DropdownMenuItem(
                              value: language,
                              child: Text(language),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null)
                            widget.speech.updateLanguage(value);
                        },
                        decoration: InputDecoration(
                          labelText: _t(
                            context,
                            'Available speech language',
                            'لغة النطق المتاحة',
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (widget.speech.voices.isNotEmpty)
                      DropdownButtonFormField<SpeechVoice?>(
                        key: const Key('speech_voice_dropdown'),
                        initialValue: widget.speech.voice,
                        items: [
                          const DropdownMenuItem<SpeechVoice?>(
                            value: null,
                            child: Text('Device default'),
                          ),
                          for (final voice in widget.speech.voices)
                            DropdownMenuItem(
                              value: voice,
                              child: Text(
                                '${voice.name} · ${voice.locale}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: widget.speech.updateVoice,
                        decoration: InputDecoration(
                          labelText: _t(
                            context,
                            'Available voice',
                            'الصوت المتاح',
                          ),
                        ),
                      ),
                    _ValueSlider(
                      label: _t(context, 'Speech speed', 'سرعة النطق'),
                      value: widget.speech.rate,
                      min: .1,
                      max: 1,
                      onChanged: widget.speech.updateRate,
                    ),
                    _ValueSlider(
                      label: _t(context, 'Volume', 'مستوى الصوت'),
                      value: widget.speech.volume,
                      min: 0,
                      max: 1,
                      onChanged: widget.speech.updateVolume,
                    ),
                    if (_error != null)
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 8),
                    FilledButton(
                      key: const Key('save_settings_button'),
                      onPressed: _savingSpeech ? null : _saveSpeech,
                      child: _savingSpeech
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _t(
                                context,
                                'Save speech settings',
                                'حفظ إعدادات النطق',
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _t(
                context,
                'The language list reflects the speech languages available on this device. App language is English or Arabic.',
                'تعرض القائمة لغات النطق المتاحة على الجهاز. لغة واجهة التطبيق هي الإنجليزية أو العربية.',
              ),
              style: TextStyle(color: palette.secondaryText, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class MindSpeakInfoScreen extends StatelessWidget {
  const MindSpeakInfoScreen({
    required this.title,
    required this.sections,
    super.key,
  });
  final String title;
  final List<(IconData, String, String)> sections;

  @override
  Widget build(BuildContext context) {
    final palette = MindSpeakPalette.of(context);
    return _ProfilePage(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (icon, heading, body) in sections)
            Card(
              color: palette.surface,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: blue),
                    const SizedBox(height: 10),
                    Text(
                      heading,
                      style: TextStyle(
                        color: palette.primaryText,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      body,
                      style: TextStyle(
                        color: palette.secondaryText,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.data, required this.onTap});
  final String? data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    ImageProvider? image;
    if (data != null) {
      try {
        image = MemoryImage(base64Decode(data!.split(',').last));
      } catch (_) {}
    }
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: CircleAvatar(
        radius: 35,
        backgroundColor: soft,
        backgroundImage: image,
        child: image == null
            ? const Icon(Icons.add_a_photo_outlined, color: navy)
            : null,
      ),
    );
  }
}

class _ValueSlider extends StatelessWidget {
  const _ValueSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(child: Text(label)),
          Text('${(value * 100).round()}%'),
        ],
      ),
      Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        onChanged: onChanged,
      ),
    ],
  );
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({
    required this.title,
    required this.child,
    this.actions = const [],
  });
  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final palette = MindSpeakPalette.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(title: Text(title), actions: actions),
      body: WavesBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: SingleChildScrollView(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => Text(
    value,
    style: TextStyle(
      color: MindSpeakPalette.of(context).primaryText,
      fontWeight: FontWeight.w700,
      fontSize: 16,
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(child: Text(message));
}

String _t(BuildContext context, String en, String ar) =>
    Localizations.localeOf(context).languageCode == 'ar' ? ar : en;
