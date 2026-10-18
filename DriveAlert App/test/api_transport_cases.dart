import 'dart:convert';
import 'package:cross_file/cross_file.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:drivealert/services/api_service.dart';

void check(bool value, String message) {
  if (!value) {
    throw StateError(message);
  }
}

Future<void> isolated(Future<void> Function() body) async {
  ApiService.baseUrl = 'http://test.local/api';
  ApiService.accessToken = 'expired';
  ApiService.refreshToken = 'refresh';
  try {
    await body();
  } finally {
    ApiService.client.close();
    ApiService.accessToken = null;
    ApiService.refreshToken = null;
  }
}

final Map<String, Future<void> Function()> apiTransportCases = {
  'an account switch prevents an old request retrying under the new account':
      () => isolated(() async {
        var calls = 0;
        ApiService.client = MockClient((request) async {
          calls++;
          ApiService.accessToken = 'new-account-access';
          ApiService.refreshToken = 'new-account-refresh';
          return http.Response('{}', 401);
        });
        final response = await ApiService.registerPushToken(
          'old-account-phone-token',
        );
        check(
          response.statusCode == 401 && calls == 1,
          'Old registration retried under the new account',
        );
      }),
  'chat and notification calls use authenticated bounded payloads': () =>
      isolated(() async {
        final requests = <http.Request>[];
        ApiService.client = MockClient((request) async {
          requests.add(request);
          return http.Response('{}', 200);
        });
        await ApiService.chat('Explain warnings', [
          {'role': 'user', 'text': 'Hi'},
          {'role': 'model', 'text': 'Hello'},
        ], includeSummary: true);
        await ApiService.registerPushToken('phone-token');
        await ApiService.testPush('phone-token');
        await ApiService.removePushToken('phone-token');
        check(
          requests.every((r) => r.headers['Authorization'] == 'Bearer expired'),
          'Missing account authorization',
        );
        final body = jsonDecode(requests.first.body);
        check(
          body['message'] == 'Explain warnings' &&
              body['include_summary'] == true &&
              body['history'].length == 2,
          'Chat payload changed',
        );
        check(
          requests[1].url.path == '/api/notifications/registration/' &&
              requests[3].method == 'DELETE',
          'Notification endpoint mismatch',
        );
      }),
  'a delayed refresh cannot restore credentials after sign-out': () =>
      isolated(() async {
        ApiService.client = MockClient((request) async {
          if (request.url.path.endsWith('/auth/refresh/')) {
            ApiService.accessToken = null;
            ApiService.refreshToken = null;
            return http.Response('{"access":"stale-after-logout"}', 200);
          }
          return http.Response('{}', 401);
        });
        await ApiService.getCurrentUser();
        check(
          ApiService.accessToken == null && ApiService.refreshToken == null,
          'A stale refresh restored signed-out credentials',
        );
      }),
  'concurrent requests share one token refresh and retry': () =>
      isolated(() async {
        var refreshes = 0;
        ApiService.client = MockClient((request) async {
          if (request.url.path.endsWith('/auth/refresh/')) {
            refreshes++;
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return http.Response('{"access":"fresh"}', 200);
          }
          return http.Response(
            '{}',
            request.headers['Authorization'] == 'Bearer fresh' ? 200 : 401,
          );
        });
        final responses = await Future.wait([
          ApiService.getCurrentUser(),
          ApiService.getProfile(),
          ApiService.getDevices(),
        ]);
        check(
          responses.every((r) => r.statusCode == 200),
          'Expired requests did not retry successfully',
        );
        check(
          refreshes == 1,
          'Concurrent requests caused duplicate refresh calls',
        );
      }),
  'registration saves all supplied fields without a bearer token': () =>
      isolated(() async {
        ApiService.client = MockClient((request) async {
          final body = jsonDecode(request.body);
          check(body['full_name'] == 'New Driver', 'Full name missing');
          check(body['vehicle_model'] == 'Myvi', 'Vehicle missing');
          check(
            !request.headers.containsKey('Authorization'),
            'Registration included an old bearer token',
          );
          return http.Response('{}', 201);
        });
        final response = await ApiService.register(
          username: 'new@example.com',
          email: 'new@example.com',
          password: 'SafeRoad!42',
          fullName: 'New Driver',
          vehicleModel: 'Myvi',
        );
        check(
          response.statusCode == 201,
          'Registration status was not preserved',
        );
      }),
  'multipart uploads retry after refresh using in-memory image bytes': () =>
      isolated(() async {
        var uploads = 0;
        ApiService.client = MockClient((request) async {
          if (request.url.path.endsWith('/auth/refresh/')) {
            return http.Response('{"access":"fresh"}', 200);
          }
          uploads++;
          check(request.body.contains('avatar.png'), 'Image filename missing');
          check(
            request.body.contains('vehicle_model'),
            'Vehicle field missing',
          );
          check(
            request.body.contains('updated@example.com'),
            'Email field missing',
          );
          return http.Response('{}', uploads == 1 ? 401 : 200);
        });
        final response = await ApiService.updateProfile(
          fullName: 'Driver',
          phoneNumber: '0123456789',
          vehicleModel: 'Axia',
          email: 'updated@example.com',
          profilePicture: XFile.fromData(
            utf8.encode('image-bytes'),
            name: 'avatar.png',
            path: 'avatar.png',
          ),
        );
        check(
          response.statusCode == 200 && uploads == 2,
          'Upload was not recreated for the retry',
        );
      }),
  'period and monitoring calls use one configured backend address': () =>
      isolated(() async {
        final paths = <String>[];
        ApiService.client = MockClient((request) async {
          paths.add(request.url.toString());
          return http.Response('{}', 200);
        });
        await ApiService.getAnalytics(period: 'Week');
        await ApiService.startMonitoring();
        await ApiService.stopMonitoring();
        check(
          paths[0] == 'http://test.local/api/analytics/summary/?period=Week',
          'Period parameter missing',
        );
        check(
          paths[1] == 'http://test.local/api/monitor/api/monitor/start',
          'Start used the wrong endpoint',
        );
        check(
          paths[2] == 'http://test.local/api/monitor/api/monitor/stop',
          'Stop used the wrong endpoint',
        );
      }),
  'invalid refresh clears expired credentials and preserves failure': () =>
      isolated(() async {
        ApiService.client = MockClient((_) async => http.Response('{}', 401));
        final response = await ApiService.getCurrentUser();
        check(response.statusCode == 401, 'Authentication failure was hidden');
        check(
          ApiService.accessToken == null && ApiService.refreshToken == null,
          'Invalid credentials were retained',
        );
      }),
};
