import 'package:flutter/material.dart';

import '../design_tokens.dart';
import '../bluetooth/headset_bluetooth.dart';
import '../animated_waves.dart';
import '../app_preferences.dart';
import 'home_repository.dart';
import 'speech_controller.dart';
import 'profile_settings.dart';

const _quickPhrases = ['I need help', 'I am thirsty', 'Yes', 'No'];

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.gateway,
    required this.onLogout,
    required this.onReconnect,
    this.onCalibration,
    this.repository = const ApiHomeRepository(),
    this.speechEngine,
    super.key,
  });

  final HeadsetBluetoothGateway gateway;
  final VoidCallback onLogout;
  final VoidCallback onReconnect;
  final VoidCallback? onCalibration;
  final HomeRepository repository;
  final SpeechEngine? speechEngine;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final SpeechController _speech;
  final _message = TextEditingController(text: 'I need water');
  List<SavedPhrase> _phrases = const [];
  bool _loadingPhrases = true;
  String? _phraseError;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _speech = SpeechController(engine: widget.speechEngine);
    _speech.addListener(_speechChanged);
    _loadPhrases();
    _loadProfile();
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    await _speech.initialize();
    try {
      final preferences = await widget.repository.loadPreferences();
      await _speech.applyPreferences(preferences);
    } catch (_) {
      // Speech remains available with device defaults if settings cannot load.
    }
  }

  Future<void> _loadPhrases() async {
    try {
      final phrases = await widget.repository.loadPhrases();
      if (mounted) setState(() => _phrases = phrases);
    } catch (_) {
      if (mounted)
        setState(() => _phraseError = 'Saved phrases could not be loaded.');
    } finally {
      if (mounted) setState(() => _loadingPhrases = false);
    }
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await widget.repository.loadProfile();
      if (mounted) setState(() => _profile = profile);
    } catch (_) {
      // Communication and speech controls remain available if profile data is offline.
    }
  }

  void _speechChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _message.dispose();
    _speech.removeListener(_speechChanged);
    _speech.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: MindSpeakPalette.of(context).background,
    body: WavesBackground(
      child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 12),
                  _welcomeCard(context),
                  const SizedBox(height: 18),
                  _BluetoothStatus(
                    gateway: widget.gateway,
                    onReconnect: widget.onReconnect,
                  ),
                  const SizedBox(height: 22),
                  _SectionLabel(_t(context, 'YOUR MESSAGE', 'رسالتك')),
                  const SizedBox(height: 9),
                  TextField(
                    key: const Key('home_message_field'),
                    controller: _message,
                    minLines: 2,
                    maxLines: 5,
                    maxLength: 500,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: _t(
                        context,
                        'Type a message to speak',
                        'اكتب رسالة لنطقها',
                      ),
                      alignLabelWithHint: true,
                      counterText: '',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  _buildSpeakButton(),
                  if (_speech.error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _speech.error!,
                      key: const Key('speech_error'),
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  const SizedBox(height: 22),
                  _SectionLabel(_t(context, 'QUICK PHRASES', 'عبارات سريعة')),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final phrase in _quickPhrases)
                        _QuickPhrase(
                          text: phrase,
                          onTap: () => _selectPhrase(phrase),
                        ),
                      if (_loadingPhrases)
                        const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      for (final phrase in _phrases) _customPhrase(phrase),
                      OutlinedButton.icon(
                        key: const Key('add_phrase_button'),
                        onPressed: _addPhrase,
                        icon: const Icon(Icons.add_rounded),
                        label: Text(_t(context, 'Add phrase', 'إضافة عبارة')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: muted,
                          side: BorderSide(
                            color: MindSpeakPalette.of(context).border,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_phraseError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _phraseError!,
                      style: TextStyle(
                        color: MindSpeakPalette.of(context).secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    ),
  );

  Widget _buildHeader(BuildContext context) => Row(
    children: [
      const Expanded(child: _HomeWordmark()),
      IconButton(
        tooltip: _t(context, 'Message history', 'سجل الرسائل'),
        onPressed: _openHistory,
        icon: Icon(
          Icons.history_rounded,
          color: MindSpeakPalette.of(context).primaryText,
        ),
      ),
      IconButton(
        key: const Key('profile_button'),
        tooltip: _t(context, 'Profile and settings', 'الملف الشخصي والإعدادات'),
        onPressed: _openProfile,
        icon: Icon(
          Icons.person_outline_rounded,
          color: MindSpeakPalette.of(context).primaryText,
        ),
      ),
      IconButton(
        tooltip: _t(context, 'Help', 'المساعدة'),
        onPressed: () => _openInfo(context, _t(context, 'Help', 'المساعدة'), [
          (
            Icons.edit_note_rounded,
            _t(context, 'Create a message', 'اكتب رسالة'),
            _t(
              context,
              'Type in the message box, choose a quick phrase, then tap Speak message to hear it through the device voice.',
              'اكتب في مربع الرسالة أو اختر عبارة سريعة، ثم اضغط على نطق الرسالة لسماعها.',
            ),
          ),
          (
            Icons.bluetooth_searching_rounded,
            _t(context, 'Connect a headset', 'توصيل السماعة'),
            _t(
              context,
              'Open the headset screen, choose Scan for devices, select the real device shown by the system, and connect. On Chrome, approve the Bluetooth chooser. Continue stays disabled until the BLE link is confirmed.',
              'افتح شاشة السماعة واضغط البحث عن الأجهزة، ثم اختر الجهاز الحقيقي واتصل به. في Chrome وافق على نافذة البلوتوث. يظل زر المتابعة معطلاً حتى يتأكد الاتصال.',
            ),
          ),
          (
            Icons.bookmarks_outlined,
            _t(context, 'Phrases and history', 'العبارات والسجل'),
            _t(
              context,
              'Use the History button to review recent messages. Add and manage your own quick phrases in the phrase section.',
              'استخدم زر السجل لمراجعة الرسائل الأخيرة. أضف عباراتك السريعة وأدرها من قسم العبارات.',
            ),
          ),
        ]),
        icon: Icon(
          Icons.help_outline_rounded,
          color: MindSpeakPalette.of(context).primaryText,
        ),
      ),
      PopupMenuButton<String>(
        tooltip: _t(context, 'More information', 'معلومات إضافية'),
        onSelected: (item) => _openInfo(
          context,
          item == 'about'
              ? _t(context, 'About MindSpeak', 'عن MindSpeak')
              : _t(context, 'Contact us', 'اتصل بنا'),
          item == 'about'
              ? [
                  (
                    Icons.psychology_alt_outlined,
                    _t(context, 'Purpose', 'الهدف'),
                    _t(
                      context,
                      'MindSpeak is a graduation project for assistive communication. It lets a person compose a message and use the device speech engine to communicate.',
                      'MindSpeak مشروع تخرج للتواصل المساند. يتيح للمستخدم كتابة رسالة واستخدام محرك النطق في الجهاز للتواصل.',
                    ),
                  ),
                  (
                    Icons.apps_rounded,
                    _t(context, 'Project features', 'مزايا المشروع'),
                    _t(
                      context,
                      'The current app includes typed speech, saved phrases, message history, account-based preferences, and a BLE headset connection flow. EEG interpretation is not configured in this phase.',
                      'يتضمن التطبيق النطق للنصوص والعبارات المحفوظة وسجل الرسائل والإعدادات الشخصية واتصال سماعة BLE. تحليل EEG غير مهيأ في هذه المرحلة.',
                    ),
                  ),
                ]
              : [
                  (
                    Icons.info_outline_rounded,
                    _t(context, 'Project contact', 'جهة التواصل'),
                    _t(
                      context,
                      'No public email address or phone number is listed in the project files yet.',
                      'لا يوجد بريد إلكتروني أو رقم هاتف للتواصل منشور في ملفات المشروع حالياً.',
                    ),
                  ),
                ],
        ),
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'about',
            child: Text(_t(context, 'About us', 'من نحن')),
          ),
          PopupMenuItem(
            value: 'contact',
            child: Text(_t(context, 'Contact us', 'اتصل بنا')),
          ),
        ],
      ),
    ],
  );

  Future<void> _openProfile() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(
          gateway: widget.gateway,
          repository: widget.repository,
          speech: _speech,
          onLogout: widget.onLogout,
          onReconnect: _manageFromProfile,
          onCalibration: widget.onCalibration ?? () {},
        ),
      ),
    );
    if (mounted) await _loadProfile();
  }

  Widget _welcomeCard(BuildContext context) {
    final palette = MindSpeakPalette.of(context);
    final name = _profile?['name']?.toString().trim();
    // The 7-digit User ID; older servers only send the internal id.
    final id = _profile?['user_code'] ?? _profile?['id'];
    return Card(
      color: palette.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: soft,
              child: Icon(
                Icons.waving_hand_outlined,
                color: palette.primaryText,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name == null || name.isEmpty
                        ? _t(context, 'Welcome back', 'مرحباً بعودتك')
                        : '${_t(context, 'Welcome back', 'مرحباً بعودتك')}, $name',
                    style: TextStyle(
                      color: palette.primaryText,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  if (id != null)
                    Text(
                      '${_t(context, 'User ID', 'معرّف المستخدم')}: $id',
                      style: TextStyle(
                        color: palette.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openInfo(
    BuildContext context,
    String title,
    List<(IconData, String, String)> sections,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MindSpeakInfoScreen(title: title, sections: sections),
      ),
    );
  }

  Widget _buildSpeakButton() {
    final status = _speech.status;
    if (status == SpeechStatus.speaking) {
      return FilledButton.icon(
        key: const Key('stop_speech_button'),
        onPressed: _speech.stop,
        icon: const Icon(Icons.stop_rounded),
        label: Text(_t(context, 'Stop speaking', 'إيقاف النطق')),
      );
    }
    return FilledButton.icon(
      key: const Key('speak_button'),
      onPressed: status == SpeechStatus.loading ? null : _speakMessage,
      icon: status == SpeechStatus.loading
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.volume_up_rounded),
      label: Text(
        status == SpeechStatus.loading
            ? _t(context, 'Preparing speech…', 'جارٍ تجهيز النطق…')
            : _t(context, 'Speak message', 'نطق الرسالة'),
      ),
    );
  }

  Widget _customPhrase(SavedPhrase phrase) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      OutlinedButton(
        key: Key('custom_phrase_${phrase.id}'),
        onPressed: () => _selectPhrase(phrase.text),
        style: OutlinedButton.styleFrom(
          foregroundColor: muted,
          side: BorderSide(color: MindSpeakPalette.of(context).border),
          backgroundColor: soft,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        child: Text(phrase.text),
      ),
      PopupMenuButton<String>(
        tooltip: 'Edit or delete ${phrase.text}',
        onSelected: (action) {
          if (action == 'edit') _editPhrase(phrase);
          if (action == 'delete') _deletePhrase(phrase);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit phrase')),
          PopupMenuItem(value: 'delete', child: Text('Delete phrase')),
        ],
      ),
    ],
  );

  void _selectPhrase(String phrase) {
    _message.text = phrase;
    _message.selection = TextSelection.collapsed(offset: phrase.length);
    setState(() {});
  }

  Future<void> _speakMessage() => _speakText(_message.text);

  Future<void> _speakText(String text) async {
    final accepted = await _speech.speak(text);
    if (!accepted || !mounted) return;
    try {
      await widget.repository.addHistory(text.trim());
    } catch (_) {
      if (mounted)
        _showMessage(
          'Speech started, but this message could not be saved to history.',
        );
    }
  }

  Future<void> _openHistory() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MessageHistoryScreen(
          repository: widget.repository,
          onSpeak: (text) {
            Navigator.of(context).pop();
            _selectPhrase(text);
            _speakText(text);
          },
        ),
      ),
    );
  }

  void _manageFromProfile() {
    Navigator.of(context).pop();
    widget.onReconnect();
  }

  String _t(BuildContext context, String en, String ar) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

  Future<void> _addPhrase() => _editPhraseDialog();

  Future<void> _editPhrase(SavedPhrase phrase) =>
      _editPhraseDialog(phrase: phrase);

  Future<void> _editPhraseDialog({SavedPhrase? phrase}) async {
    final saved = await showDialog<String>(
      context: context,
      builder: (_) => _PhraseEditorDialog(existingPhrase: phrase?.text),
    );
    if (saved == null) return;
    try {
      final result = phrase == null
          ? await widget.repository.createPhrase(saved)
          : await widget.repository.updatePhrase(phrase.id, saved);
      if (!mounted) return;
      setState(() {
        if (phrase == null) {
          _phrases = [..._phrases, result];
        } else {
          _phrases = [
            for (final item in _phrases)
              if (item.id == phrase.id) result else item,
          ];
        }
        _phraseError = null;
      });
    } catch (error) {
      if (mounted)
        _showMessage(_errorMessage(error, 'Phrase could not be saved.'));
    }
  }

  Future<void> _deletePhrase(SavedPhrase phrase) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete saved phrase?'),
        content: Text(
          '“${phrase.text}” will be removed from your quick phrases.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.deletePhrase(phrase.id);
      if (mounted)
        setState(
          () => _phrases = _phrases
              .where((item) => item.id != phrase.id)
              .toList(),
        );
    } catch (error) {
      if (mounted)
        _showMessage(_errorMessage(error, 'Phrase could not be deleted.'));
    }
  }

  void _showMessage(String value) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));

  String _errorMessage(Object error, String fallback) =>
      error.toString().isNotEmpty ? error.toString() : fallback;
}

class MessageHistoryScreen extends StatefulWidget {
  const MessageHistoryScreen({
    required this.repository,
    required this.onSpeak,
    super.key,
  });

  final HomeRepository repository;
  final ValueChanged<String> onSpeak;

  @override
  State<MessageHistoryScreen> createState() => _MessageHistoryScreenState();
}

class _MessageHistoryScreenState extends State<MessageHistoryScreen> {
  late Future<List<SpeechHistoryEntry>> _history;

  @override
  void initState() {
    super.initState();
    _history = widget.repository.loadHistory();
  }

  @override
  Widget build(BuildContext context) => _Page(
    title: 'Message history',
    actions: [
      IconButton(
        tooltip: 'Clear history',
        onPressed: _clearHistory,
        icon: Icon(
          Icons.delete_sweep_outlined,
          color: MindSpeakPalette.of(context).primaryText,
        ),
      ),
    ],
    child: FutureBuilder<List<SpeechHistoryEntry>>(
      future: _history,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError)
          return const Center(
            child: Text('Message history could not be loaded.'),
          );
        final entries = snapshot.data ?? const <SpeechHistoryEntry>[];
        if (entries.isEmpty) {
          return const Center(
            child: Text('Your spoken messages will appear here.'),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: entries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final entry = entries[index];
            return Card(
              color: MindSpeakPalette.of(context).surface,
              child: ListTile(
                title: Text(entry.text),
                subtitle: Text(_formatTimestamp(entry.createdAt)),
                onTap: () => widget.onSpeak(entry.text),
                trailing: IconButton(
                  tooltip: 'Delete message',
                  onPressed: () => _deleteEntry(entry),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ),
            );
          },
        );
      },
    ),
  );

  Future<void> _deleteEntry(SpeechHistoryEntry entry) async {
    try {
      await widget.repository.deleteHistory(entry.id);
      if (mounted) setState(() => _history = widget.repository.loadHistory());
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('History entry could not be deleted.')),
        );
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear message history?'),
        content: const Text('This removes all of your saved message history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear history'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.clearHistory();
      if (mounted) setState(() => _history = widget.repository.loadHistory());
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('History could not be cleared.')),
        );
    }
  }
}

class _PhraseEditorDialog extends StatefulWidget {
  const _PhraseEditorDialog({this.existingPhrase});
  final String? existingPhrase;

  @override
  State<_PhraseEditorDialog> createState() => _PhraseEditorDialogState();
}

class _PhraseEditorDialogState extends State<_PhraseEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.existingPhrase ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existingPhrase == null ? 'Add a phrase' : 'Edit phrase'),
    content: Form(
      key: _formKey,
      child: TextFormField(
        controller: _controller,
        autofocus: true,
        maxLength: 100,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Phrase',
          hintText: 'Type a short message',
        ),
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Enter a phrase.'
            : value.trim().length > 100
            ? 'Keep phrases under 100 characters.'
            : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            Navigator.pop(context, _controller.text.trim());
          }
        },
        child: const Text('Save'),
      ),
    ],
  );
}

class _BluetoothStatus extends StatelessWidget {
  const _BluetoothStatus({required this.gateway, required this.onReconnect});
  final HeadsetBluetoothGateway gateway;
  final VoidCallback onReconnect;

  @override
  Widget build(BuildContext context) => StreamBuilder<HeadsetSnapshot>(
    stream: gateway.changes,
    initialData: gateway.snapshot,
    builder: (context, state) {
      final snapshot = state.data ?? gateway.snapshot;
      final connected = snapshot.isConnected;
      final device = snapshot.devices
          .where((item) => item.id == snapshot.selectedDeviceId)
          .firstOrNull;
      final palette = MindSpeakPalette.of(context);
      final arabic = Localizations.localeOf(context).languageCode == 'ar';
      return DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border),
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: soft,
            child: Icon(
              connected
                  ? Icons.bluetooth_connected_rounded
                  : Icons.bluetooth_disabled_rounded,
              color: connected ? green : navy,
            ),
          ),
          title: Text(device?.name ?? 'No headset connected'),
          subtitle: Text(
            arabic
                ? '${connected ? 'متصل عبر BLE' : 'غير متصل'} · جهاز EEG غير مهيأ'
                : '${connected ? 'BLE Connected' : 'Disconnected'} · EEG device not configured',
            style: TextStyle(color: connected ? green : muted),
          ),
          trailing: TextButton(
            onPressed: onReconnect,
            child: Text(arabic ? 'إدارة' : 'Manage'),
          ),
        ),
      );
    },
  );
}

class _QuickPhrase extends StatelessWidget {
  const _QuickPhrase({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      foregroundColor: MindSpeakPalette.of(context).secondaryText,
      side: BorderSide(color: MindSpeakPalette.of(context).border),
      backgroundColor: MindSpeakPalette.of(context).softSurface,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    child: Text(text),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: MindSpeakPalette.of(context).secondaryText,
      fontSize: 12,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _HomeWordmark extends StatelessWidget {
  const _HomeWordmark();

  @override
  Widget build(BuildContext context) {
    final palette = MindSpeakPalette.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Mind',
            style: TextStyle(
              color: palette.primaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text: 'Speak',
            style: TextStyle(color: blue, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      style: TextStyle(fontSize: 25),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({
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
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: palette.primaryText,
        title: Text(
          title,
          style: TextStyle(
            color: palette.primaryText,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: actions,
      ),
      body: WavesBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 18),
                child: SingleChildScrollView(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatTimestamp(DateTime value) {
  final local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} · ${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
