import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/user_message.dart';
import '../ui/app_theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.panel = false});
  final bool panel;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<Map<String, String>> _turns = [];
  bool _busy = false;
  bool _includeSummary = false;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final message = _input.text.trim();
    if (_busy || message.isEmpty) return;
    // History always consists of complete user/assistant pairs.
    final history = _turns
        .skip(_turns.length > 10 ? _turns.length - 10 : 0)
        .toList();
    setState(() {
      _busy = true;
      _error = null;
      _turns.add({'role': 'user', 'text': message});
      _input.clear();
    });
    _scrollDown();
    try {
      final response = await ApiService.chat(
        message,
        history,
        includeSummary: _includeSummary,
      );
      if (response.statusCode != 200) {
        throw Exception(ApiService.errorText(response));
      }
      final result = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(
        () => _turns.add({'role': 'model', 'text': result['reply'] as String}),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _turns.removeLast();
        _input.text = message;
        _error = error is TimeoutException
            ? 'The assistant is taking too long to reply. Please try again.'
            : UserMessage.from(
                error,
                fallback: 'Unable to send your message. Please try again.',
              );
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _scrollDown();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        automaticallyImplyLeading: !widget.panel,
        leading: widget.panel
            ? IconButton(
                tooltip: 'Close assistant',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        title: const Row(
          children: [
            Icon(Icons.chat_bubble_rounded, color: AppTheme.blue, size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'DriveAlert assistant',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Clear conversation',
            onPressed: _busy
                ? null
                : () {
                    setState(() {
                      _turns.clear();
                      _error = null;
                    });
                  },
            icon: const Icon(Icons.delete_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Only chat while parked. Messages go to our AI service; no video or contacts are shared. This conversation clears when closed.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
            ),
            SwitchListTile.adaptive(
              title: const Text(
                'Personalise with my recent warnings',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Shares saved journey and warning counts. No video or contacts.',
              ),
              value: _includeSummary,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _includeSummary = value),
            ),
            Expanded(
              child: _turns.isEmpty && !_busy
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const SizedBox(height: 12),
                        const Icon(
                          Icons.chat_bubble_rounded,
                          size: 42,
                          color: AppTheme.blue,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'A little guidance for\nyour next journey.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 23,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Ask about warnings, rest breaks or using DriveAlert.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.muted, height: 1.5),
                        ),
                        const SizedBox(height: 22),
                        for (final prompt in [
                          'What do my fatigue warnings mean?',
                          'How can I plan better rest breaks?',
                          'Help me get started with DriveAlert',
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: OutlinedButton(
                              onPressed: () {
                                _input.text = prompt;
                              },
                              child: Text(prompt, textAlign: TextAlign.center),
                            ),
                          ),
                      ],
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: _turns.length,
                      itemBuilder: (context, index) {
                        final turn = _turns[index];
                        final user = turn['role'] == 'user';
                        return Align(
                          alignment: user
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            constraints: const BoxConstraints(maxWidth: 560),
                            decoration: BoxDecoration(
                              color: user
                                  ? const Color(0xFFE1EBFF)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user ? 'You' : 'DriveAlert AI',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SelectableText(turn['text']!),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      enabled: !_busy,
                      maxLength: 2000,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Ask DriveAlert...',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send message',
                    onPressed: _busy ? null : _send,
                    icon: const Icon(Icons.send_rounded),
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
