import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';
import '../services/chat_api_service.dart';

/// Provider for managing chat state using ChangeNotifier.
/// 
/// This provider follows clean architecture by:
/// - Separating state management from UI
/// - Handling business logic for chat operations
/// - Managing loading and error states
class ChatProvider extends ChangeNotifier {
  final ChatApiService _apiService;
  
  // Current selected location for chat context
  String _currentLocation = '';

  // Current location coordinates
  double _latitude = 0.0;
  double _longitude = 0.0;
  
  // List of chat messages
  final List<ChatMessage> _messages = [];
  
  // Loading state
  bool _isLoading = false;
  
  // Error message
  String? _errorMessage;

  ChatProvider({ChatApiService? apiService})
      : _apiService = apiService ?? ChatApiService();

  // Getters
  String get currentLocation => _currentLocation;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasMessages => _messages.isNotEmpty;

  /// Sets the current location and coordinates, optionally clears previous messages.
  /// 
  /// [location] - The name of the tourist attraction
  /// [latitude] - Latitude of the location
  /// [longitude] - Longitude of the location
  /// [clearHistory] - Whether to clear previous chat messages
  void setLocation(
    String location, {
    double latitude = 0.0,
    double longitude = 0.0,
    bool clearHistory = true,
  }) {
    if (_currentLocation != location) {
      _currentLocation = location;
      _latitude = latitude;
      _longitude = longitude;
      if (clearHistory) {
        _messages.clear();
        _addWelcomeMessage();
      }
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Adds a welcome message when a new location is selected.
  void _addWelcomeMessage() {
    _messages.add(ChatMessage.ai(
      'Welcome to $_currentLocation! 🏛️\n\n'
      'I\'m your AI tour guide powered by advanced AI. Ask me anything about this '
      'fascinating place - its history, significance, legends, or interesting facts!',
    ));
  }

  /// Sends a user message and gets AI response.
  /// 
  /// [query] - The user's question
  Future<void> sendMessage(String query) async {
    if (query.trim().isEmpty || _currentLocation.isEmpty) return;
    
    // Clear any previous error
    _errorMessage = null;
    
    // Add user message
    final userMessage = ChatMessage.user(query.trim());
    _messages.add(userMessage);
    notifyListeners();

    // Add loading indicator
    _isLoading = true;
    _messages.add(ChatMessage.loading());
    notifyListeners();

    try {
      // Send the actual current location to get location-specific responses
      final response = await _apiService.sendMessage(
        location: _currentLocation,
        userQuery: query.trim(),
      );

      // Remove loading indicator
      _messages.removeWhere((m) => m.isLoading);
      
      // Add AI response
      _messages.add(ChatMessage.ai(response.response));
      _isLoading = false;
      notifyListeners();
    } on ChatApiException catch (e) {
      _handleError(e.message);
    } catch (e) {
      _handleError('Something went wrong. Please try again.');
    }
  }

  /// Handles errors by updating state and notifying listeners.
  void _handleError(String message) {
    _messages.removeWhere((m) => m.isLoading);
    _messages.add(ChatMessage.error(message));
    _isLoading = false;
    _errorMessage = message;
    notifyListeners();
  }

  /// Clears all messages and resets the chat.
  void clearChat() {
    _messages.clear();
    _errorMessage = null;
    if (_currentLocation.isNotEmpty) {
      _addWelcomeMessage();
    }
    notifyListeners();
  }

  /// Retries the last failed message.
  void retryLastMessage() {
    // Find the last user message
    ChatMessage? lastUserMessage;
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].isUser) {
        lastUserMessage = _messages[i];
        break;
      }
    }

    if (lastUserMessage != null) {
      // Remove error message if present
      if (_messages.isNotEmpty && _messages.last.isError) {
        _messages.removeLast();
      }
      // Remove the last user message (it will be re-added)
      _messages.remove(lastUserMessage);
      notifyListeners();
      
      // Retry sending
      sendMessage(lastUserMessage.content);
    }
  }

  /// Quick suggestion queries for the current location.
  List<String> get quickSuggestions => [
    'Tell me about this place',
    'What is the history here?',
    'Any interesting facts?',
    'Best time to visit?',
    'What should I see here?',
  ];

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }
}
