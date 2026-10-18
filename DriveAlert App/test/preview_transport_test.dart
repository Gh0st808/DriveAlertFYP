import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:drivealert/services/api_service.dart';

class PendingPreviewClient extends http.BaseClient {
  bool aborted = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final result = Completer<http.StreamedResponse>();
    if (request is http.Abortable) {
      request.abortTrigger?.then((_) {
        aborted = true;
        result.completeError(http.RequestAbortedException(request.url));
      });
    }
    return result.future;
  }
}

void main() {
  testWidgets('preview timeout aborts the transport instead of leaving it running', (tester) async {
    final client = PendingPreviewClient();
    ApiService.client = client;
    addTearDown(client.close);
    final outcome = expectLater(ApiService.monitorFrame(), throwsA(isA<TimeoutException>()));
    await tester.pump(const Duration(seconds: 4));
    await outcome;
    expect(client.aborted, isTrue);
  });
}
