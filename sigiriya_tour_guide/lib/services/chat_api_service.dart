import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';

/// API Service class for handling chat backend communication.
///
/// This service is responsible for making HTTP requests to the
/// Railway-deployed AI chatbot backend and parsing responses.
class ChatApiService {
  /// Production Railway API endpoint
  static const String _baseUrl =
      'https://web-production-deab8.up.railway.app';

  /// Timeout duration for API calls (20 seconds)
  static const Duration _timeout = Duration(seconds: 20);

  final http.Client _client;

  ChatApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Sends a chat message to the backend and returns the AI response.
  ///
  /// [location] - The name of the tourist attraction
  /// [userQuery] - The user's question about the location
  ///
  /// Returns a [ChatResponse] with the AI's answer.
  /// Throws [ChatApiException] on failure.
  Future<ChatResponse> sendMessage({
    required String location,
    required String userQuery,
  }) async {
    final request = ChatRequest(
      location: location,
      userQuery: userQuery,
    );

    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl/chat'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode(request.toJson()),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return ChatResponse.fromJson(jsonData);
      } else if (response.statusCode == 404) {
        throw ChatApiException(
          'Location not found. Please try another attraction.',
          code: response.statusCode,
        );
      } else if (response.statusCode >= 500) {
        throw ChatApiException(
          'Server is currently unavailable. Please try again later.',
          code: response.statusCode,
        );
      } else {
        throw ChatApiException(
          'Something went wrong. Please try again.',
          code: response.statusCode,
        );
      }
    } on SocketException {
      throw ChatApiException(
        'No internet connection. Please check your network and try again.',
        code: -1,
      );
    } on TimeoutException {
      throw ChatApiException(
        'Request timed out. The server took too long to respond. Please try again.',
        code: -2,
      );
    } on FormatException {
      throw ChatApiException(
        'Something went wrong. Please try again.',
        code: -3,
      );
    } catch (e) {
      if (e is ChatApiException) rethrow;
      throw ChatApiException(
        'Something went wrong. Please try again.',
        code: -4,
      );
    }
  }

  /// Dispose of resources
  void dispose() {
    _client.close();
  }
}

/// Custom exception for Chat API errors
class ChatApiException implements Exception {
  final String message;
  final int code;

  const ChatApiException(this.message, {this.code = 0});

  @override
  String toString() => 'ChatApiException: $message (code: $code)';
}
