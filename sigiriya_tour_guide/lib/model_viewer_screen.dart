import 'dart:math';
import 'dart:ui';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:http/http.dart' as http;

enum TimePreset { day, evening, night }

class ModelViewerScreen extends StatefulWidget {
  const ModelViewerScreen({super.key});

  @override
  State<ModelViewerScreen> createState() => _ModelViewerScreenState();
}

class _ModelViewerScreenState extends State<ModelViewerScreen>
    with TickerProviderStateMixin {
  final Flutter3DController controller = Flutter3DController();
  String srcGlb = 'assets/test.glb';

  bool isRaining = false;
  bool isFoggy = false;
  TimePreset preset = TimePreset.day;

  // Chat interface
  bool isChatOpen = false;
  final TextEditingController _chatController = TextEditingController();
  final ValueNotifier<List<ChatMessage>> _messages = ValueNotifier([]);
  bool isApiHealthy = false;

  // API URL: Use 10.0.2.2 for Android Emulator, localhost for web/desktop
  static const String apiBaseUrl = 'http://10.0.2.2:8000';

  @override
  void initState() {
    super.initState();
    controller.onModelLoaded.addListener(() {
      debugPrint('model is loaded : ${controller.onModelLoaded.value}');
    });
    _checkApiHealth();
  }

  Future<void> _checkApiHealth() async {
    try {
      final response = await http
          .get(
            Uri.parse('$apiBaseUrl/health'),
            headers: {'accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        setState(() {
          isApiHealthy = true;
        });
        debugPrint('API Health Check: Healthy');
      } else {
        setState(() {
          isApiHealthy = false;
        });
        debugPrint(
          'API Health Check: Unhealthy (Status: ${response.statusCode})',
        );
      }
    } catch (e) {
      setState(() {
        isApiHealthy = false;
      });
      debugPrint('API Health Check Failed: $e');
    }
  }

  @override
  void dispose() {
    _chatController.dispose();
    _messages.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    if (_chatController.text.trim().isEmpty) return;

    final userMessage = _chatController.text;
    _messages.value = [
      ..._messages.value,
      ChatMessage(text: userMessage, isUser: true, timestamp: DateTime.now()),
    ];
    _chatController.clear();

    // Call the chat API
    try {
      debugPrint('Sending chat message to: $apiBaseUrl/chat');
      debugPrint('Message content: $userMessage');

      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/chat'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'message': userMessage}),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('Chat API response status: ${response.statusCode}');
      debugPrint('Chat API response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          _messages.value = [
            ..._messages.value,
            ChatMessage(
              text: data['assistant_response'] ?? 'No response',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          ];
        }
      } else {
        if (mounted) {
          _messages.value = [
            ..._messages.value,
            ChatMessage(
              text:
                  'Error: Unable to get response (Status: ${response.statusCode})\nResponse: ${response.body}',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          ];
        }
      }
    } catch (e) {
      debugPrint('Chat API Exception: $e');
      if (mounted) {
        _messages.value = [
          ..._messages.value,
          ChatMessage(
            text:
                'Error: Could not connect to server.\n\nDetails: $e\n\nTip: If running on Android emulator, use 10.0.2.2 instead of localhost',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        ];
      }
      debugPrint('Chat API Error: $e');
    }
  }

  void _showChatBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ChatBottomSheetContent(
        messagesNotifier: _messages,
        chatController: _chatController,
        isApiHealthy: isApiHealthy,
        onSendMessage: _sendMessage,
      ),
    );
  }

  BoxDecoration _backgroundForPreset() {
    switch (preset) {
      case TimePreset.day:
        return const BoxDecoration(
          gradient: RadialGradient(
            colors: [Color(0xffffffff), Colors.grey],
            stops: [0.1, 1.0],
            radius: 0.7,
            center: Alignment.center,
          ),
        );
      case TimePreset.evening:
        return const BoxDecoration(
          gradient: RadialGradient(
            colors: [Color(0xFFFFE0B2), Color(0xFF1B1F2A)],
            stops: [0.05, 1.0],
            radius: 0.9,
            center: Alignment.topCenter,
          ),
        );
      case TimePreset.night:
        return const BoxDecoration(
          gradient: RadialGradient(
            colors: [Color(0xFF1A237E), Color(0xFF05070D)],
            stops: [0.05, 1.0],
            radius: 1.0,
            center: Alignment.topCenter,
          ),
        );
    }
  }

  double _nightTintOpacity() {
    switch (preset) {
      case TimePreset.day:
        return 0.0;
      case TimePreset.evening:
        return 0.18;
      case TimePreset.night:
        return 0.35;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showChatBottomSheet(context),
        backgroundColor: const Color(0xff0d2039),
        child: const Icon(Icons.chat, color: Colors.white),
      ),
      body: Container(
        decoration: _backgroundForPreset(),
        width: double.infinity,
        height: double.infinity,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Flutter3DViewer(
                    activeGestureInterceptor: true,
                    progressBarColor: Colors.orange,
                    enableTouch: true,
                    onProgress: (p) =>
                        debugPrint('model loading progress : $p'),
                    onLoad: (modelAddress) {
                      debugPrint('model loaded : $modelAddress');
                      controller.setCameraOrbit(-85, 50, 5);
                      controller.playAnimation();
                    },
                    onError: (e) => debugPrint('model failed to load : $e'),
                    controller: controller,
                    src: srcGlb,
                  ),

                  // Night/Evening tint overlay
                  IgnorePointer(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: _nightTintOpacity(),
                      child: Container(color: Colors.black),
                    ),
                  ),

                  // Fog overlay (blur + haze)
                  IgnorePointer(child: FogOverlay(enabled: isFoggy)),

                  // Rain overlay (particles)
                  IgnorePointer(child: RainOverlay(enabled: isRaining)),
                ],
              ),
            ),

            // Controls panel
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Scene Controls',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),

                  ElevatedButton.icon(
                    onPressed: () => setState(() => isRaining = !isRaining),
                    icon: const Icon(Icons.water_drop),
                    label: Text(isRaining ? 'Disable Rain' : 'Enable Rain'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(220, 50),
                    ),
                  ),
                  const SizedBox(height: 10),

                  ElevatedButton.icon(
                    onPressed: () => setState(() => isFoggy = !isFoggy),
                    icon: const Icon(Icons.cloud),
                    label: Text(isFoggy ? 'Disable Fog' : 'Enable Fog'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(220, 50),
                    ),
                  ),
                  const SizedBox(height: 10),

                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        preset = switch (preset) {
                          TimePreset.day => TimePreset.evening,
                          TimePreset.evening => TimePreset.night,
                          TimePreset.night => TimePreset.day,
                        };
                      });
                      debugPrint('Preset: $preset');
                    },
                    icon: const Icon(Icons.nightlight_round),
                    label: Text(switch (preset) {
                      TimePreset.day => 'Switch to Evening',
                      TimePreset.evening => 'Switch to Night',
                      TimePreset.night => 'Switch to Day',
                    }),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(220, 50),
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
}

class FogOverlay extends StatelessWidget {
  final bool enabled;
  const FogOverlay({super.key, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 350),
      opacity: enabled ? 1.0 : 0.0,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: enabled ? 6 : 0,
          sigmaY: enabled ? 6 : 0,
        ),
        child: Container(
          color: Colors.white.withOpacity(0.10), // haze
        ),
      ),
    );
  }
}

class RainOverlay extends StatefulWidget {
  final bool enabled;
  const RainOverlay({super.key, required this.enabled});

  @override
  State<RainOverlay> createState() => _RainOverlayState();
}

class _RainOverlayState extends State<RainOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _rng = Random();
  late List<_Drop> _drops;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 16),
          )
          ..addListener(() {
            if (!widget.enabled) return;
            setState(() {
              for (final d in _drops) {
                d.y += d.speed;
                if (d.y > 1.2) {
                  d.y = -0.2;
                  d.x = _rng.nextDouble();
                }
              }
            });
          })
          ..repeat();

    _drops = List.generate(220, (_) {
      return _Drop(
        x: _rng.nextDouble(),
        y: _rng.nextDouble(),
        len: _rng.nextDouble() * 0.04 + 0.02,
        speed: _rng.nextDouble() * 0.03 + 0.02,
      );
    });
  }

  @override
  void didUpdateWidget(covariant RainOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // keep controller running; we just stop drawing when disabled
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();
    return CustomPaint(painter: _RainPainter(_drops), size: Size.infinite);
  }
}

class _Drop {
  double x;
  double y;
  final double len;
  final double speed;

  _Drop({
    required this.x,
    required this.y,
    required this.len,
    required this.speed,
  });
}

class _RainPainter extends CustomPainter {
  final List<_Drop> drops;
  _RainPainter(this.drops);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.lightBlueAccent.withOpacity(0.55)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    for (final d in drops) {
      final x = d.x * size.width;
      final y1 = d.y * size.height;
      final y2 = y1 + d.len * size.height;
      canvas.drawLine(Offset(x, y1), Offset(x, y2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RainPainter oldDelegate) => true;
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class _ChatBottomSheetContent extends StatefulWidget {
  final ValueNotifier<List<ChatMessage>> messagesNotifier;
  final TextEditingController chatController;
  final bool isApiHealthy;
  final VoidCallback onSendMessage;

  const _ChatBottomSheetContent({
    required this.messagesNotifier,
    required this.chatController,
    required this.isApiHealthy,
    required this.onSendMessage,
  });

  @override
  State<_ChatBottomSheetContent> createState() =>
      _ChatBottomSheetContentState();
}

class _ChatBottomSheetContentState extends State<_ChatBottomSheetContent> {
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Chat Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xff0d2039),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.chat, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text(
                    'Tour Guide Chat',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Health status indicator
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: widget.isApiHealthy ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Messages List
            Expanded(
              child: ValueListenableBuilder<List<ChatMessage>>(
                valueListenable: widget.messagesNotifier,
                builder: (context, messages, child) {
                  return messages.isEmpty
                      ? const Center(
                          child: Text(
                            'Start a conversation!',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            return _ChatBubble(message: message);
                          },
                        );
                },
              ),
            ),
            // Input Field
            Container(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 12,
              ),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: const Border(
                  top: BorderSide(color: Colors.grey, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.chatController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onSubmitted: (_) {
                        widget.onSendMessage();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    color: const Color(0xff0d2039),
                    onPressed: widget.onSendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: message.isUser
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: message.isUser ? const Color(0xff0d2039) : Colors.grey[200],
            borderRadius: BorderRadius.circular(18),
          ),
          child: SelectableText(
            message.text,
            style: TextStyle(
              color: message.isUser ? Colors.white : Colors.black87,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}
