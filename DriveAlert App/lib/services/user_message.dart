import 'dart:async';

/// Technical diagnostics belong in development tools, never on driver screens.
class UserMessage {
  static String from(
    Object? error, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    if (error is TimeoutException) {
      return 'The connection is taking too long. Please try again.';
    }
    var text = error
        .toString()
        .replaceFirst(RegExp(r'^(Exception: |Bad state: )'), '')
        .trim();
    final lower = text.toLowerCase();
    if (lower.contains('ilmu') ||
        lower.contains('gemini') ||
        lower.contains('api key') ||
        lower.contains('model access')) {
      return 'The AI assistant is unavailable right now. Please try again later.';
    }
    if (lower.contains('firebase') ||
        lower.contains('credential') ||
        lower.contains('notification worker')) {
      return 'Notifications are temporarily unavailable. Please try again later.';
    }
    if (lower.contains('backend')) {
      return 'The service is unavailable. Please try again when connected.';
    }
    if (RegExp(
      r'https?://|\b\d{1,3}(?:\.\d{1,3}){3}\b|Exception|Error\(|Traceback|SocketException|ClientException|FormatException|PlatformException|/api/|HTTP \d|[A-Za-z]:\\|django|wsgi|\bSQL\b|api_key|Bearer |Authorization:|run_id',
      caseSensitive: false,
    ).hasMatch(text)) {
      return fallback;
    }
    if (text.isEmpty ||
        text == 'null' ||
        text.length > 350 ||
        text.startsWith('<') ||
        text.startsWith('{')) {
      return fallback;
    }
    return text;
  }
}
