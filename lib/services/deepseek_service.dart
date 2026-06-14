import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class DeepSeekService {
  final String _baseUrl = 'https://api.deepseek.com/v1/chat/completions';
  String _token = '';

  void setToken(String token) => _token = token;
  bool get hasToken => _token.isNotEmpty;

  Stream<String> chat({
    required List<Map<String, String>> messages,
    String model = 'deepseek-chat',
  }) async* {
    if (!hasToken) {
      yield '⚠ DEEPSEEK_TOKEN not set. Add it in Settings.';
      return;
    }

    try {
      final body = jsonEncode({
        'model': model,
        'messages': [
          {
            'role': 'system',
            'content': 'You are Pau Agent, an AI coding assistant running on Android. '
                'You help the user edit code, manage git repos, and build Flutter apps. '
                'When suggesting code changes, show the exact file path and full file content. '
                'Keep responses practical — the user is on a phone and needs concise answers.'
          },
          ...messages,
        ],
        'stream': true,
        'max_tokens': 8192,
        'temperature': 0.3,
      });

      final request = http.Request('POST', Uri.parse(_baseUrl))
        ..headers['Content-Type'] = 'application/json'
        ..headers['Authorization'] = 'Bearer $_token'
        ..body = body;

      final response = await request.send().timeout(const Duration(seconds: 120));

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        for (final line in chunk.split('\n')) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6).trim();
            if (data == '[DONE]') return;
            try {
              final json = jsonDecode(data);
              final content = json['choices']?[0]?['delta']?['content'] as String?;
              if (content != null) yield content;
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      yield '\n\n[Error: $e]';
    }
  }
}
