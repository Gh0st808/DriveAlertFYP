import 'package:flutter/material.dart';
import '../screens/chat_screen.dart';
import 'app_theme.dart';

class AssistantBubble extends StatelessWidget {
  const AssistantBubble({super.key});

  @override
  Widget build(BuildContext context) => FloatingActionButton(
    heroTag: null,
    tooltip: 'Ask DriveAlert',
    backgroundColor: AppTheme.blue,
    foregroundColor: Colors.white,
    elevation: 4,
    shape: const CircleBorder(),
    onPressed: () => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: .92,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: const ChatScreen(panel: true),
        ),
      ),
    ),
    child: const Icon(Icons.chat_bubble_rounded, size: 26),
  );
}
