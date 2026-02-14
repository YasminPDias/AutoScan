import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../layouts/desktop_layout.dart';
import '../utils/responsive.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [
    ChatMessage(
      text: 'Lorem ipsum is simply dummy text of the printing and typesetting industry. Lorem ipsum has been the industry\'s standard dummy text ever since the 1E',
      isUser: false,
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    ChatMessage(
      text: '''• Lorem ipsum is simply
• dummy text of the printing
• and typesetting industry.
• Lorem ipsum has been the
• industry's standard dummy
• text ever since the 1900s
• when an unknown printer
• took a galley of type and
• scrambled it to make a
• type specimen book. It has
• survived not''',
      isUser: false,
      timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
      isHighlighted: true,
    ),
    ChatMessage(
      text: 'Lorem ipsum is simply dummy text of the printing and typesetting industry. Lorem ipsum has been the industry\'s standard dummy text ever since the 1E',
      isUser: true,
      timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DesktopLayout(
      currentRoute: '/chat',
      title: context.isDesktop ? 'Chat' : '',
      showAppBar: !context.isDesktop,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: context.isDesktop
            ? null
            : AppBar(
                title: const Text('Chat'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.person_outline),
                    onPressed: () {},
                  ),
                ],
              ),
        body: Column(
          children: [
            // Messages list
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(context.isDesktop ? 40 : 20),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return _buildMessageBubble(message);
                },
              ),
            ),
            
            // Message input
            Container(
              padding: EdgeInsets.all(context.isDesktop ? 24 : 16),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                border: Border(
                  top: BorderSide(color: AppColors.border, width: 1),
                ),
              ),
              child: SafeArea(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: context.isDesktop ? 1200 : double.infinity,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppColors.iconBackground,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppColors.border, width: 1),
                          ),
                          child: TextField(
                            controller: _messageController,
                            decoration: const InputDecoration(
                              hintText: 'Escreva uma mensagem',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.mic_none),
                        onPressed: () {},
                        color: AppColors.textSecondary,
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: () {
                          if (_messageController.text.isNotEmpty) {
                            setState(() {
                              _messages.add(ChatMessage(
                                text: _messageController.text,
                                isUser: true,
                                timestamp: DateTime.now(),
                              ));
                              _messageController.clear();
                            });
                          }
                        },
                        color: AppColors.primaryRed,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppColors.iconBackground,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: const Icon(
                Icons.support_agent,
                size: 18,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isHighlighted
                    ? AppColors.lightRed
                    : (message.isUser ? AppColors.iconBackground : AppColors.cardWhite),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: message.isHighlighted
                      ? AppColors.primaryRed
                      : AppColors.border,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.isHighlighted)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'BarScan',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  Text(
                    message.text,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.primaryRed,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                size: 18,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isHighlighted;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isHighlighted = false,
  });
}
