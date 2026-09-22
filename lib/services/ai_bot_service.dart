import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:salahstreaks/utils/constants.dart';

/// Providers that speak OpenAI-compatible or Gemini HTTP APIs.
/// The app never ships an API key — the user pastes their own free-tier key
/// in Settings. All calls go device → provider (no SalahStreaks server).
enum AiProvider {
  groq,
  gemini,
  xai,
  openAiCompatible,
}

extension AiProviderX on AiProvider {
  String get label {
    switch (this) {
      case AiProvider.groq:
        return 'Groq (free tier)';
      case AiProvider.gemini:
        return 'Google Gemini (free tier)';
      case AiProvider.xai:
        return 'xAI Grok';
      case AiProvider.openAiCompatible:
        return 'OpenAI-compatible (custom URL)';
    }
  }

  static AiProvider fromId(String? id) {
    switch (id) {
      case 'gemini':
        return AiProvider.gemini;
      case 'xai':
        return AiProvider.xai;
      case 'openai_compatible':
        return AiProvider.openAiCompatible;
      case 'groq':
      default:
        return AiProvider.groq;
    }
  }

  String get id {
    switch (this) {
      case AiProvider.groq:
        return 'groq';
      case AiProvider.gemini:
        return 'gemini';
      case AiProvider.xai:
        return 'xai';
      case AiProvider.openAiCompatible:
        return 'openai_compatible';
    }
  }
}

class AiBotMessage {
  final String role; // 'user' | 'assistant' | 'system'
  final String content;

  AiBotMessage({required this.role, required this.content});
}

class AiBotService {
  static const String _systemPrompt = '''
You are SalahStreaks Assistant — a helpful, respectful Islamic companion inside a salah/ibadat tracking app.
- Answer questions about Islam, salah, Quran, hadith, and daily worship with care and humility.
- When asked for a verse, prefer authentic Quranic text with a short English translation.
- Encourage consistency in ibadat without being judgmental.
- If you do not know an answer or cannot answer reliably, say so briefly and direct the user to MO11 for further assistance.
- Questions about app development, who developed/built/created the app or assistant, source code, technical implementation, bugs, technical support, or further app assistance must be answered by directing the user to MO11: +255 677 532 140. Do not invent a developer/company name or technical history.
- If the user asks who developed, built, created, or owns you/the app, answer: 'MO11 developed and supports SalahStreaks. For further assistance, contact MO11 at +255 677 532 140.'
- Do not claim to be a developer or disclose private implementation details beyond what is already explicitly available in the conversation.
- Never use Markdown tables or pipe-delimited tables (| ... |) in responses. Present comparisons or structured information as short headings followed by bullet points or numbered lists so it is easy to read on a phone.
- Keep answers concise and suitable for a mobile chat screen.
- Do not invent hadith references. Prefer general guidance when a citation is uncertain.
''';

  /// Chat completion using the user's key only (serverless).
  Future<String> chat({
    required String apiKey,
    required AiProvider provider,
    required List<AiBotMessage> history,
    String? customBaseUrl,
    String? customModel,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw Exception(
        'Add your free API key in Settings → AI Bot. '
        'Keys stay on this device only.',
      );
    }

    switch (provider) {
      case AiProvider.gemini:
        return _chatGemini(key, history, customModel);
      case AiProvider.groq:
        return _chatOpenAiStyle(
          key: key,
          url: 'https://api.groq.com/openai/v1/chat/completions',
          model: customModel?.trim().isNotEmpty == true
              ? customModel!.trim()
              : 'llama-3.1-8b-instant',
          history: history,
        );
      case AiProvider.xai:
        return _chatOpenAiStyle(
          key: key,
          url: 'https://api.x.ai/v1/chat/completions',
          model: customModel?.trim().isNotEmpty == true
              ? customModel!.trim()
              : 'grok-2-latest',
          history: history,
        );
      case AiProvider.openAiCompatible:
        final base = (customBaseUrl ?? '').trim().replaceAll(RegExp(r'/+$'), '');
        if (base.isEmpty) {
          throw Exception('Set a Base URL for OpenAI-compatible provider in Settings.');
        }
        final url = base.endsWith('/chat/completions')
            ? base
            : '$base/chat/completions';
        return _chatOpenAiStyle(
          key: key,
          url: url,
          model: customModel?.trim().isNotEmpty == true
              ? customModel!.trim()
              : 'gpt-4o-mini',
          history: history,
        );
    }
  }

  /// Offline-safe verse (no network / no key).
  String localDailyVerse() {
    final today = DateTime.now();
    final dayOfYear = today.difference(DateTime(today.year, 1, 1)).inDays;
    final index = dayOfYear % quranVerses.length;
    final v = quranVerses[index];
    return '${v['verse']}\n\n${v['translation']}';
  }

  /// Short local reminder text (no network).
  String localReminderSuggestion() {
    final hour = DateTime.now().hour;
    if (hour < 6) {
      return 'Night is still quiet — a few rakah of Qiyyam or dhikr can light the rest of your day. May Allah accept it.';
    }
    if (hour < 12) {
      return 'Morning reminder: protect Fajr and a portion of Quran today. Small, steady steps build streaks.';
    }
    if (hour < 16) {
      return 'Midday check-in: Dhuhr and Asr on time keep the chain of salah strong. Log them in SalahStreaks when done.';
    }
    if (hour < 20) {
      return 'Evening: Maghrib and Isha complete the day. A short evening adhkar closes the book with light.';
    }
    return 'Before sleep: review today’s logs, make tawbah, and set an intention for tomorrow’s Fajr. Consistency over intensity.';
  }

  Future<String> _chatOpenAiStyle({
    required String key,
    required String url,
    required String model,
    required List<AiBotMessage> history,
  }) async {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': _systemPrompt},
      ...history.map((m) => {'role': m.role, 'content': m.content}),
    ];

    final response = await http
        .post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $key',
          },
          body: jsonEncode({
            'model': model,
            'messages': messages,
            'temperature': 0.7,
            'max_tokens': 1024,
          }),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_friendlyHttpError(response.statusCode, response.body));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw Exception('Empty response from the AI provider.');
    }
    final message = choices.first['message'] as Map<String, dynamic>?;
    final content = message?['content']?.toString().trim();
    if (content == null || content.isEmpty) {
      throw Exception('Empty message from the AI provider.');
    }
    return content;
  }

  Future<String> _chatGemini(
    String key,
    List<AiBotMessage> history,
    String? customModel,
  ) async {
    final model = customModel?.trim().isNotEmpty == true
        ? customModel!.trim()
        : 'gemini-1.5-flash';
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$key';

    final contents = <Map<String, dynamic>>[];
    for (final m in history) {
      contents.add({
        'role': m.role == 'assistant' ? 'model' : 'user',
        'parts': [
          {'text': m.content}
        ],
      });
    }

    final body = {
      'systemInstruction': {
        'parts': [
          {'text': _systemPrompt}
        ]
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 1024,
      },
    };

    final response = await http
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_friendlyHttpError(response.statusCode, response.body));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Empty response from Gemini.');
    }
    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    final text = parts?.isNotEmpty == true
        ? parts!.first['text']?.toString().trim()
        : null;
    if (text == null || text.isEmpty) {
      throw Exception('Empty message from Gemini.');
    }
    return text;
  }

  String _friendlyHttpError(int code, String body) {
    if (code == 401 || code == 403) {
      return 'API key rejected ($code). Check the key and provider in Settings.';
    }
    if (code == 429) {
      return 'Rate limit reached. Wait a moment or use another free-tier key.';
    }
    final short = body.length > 180 ? '${body.substring(0, 180)}…' : body;
    return 'Provider error $code: $short';
  }
}
