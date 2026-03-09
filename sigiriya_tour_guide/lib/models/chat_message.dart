/// Model class representing a chat message in the AI chatbot.
/// 
/// This follows clean architecture principles by separating
/// data representation from business logic.
class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;
  final bool isLoading;

  const ChatMessage({
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
    this.isLoading = false,
  });

  /// Factory constructor for user messages
  factory ChatMessage.user(String content) {
    return ChatMessage(
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
    );
  }

  /// Factory constructor for AI responses
  factory ChatMessage.ai(String content) {
    return ChatMessage(
      content: content,
      isUser: false,
      timestamp: DateTime.now(),
    );
  }

  /// Factory constructor for error messages
  factory ChatMessage.error(String content) {
    return ChatMessage(
      content: content,
      isUser: false,
      timestamp: DateTime.now(),
      isError: true,
    );
  }

  /// Factory constructor for loading placeholder
  factory ChatMessage.loading() {
    return ChatMessage(
      content: '',
      isUser: false,
      timestamp: DateTime.now(),
      isLoading: true,
    );
  }

  /// Create a copy with modified fields
  ChatMessage copyWith({
    String? content,
    bool? isUser,
    DateTime? timestamp,
    bool? isError,
    bool? isLoading,
  }) {
    return ChatMessage(
      content: content ?? this.content,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      isError: isError ?? this.isError,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Model for API request payload
class ChatRequest {
  final String location;
  final String userQuery;

  const ChatRequest({
    required this.location,
    required this.userQuery,
  });

  Map<String, dynamic> toJson() => {
    'location': location,
    'user_query': userQuery,
  };
}

/// Model for API response payload
class ChatResponse {
  final String response;

  const ChatResponse({
    required this.response,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    return ChatResponse(
      response: json['response'] ?? '',
    );
  }
}
