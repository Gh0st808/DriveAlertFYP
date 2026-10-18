import 'package:flutter_test/flutter_test.dart';
import 'api_transport_cases.dart';

void main() {
  for (final entry in apiTransportCases.entries) {
    test(entry.key, entry.value);
  }
}
