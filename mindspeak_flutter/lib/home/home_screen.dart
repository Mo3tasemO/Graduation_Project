import 'package:flutter/material.dart';

import '../design_tokens.dart';
import '../bluetooth/headset_bluetooth.dart';
import 'home_repository.dart';
import 'speech_controller.dart';

const _quickPhrases = ['I need help', 'I am thirsty', 'Yes', 'No'];

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.gateway,
    required this.onLogout,
    required this.onReconnect,
    this.repository = const ApiHomeRepository(),
    this.speechEngine,
    super.key,
  });

  final HeadsetBluetoothGateway gateway;
  final VoidCallback onLogout;
  final VoidCallback onReconnect;
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

  @override
  void initState() {
    super.initState();
    _speech = SpeechController(engine: widget.speechEngine);
    _speech.addListener(_speechChanged);
    _loadPhrases();
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
    backgroundColor: bg,
    body: SafeArea(
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
                  const SizedBox(height: 18),
                  _BluetoothStatus(
                    gateway: widget.gateway,
                    onReconnect: widget.onReconnect,
                  ),
                  const SizedBox(height: 22),
                  const _SectionLabel('YOUR MESSAGE'),
                  const SizedBox(height: 9),
                  TextField(
                    key: const Key('home_message_field'),
                    controller: _message,
                    minLines: 2,
                    maxLines: 5,
                    maxLength: 500,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: 'Type a message to speak',
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
                  const _SectionLabel('QUICK PHRASES'),
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
                        label: const Text('Add phrase'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: muted,
                          side: const BorderSide(color: line),
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
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ],
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
        tooltip: 'Message history',
        onPressed: _openHistory,
        icon: const Icon(Icons.history_rounded, color: navy),
      ),
      IconButton(
        key: const Key('profile_button'),
        tooltip: 'Profile and settings',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ProfileSettingsScreen(
              gateway: widget.gateway,
              repository: widget.repository,
              speech: _speech,
              onLogout: widget.onLogout,
              onReconnect: _manageFromProfile,
            ),
          ),
        ),
        icon: const Icon(Icons.person_outline_rounded, color: navy),
      ),
    ],
  );

  Widget _buildSpeakButton() {
    final status = _speech.status;
    if (status == SpeechStatus.speaking) {
      return FilledButton.icon(
        key: const Key('stop_speech_button'),
        onPressed: _speech.stop,
        icon: const Icon(Icons.stop_rounded),
        label: const Text('Stop speaking'),
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
        status == SpeechStatus.loading ? 'Preparing speech…' : 'Speak message',
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
          side: const BorderSide(color: line),
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
        icon: const Icon(Icons.delete_sweep_outlined, color: navy),
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
              color: Colors.white,
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

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({
    required this.gateway,
    required this.repository,
    required this.speech,
    required this.onLogout,
    required this.onReconnect,
    super.key,
  });

  final HeadsetBluetoothGateway gateway;
  final HomeRepository repository;
  final SpeechController speech;
  final VoidCallback onLogout;
  final VoidCallback onReconnect;

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.speech.addListener(_speechChanged);
    _load();
  }

  @override
  void dispose() {
    widget.speech.removeListener(_speechChanged);
    super.dispose();
  }

  void _speechChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        widget.repository.loadProfile(),
        widget.repository.loadPreferences(),
      ]);
      await widget.speech.initialize();
      await widget.speech.applyPreferences(values[1]);
      if (mounted) setState(() => _profile = values[0]);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.repository.savePreferences({
        'language': widget.speech.language,
        'voice_name': widget.speech.voice?.name,
        'voice_locale': widget.speech.voice?.locale,
        'rate': widget.speech.rate,
        'volume': widget.speech.volume,
      });
      if (mounted) {
        setState(() => _error = null);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Speech settings saved.')));
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => _Page(
    title: 'Profile & Settings',
    child: _loading
        ? const Center(child: CircularProgressIndicator())
        : _profile == null
        ? Center(child: Text(_error ?? 'Profile could not be loaded.'))
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: Colors.white,
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: soft,
                    child: Icon(Icons.person_outline, color: navy),
                  ),
                  title: Text(
                    _profile?['name']?.toString() ?? 'MindSpeak user',
                  ),
                  subtitle: Text(
                    '${_profile?['email'] ?? ''}\n${_profile?['email_verified_at'] == null ? 'Email not verified' : 'Email verified'}',
                  ),
                  isThreeLine: true,
                ),
              ),
              const SizedBox(height: 18),
              const _SectionLabel('SPEECH LANGUAGE'),
              const SizedBox(height: 6),
              if (widget.speech.languages.isEmpty)
                const Text(
                  'The device will use its default speech language.',
                  style: TextStyle(color: muted),
                )
              else
                DropdownButtonFormField<String>(
                  key: const Key('speech_language_dropdown'),
                  initialValue:
                      widget.speech.languages.contains(widget.speech.language)
                      ? widget.speech.language
                      : widget.speech.languages.first,
                  items: [
                    for (final language in widget.speech.languages)
                      DropdownMenuItem(value: language, child: Text(language)),
                  ],
                  onChanged: (value) => value == null
                      ? null
                      : _change(() => widget.speech.updateLanguage(value)),
                  decoration: const InputDecoration(
                    labelText: 'Available language',
                  ),
                ),
              const SizedBox(height: 14),
              const _SectionLabel('AVAILABLE VOICE'),
              const SizedBox(height: 6),
              if (widget.speech.voices.isEmpty)
                const Text(
                  'No selectable system voices were reported by this device.',
                  style: TextStyle(color: muted),
                )
              else
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
                  onChanged: (value) =>
                      _change(() => widget.speech.updateVoice(value)),
                  decoration: const InputDecoration(labelText: 'System voice'),
                ),
              const SizedBox(height: 14),
              _SliderSetting(
                label: 'Speech speed',
                value: widget.speech.rate,
                min: 0.1,
                max: 1,
                onChanged: (value) => widget.speech.updateRate(value),
              ),
              _SliderSetting(
                label: 'Volume',
                value: widget.speech.volume,
                min: 0,
                max: 1,
                onChanged: (value) => widget.speech.updateVolume(value),
              ),
              const SizedBox(height: 12),
              const _SectionLabel('BLUETOOTH'),
              const SizedBox(height: 6),
              _BluetoothStatus(
                gateway: widget.gateway,
                onReconnect: widget.onReconnect,
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'BLE connection and EEG device readiness are separate. EEG integration is not configured in this phase.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('save_settings_button'),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Save speech settings'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('logout_button'),
                onPressed: widget.onLogout,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Log out'),
              ),
            ],
          ),
  );

  Future<void> _change(Future<void> Function() update) async {
    await update();
    if (mounted) setState(() {});
  }
}

class _SliderSetting extends StatelessWidget {
  const _SliderSetting({
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
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: navy, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '${(value * 100).round()}%',
            style: const TextStyle(color: muted),
          ),
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
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: line),
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
            '${connected ? 'BLE Connected' : 'Disconnected'} · EEG device not configured',
            style: TextStyle(color: connected ? green : muted),
          ),
          trailing: TextButton(
            onPressed: onReconnect,
            child: const Text('Manage'),
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
      foregroundColor: muted,
      side: const BorderSide(color: line),
      backgroundColor: soft,
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
    style: const TextStyle(
      color: muted,
      fontSize: 12,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _HomeWordmark extends StatelessWidget {
  const _HomeWordmark();

  @override
  Widget build(BuildContext context) => const Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: 'Mind',
          style: TextStyle(color: navy, fontWeight: FontWeight.w700),
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: bg,
    appBar: AppBar(
      backgroundColor: bg,
      foregroundColor: navy,
      title: Text(
        title,
        style: const TextStyle(color: navy, fontWeight: FontWeight.w700),
      ),
      actions: actions,
    ),
    body: SafeArea(
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
  );
}

String _formatTimestamp(DateTime value) {
  final local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} · ${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
