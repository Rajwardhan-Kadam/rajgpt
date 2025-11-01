import 'dart:convert';
import 'dart:io';

import 'package:raj_gpt/secrets.dart';
import 'package:http/http.dart' as http;

class OpenAIService {
  final List<Map<String, String>> messages = [];

  Future<String> isArtPromptAPI(String prompt) async {
    try {
      final res = await http
          .post(
            Uri.parse('https://api.openai.com/v1/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $openAIAPIKey',
            },
            body: jsonEncode({
              "model": "gpt-4o-mini",
              "messages": [
                {
                  'role': 'user',
                  'content':
                      'Does this message want to generate an AI picture, image, art or anything similar? $prompt . Simply answer with a yes or no.',
                }
              ],
            }),
          )
          .timeout(const Duration(seconds: 25));

      // Always surface error
      if (res.statusCode != 200) {
        // This is what your UI will show if classify fails (wrong key/billing/etc.)
        return "Classify error: ${res.statusCode} ${res.body}";
      }

      String content =
          (jsonDecode(res.body)['choices'][0]['message']['content'] as String)
              .trim();

      switch (content) {
        case 'Yes':
        case 'yes':
        case 'Yes.':
        case 'yes.':
          return await dallEAPI(prompt);
        default:
          return await chatGPTAPI(prompt);
      }
    } on SocketException catch (e) {
      return "Network error: $e";
    } on HttpException catch (e) {
      return "HTTP error: $e";
    } on FormatException catch (e) {
      return "Response parse error: $e";
    } catch (e) {
      return "Exception during classify: $e";
    }
  }

  Future<String> chatGPTAPI(String prompt) async {
    messages.add({'role': 'user', 'content': prompt});
    try {
      final res = await http
          .post(
            Uri.parse('https://api.openai.com/v1/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $openAIAPIKey',
            },
            body: jsonEncode({
              "model": "gpt-4o-mini", // <- make sure it's FOUR-O, not forty
              "messages": messages,
              "temperature": 0.7,
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (res.statusCode != 200) {
        // Return the actual API error so it shows in your bubble
        return "Chat error: ${res.statusCode} ${res.body}";
      }

      String content =
          (jsonDecode(res.body)['choices'][0]['message']['content'] as String)
              .trim();

      messages.add({'role': 'assistant', 'content': content});
      return content;
    } on SocketException catch (e) {
      return "Network error: $e";
    } on HttpException catch (e) {
      return "HTTP error: $e";
    } on FormatException catch (e) {
      return "Response parse error: $e";
    } catch (e) {
      return "Exception during chat: $e";
    }
  }

  Future<String> dallEAPI(String prompt) async {
    try {
      final res = await http
          .post(
            Uri.parse('https://api.openai.com/v1/images/generations'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $openAIAPIKey',
            },
            body: jsonEncode({
              "model": "gpt-image-1", // REQUIRED
              "prompt": prompt,
              "n": 1,
              "size": "1024x1024"
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode != 200) {
        return "Image error: ${res.statusCode} ${res.body}";
      }

      String imageUrl = (jsonDecode(res.body)['data'][0]['url'] as String).trim();
      messages.add({'role': 'assistant', 'content': imageUrl});
      return imageUrl;
    } on SocketException catch (e) {
      return "Network error: $e";
    } on HttpException catch (e) {
      return "HTTP error: $e";
    } on FormatException catch (e) {
      return "Response parse error: $e";
    } catch (e) {
      return "Exception during image generation: $e";
    }
  }
}
