import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:salahstreaks/providers/app_provider.dart';
import 'package:salahstreaks/services/ai_bot_service.dart';
import 'package:salahstreaks/utils/app_theme.dart';
import 'package:salahstreaks/screens/settings_screen.dart';

class AiBotScreen extends StatefulWidget {
  const AiBotScreen({super.key});

  @override
  State<AiBotScreen> createState() => _AiBotScreenState();
}

class _AiBotScreenState extends State<AiBotScreen> {
  final AiBotService _bot = AiBotService();
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<AiBotMessage> _messages = [];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _messages.add(AiBotMessage(
      role: 'assistant',
      content:
          'Assalamu alaikum. I am your SalahStreaks assistant.\n\n'
          'Ask about salah, Quran, streaks, or daily ibadat.\n'
          'Quick actions below work offline; full AI replies need your free API key in Settings.',
    ));
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  bool _needsMo11Support(String text) {
    final q = text.toLowerCase();
    const patterns = [
      'who developed',
      'who built',
      'who created',
      'who made you',
      'who made this app',
      'who developed this app',
      'who built this app',
      'who created this app',
      'who is the developer',
      'developer of the app',
      'app developer',
      'source code',
      'programmer',
      'developer information',
      'technical support',
      'technical assistance',
      'further assistance',
      'contact the developer',
      'contact developer',
      'report a bug',
      'report an issue',
      'app bug',
      'app issue',
      'technical issue',
      'how was this app built',
      'how was the app built',
    ];
    return patterns.any(q.contains);
  }

  String _mo11SupportMessage() =>
      'MO11 developed and supports SalahStreaks.\n\n'
      'For further assistance, technical support, or questions about the app, '
      'please contact MO11 at +255 677 532 140.';

  bool _looksLikeUnknownAnswer(String text) {
    final q = text.toLowerCase().trim();
    const phrases = [
      'i don\'t know',
      'i do not know',
      'i\'m not sure',
      'i am not sure',
      'i cannot answer',
      'i can\'t answer',
      'i cannot reliably answer',
      'i can\'t reliably answer',
      'i don\'t have enough information',
      'i do not have enough information',
      'i\'m unable to answer',
      'i am unable to answer',
    ];
    return phrases.any(q.contains);
  }

  String _formatAssistantText(String text) {
    // AI providers sometimes ignore the no-table instruction. Convert any
    // Markdown/pipe table into a phone-friendly list before displaying it.
    final lines = text.replaceAll('\r\n', '\n').split('\n');
    final output = <String>[];
    var i = 0;
    while (i < lines.length) {
      final line = lines[i].trim();
      final next = i + 1 < lines.length ? lines[i + 1].trim() : '';
      final looksLikeTable = line.contains('|') &&
          next.contains('|') &&
          RegExp(r'^\|?\s*:?-{2,}').hasMatch(next);

      if (looksLikeTable) {
        final headers = _splitTableRow(line);
        i += 2;
        output.add('');
        while (i < lines.length && lines[i].contains('|')) {
          final cells = _splitTableRow(lines[i]);
          if (cells.isNotEmpty) {
            if (headers.isNotEmpty && cells.length == headers.length) {
              for (var c = 0; c < cells.length; c++) {
                final value = cells[c].trim();
                if (value.isEmpty) continue;
                output.add('• ${headers[c].trim()}: $value');
              }
            } else {
              output.add('• ${cells.where((e) => e.trim().isNotEmpty).join(' — ')}');
            }
            output.add('');
          }
          i++;
        }
        continue;
      }

      // Remove accidental table separator rows even when the provider emits
      // them without a clean header immediately before.
      if (line.contains('|') &&
          RegExp(r'^\|?\s*:?-{2,}(\s*\|\s*:?-{2,})+\s*\|?$')
              .hasMatch(line)) {
        i++;
        continue;
      }

      // Also handle provider output that uses pipes without the Markdown
      // separator row. Never expose raw table syntax to the user.
      if (line.split('|').length >= 3) {
        final cells = _splitTableRow(line)
            .where((e) => e.trim().isNotEmpty)
            .toList();
        if (cells.isNotEmpty) {
          output.add('• ${cells.join(' — ')}');
          i++;
          continue;
        }
      }

      output.add(lines[i]);
      i++;
    }

    return output.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  List<String> _splitTableRow(String line) {
    var value = line.trim();
    if (value.startsWith('|')) value = value.substring(1);
    if (value.endsWith('|')) value = value.substring(0, value.length - 1);
    return value.split('|').map((e) => e.trim()).toList();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _busy) return;

    final provider = Provider.of<AppProvider>(context, listen: false);
    final settings = provider.settings;

    setState(() {
      _error = null;
      _messages.add(AiBotMessage(role: 'user', content: text));
      _busy = true;
      if (preset == null) _input.clear();
    });
    _scrollToEnd();

    if (_needsMo11Support(text)) {
      setState(() {
        _messages.add(AiBotMessage(
          role: 'assistant',
          content: _mo11SupportMessage(),
        ));
        _busy = false;
      });
      _scrollToEnd();
      return;
    }

    // Offline shortcuts — no key, no network required.
    if (text.toLowerCase().contains('daily verse') ||
        text.toLowerCase() == 'verse') {
      final verse = _bot.localDailyVerse();
      setState(() {
        _messages.add(AiBotMessage(
          role: 'assistant',
          content: '📖 Today’s verse (offline):\n\n$verse',
        ));
        _busy = false;
      });
      _scrollToEnd();
      return;
    }
    if (text.toLowerCase().contains('reminder tip') ||
        text.toLowerCase() == 'reminder') {
      setState(() {
        _messages.add(AiBotMessage(
          role: 'assistant',
          content: '🔔 ${_bot.localReminderSuggestion()}',
        ));
        _busy = false;
      });
      _scrollToEnd();
      return;
    }

    if (!settings.aiBotEnabled || settings.aiApiKey.trim().isEmpty) {
      setState(() {
        _messages.add(AiBotMessage(
          role: 'assistant',
          content:
              'AI chat is off or no API key is set.\n\n'
              'Open Settings → AI Bot, turn it on, and paste a free-tier key '
              '(Groq / Gemini / xAI / OpenAI-compatible). '
              'The key stays on this phone only — no SalahStreaks server.',
        ));
        _busy = false;
      });
      _scrollToEnd();
      return;
    }

    try {
      final history = _messages
          .where((m) => m.role == 'user' || m.role == 'assistant')
          .toList();
      // Drop the long welcome from the payload if present as first assistant msg
      if (history.isNotEmpty &&
          history.first.role == 'assistant' &&
          history.first.content.startsWith('Assalamu alaikum')) {
        history.removeAt(0);
      }

      final reply = await _bot.chat(
        apiKey: settings.aiApiKey,
        provider: AiProviderX.fromId(settings.aiProvider),
        history: history,
        customBaseUrl: settings.aiBaseUrl,
        customModel: settings.aiModel.isEmpty ? null : settings.aiModel,
      );

      if (!mounted) return;
      final cleanReply = _formatAssistantText(reply);
      setState(() {
        _messages.add(AiBotMessage(
          role: 'assistant',
          content: _looksLikeUnknownAnswer(cleanReply)
              ? _mo11SupportMessage()
              : cleanReply,
        ));
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _messages.add(AiBotMessage(
          role: 'assistant',
          content: '⚠️ Could not reach the AI provider.\n$_error',
        ));
        _busy = false;
      });
    }
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppProvider>(context).settings;
    final keyReady =
        settings.aiBotEnabled && settings.aiApiKey.trim().isNotEmpty;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppThemeColors.pageGradientSimple(context),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back,
                          color: AppThemeColors.icon(context)),
                    ),
                    Expanded(
                      child: Text(
                        '🤖 SalahStreaks Bot',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppThemeColors.textPrimary(context),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'AI settings',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      },
                      icon: Icon(Icons.vpn_key_outlined,
                          color: keyReady ? Colors.green : Colors.orange),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: keyReady
                        ? AppThemeColors.panelFill(context, 0.15)
                        : Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: keyReady
                          ? AppThemeColors.cardBorder(context)
                          : Colors.orange.withOpacity(0.4),
                    ),
                  ),
                  child: Text(
                    keyReady
                        ? 'Serverless · Provider: ${AiProviderX.fromId(settings.aiProvider).label} · Key on this device only'
                        : 'Add a free API key in Settings to enable live AI answers. Offline verse & reminder tips still work.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppThemeColors.textSecondary(context),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    _chip('📖 Daily verse', () => _send('Daily verse')),
                    _chip('🔔 Reminder tip', () => _send('Reminder tip')),
                    _chip('🕌 How to stay consistent?',
                        () => _send('How can I stay consistent with all 5 prayers?')),
                    _chip('📿 Short adhkar ideas',
                        () => _send('Suggest short morning and evening adhkar.')),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _messages.length + (_busy ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_busy && index == _messages.length) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Thinking…',
                            style: TextStyle(
                              color: AppThemeColors.textHint(context),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      );
                    }
                    final m = _messages[index];
                    final isUser = m.role == 'user';
                    return Align(
                      alignment:
                          isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.85,
                        ),
                        decoration: BoxDecoration(
                          color: isUser
                              ? Colors.green.withOpacity(0.25)
                              : AppThemeColors.panelFill(context, 0.2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppThemeColors.cardBorder(context),
                          ),
                        ),
                        child: SelectableText(
                          m.content,
                          style: TextStyle(
                            color: AppThemeColors.textPrimary(context),
                            height: 1.35,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        style: TextStyle(
                          color: AppThemeColors.textPrimary(context),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Ask anything…',
                          hintStyle: TextStyle(
                            color: AppThemeColors.textHint(context),
                          ),
                          filled: true,
                          fillColor: AppThemeColors.inputFill(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _busy ? null : () => _send(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.green[700],
                      ),
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onPressed: _busy ? null : onTap,
        backgroundColor: AppThemeColors.panelFill(context, 0.2),
        side: BorderSide(color: AppThemeColors.cardBorder(context)),
      ),
    );
  }
}
