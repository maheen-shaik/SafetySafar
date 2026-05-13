import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LLMChatbotService {
  static const String _groqApiKey = 'gsk_YOUR_GROQ_API_KEY_HERE'; // Replace with your key from console.groq.com

  static const String _huggingFaceKey = 'hf_FKvzPqRstuVwXyZaBcDeFgHiJkLmNoPq';
  static const String _huggingFaceUrl =
      'https://api-inference.huggingface.co/models/mistralai/Mistral-7B-Instruct-v0.1';

  static const Duration _timeout = Duration(seconds: 15);

  static Future<String> chat({
    required String userMessage,
    required String context,
  }) async {
    debugPrint('\n========== CHAT START ==========');
    debugPrint('📝 Message: "$userMessage"');

    try {
      debugPrint('🔄 Trying Groq...');
      final groqResponse = await _callGroqAPI(userMessage, context);

      if (groqResponse.isNotEmpty) {
        debugPrint('✅ Groq SUCCESS');
        return groqResponse;
      }

      debugPrint('⚠️ Groq failed, trying HF...');
      final hfResponse = await _callHuggingFaceAPI(userMessage, context);

      if (hfResponse.isNotEmpty) {
        debugPrint('✅ HF SUCCESS');
        return hfResponse;
      }

      debugPrint('❌ All APIs failed');
      return "❌ AI service error. Restart app or try Groq key setup.";
    } catch (e) {
      debugPrint('💥 CHAT Exception: $e');
      return "Error: ${e.toString()}";
    }
  }

  static Future<String> _callGroqAPI(String userMessage, String context) async {
    try {
      final payload = {
        'model': 'llama-3.1-8b-instant',
        'messages': [
          {
            'role': 'system',
            'content': 'You are SafetySafar safety assistant. Answer in 1-2 sentences.',
          },
          {'role': 'user', 'content': userMessage},
        ],
        'temperature': 0.7,
        'max_tokens': 150,
      };

      final response = await http
          .post(
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
            headers: {
              'Authorization': 'Bearer $_groqApiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('  [Groq] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        debugPrint('  [Groq] ✅ Got response: ${content.length} chars');
        return content;
      } else {
        debugPrint('  [Groq] ❌ HTTP ${response.statusCode}: ${response.body}');
        return '';
      }
    } catch (e) {
      debugPrint('  [Groq] ❌ Exception: $e');
      return '';
    }
  }

  static Future<String> _callHuggingFaceAPI(String userMessage, String context) async {
    try {
      final prompt = '''SafetySafar Safety Assistant

Context: $context

User Question: $userMessage

Respond with safety advice for tourists in India. Be concise and actionable.

Response:''';

      final response = await http
          .post(
            Uri.parse(_huggingFaceUrl),
            headers: {
              'Authorization': 'Bearer $_huggingFaceKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'inputs': prompt,
              'parameters': {'max_length': 500, 'temperature': 0.7},
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          return data[0]['generated_text']?.replaceFirst(prompt, '').trim() ?? '';
        }
      }
      return '';
    } catch (e) {
      debugPrint('Hugging Face Error: $e');
      return '';
    }
  }

  static Future<String> testGroqConnection() async {
    try {
      final response = await http
          .post(
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
            headers: {
              'Authorization': 'Bearer $_groqApiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': 'llama-3.1-8b-instant',
              'messages': [
                {'role': 'user', 'content': 'Say "OK" only'},
              ],
              'max_tokens': 10,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'] ?? '';
        return 'SUCCESS: $content';
      } else if (response.statusCode == 401) {
        return 'ERROR 401: Invalid API Key';
      } else if (response.statusCode == 429) {
        return 'ERROR 429: Rate limited - Try again later';
      } else {
        return 'ERROR ${response.statusCode}: ${response.body}';
      }
    } catch (e) {
      return 'EXCEPTION: $e';
    }
  }

  static bool isConfigured() {
    return _groqApiKey.startsWith('gsk_') &&
        _groqApiKey != 'gsk_YOUR_GROQ_API_KEY_HERE';
  }

  static String getSetupInstructions() {
    return '''To enable AI Assistant:

1. Go to https://console.groq.com/keys
2. Create a free account
3. Copy your API Key
4. Edit lib/services/llm_chatbot_service.dart
5. Replace _groqApiKey with your actual key''';
  }
}
