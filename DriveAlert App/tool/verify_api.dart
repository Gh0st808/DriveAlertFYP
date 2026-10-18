import 'dart:io';
import '../test/api_transport_cases.dart';

Future<void> main() async {
  var passed = 0;
  for (final entry in apiTransportCases.entries) {
    try {
      await entry.value();
      stdout.writeln('PASS: ${entry.key}');
      passed++;
    } catch (error, stack) {
      stderr.writeln('FAIL: ${entry.key}\n$error\n$stack');
      exitCode = 1;
    }
  }
  stdout.writeln(
    '$passed/${apiTransportCases.length} API transport checks passed.',
  );
}
