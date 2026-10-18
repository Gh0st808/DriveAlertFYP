import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cross_file/cross_file.dart';
import 'user_message.dart';

class ApiService {
  static String baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.13.1.97:8000/api',
  );
  static String? accessToken;
  static String? refreshToken;
  static Future<bool>? _refreshing;
  static const timeout = Duration(seconds: 20);
  static http.Client client = http.Client();
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    if (accessToken != null) 'Authorization': 'Bearer $accessToken',
  };

  static String errorText(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map) {
        return UserMessage.from(
          data.entries
              .map(
                (e) =>
                    '${e.key == 'detail' ? '' : '${e.key.toString().replaceAll('_', ' ')}: '}${e.value is List ? (e.value as List).join(" ") : e.value}',
              )
              .join('\n'),
        );
      }
      return UserMessage.from(data);
    } catch (_) {
      return 'Unable to complete that request. Please try again.';
    }
  }

  static Future<http.Response> request(
    String method,
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    final requestAccount = refreshToken;
    Future<http.Response> send() async {
      final req = http.Request(method, Uri.parse('$baseUrl$path'));
      req.headers.addAll(
        authenticated ? headers : {'Content-Type': 'application/json'},
      );
      if (body != null) req.body = jsonEncode(body);
      return await http.Response.fromStream(
        await client.send(req),
      ).timeout(timeout);
    }

    var response = await send().timeout(timeout);
    if (authenticated &&
        response.statusCode == 401 &&
        refreshToken == requestAccount &&
        await refreshAccessToken() &&
        refreshToken == requestAccount) {
      response = await send().timeout(timeout);
    }
    return response;
  }

  static Future<http.Response> register({
    required String username,
    required String email,
    required String password,
    String fullName = '',
    String vehicleModel = '',
  }) => request(
    'POST',
    '/auth/register/',
    authenticated: false,
    body: {
      'username': username,
      'email': email,
      'password': password,
      'full_name': fullName,
      'vehicle_model': vehicleModel,
    },
  );

  static Future<bool> login({
    required String username,
    required String password,
  }) async {
    final response = await request(
      'POST',
      '/auth/login/',
      authenticated: false,
      body: {'username': username, 'password': password},
    );
    if (response.statusCode != 200) return false;
    final data = jsonDecode(response.body);
    accessToken = data['access'];
    refreshToken = data['refresh'];
    return true;
  }

  static Future<bool> refreshAccessToken() async {
    if (_refreshing != null) return _refreshing!;
    final task = _doRefresh();
    _refreshing = task;
    try {
      return await task;
    } finally {
      _refreshing = null;
    }
  }

  static Future<bool> _doRefresh() async {
    final originalRefresh = refreshToken;
    if (originalRefresh == null) return false;
    try {
      final response = await request(
        'POST',
        '/auth/refresh/',
        authenticated: false,
        body: {'refresh': originalRefresh},
      );
      if (refreshToken != originalRefresh) return false;
      if (response.statusCode == 200) {
        accessToken = jsonDecode(response.body)['access'];
        return true;
      }
      accessToken = null;
      refreshToken = null;
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<http.Response> registerPushToken(String token) =>
      request('POST', '/notifications/registration/', body: {'token': token});
  static Future<http.Response> removePushToken(String token) =>
      request('DELETE', '/notifications/registration/', body: {'token': token});
  static Future<http.Response> getPushStatus() =>
      request('GET', '/notifications/status/');
  static Future<http.Response> testPush(String token) =>
      request('POST', '/notifications/test/', body: {'token': token});
  static Future<http.Response> getCurrentUser() => request('GET', '/auth/me/');
  static Future<http.Response> chat(
    String message,
    List<Map<String, String>> history, {
    bool includeSummary = false,
  }) => request(
    'POST',
    '/chat/',
    body: {
      'message': message,
      'history': history,
      'include_summary': includeSummary,
    },
  );
  static Future<http.Response> getProfile() => request('GET', '/profile/');
  static Future<http.Response> updateProfile({
    required String fullName,
    required String phoneNumber,
    String? vehicleModel,
    String? email,
    String? emergencyContactName,
    String? emergencyContactPhone,
    XFile? profilePicture,
  }) async {
    Future<http.Response> send() async {
      final req = http.MultipartRequest(
        'PATCH',
        Uri.parse('$baseUrl/profile/'),
      );
      if (accessToken != null) {
        req.headers['Authorization'] = 'Bearer $accessToken';
      }
      req.fields.addAll({'full_name': fullName, 'phone_number': phoneNumber});
      if (vehicleModel != null) req.fields['vehicle_model'] = vehicleModel;
      if (email != null) req.fields['email'] = email;
      if (emergencyContactName != null) {
        req.fields['emergency_contact_name'] = emergencyContactName;
      }
      if (emergencyContactPhone != null) {
        req.fields['emergency_contact_phone'] = emergencyContactPhone;
      }
      if (profilePicture != null) {
        req.files.add(
          http.MultipartFile.fromBytes(
            'profile_picture',
            await profilePicture.readAsBytes(),
            filename: profilePicture.name,
          ),
        );
      }
      return await http.Response.fromStream(
        await client.send(req),
      ).timeout(timeout);
    }

    var response = await send().timeout(timeout);
    if (response.statusCode == 401 && await refreshAccessToken()) {
      response = await send().timeout(timeout);
    }
    return response;
  }

  static Future<http.Response> getEmergencyContact() => getProfile();
  static Future<http.Response> updateEmergencyContact({
    required String name,
    required String phone,
  }) => savePreferences({
    'emergency_contact_name': name,
    'emergency_contact_phone': phone,
  });
  static Future<http.Response> clearEmergencyContact() =>
      updateEmergencyContact(name: '', phone: '');
  static Future<http.Response> savePreferences(Map<String, dynamic> data) =>
      request('PATCH', '/profile/', body: data);
  static Future<http.Response> updateAccount({
    String? username,
    String? email,
  }) => request(
    'PATCH',
    '/account/',
    body: {'username': ?username, 'email': ?email},
  );
  static Future<http.Response> resetPassword(String email) => request(
    'POST',
    '/auth/password-reset/',
    authenticated: false,
    body: {'email': email},
  );
  static Future<http.Response> changePassword(String current, String next) =>
      request(
        'POST',
        '/auth/change-password/',
        body: {'current_password': current, 'new_password': next},
      );
  static Future<http.Response> getDevices() => request('GET', '/devices/');
  static Future<http.Response> createDevice({
    required String name,
    required String deviceId,
  }) =>
      request('POST', '/devices/', body: {'name': name, 'device_id': deviceId});
  static Future<http.Response> updateDevice({
    required int deviceId,
    String? name,
    String? deviceIdValue,
    bool? isActive,
  }) => request(
    'PATCH',
    '/devices/$deviceId/',
    body: {'name': ?name, 'device_id': ?deviceIdValue, 'is_active': ?isActive},
  );
  static Future<http.Response> deleteDevice(int deviceId) =>
      request('DELETE', '/devices/$deviceId/');
  static Future<http.Response> getSessions() => request('GET', '/sessions/');
  static Future<http.Response> createSession({
    required int deviceId,
    required String startTime,
  }) => request(
    'POST',
    '/sessions/',
    body: {
      'device': deviceId,
      'start_time': startTime,
      'vehicle_moving': false,
    },
  );
  static Future<http.Response> endSession({
    required int sessionId,
    required String endTime,
  }) => request('PATCH', '/sessions/$sessionId/', body: {'end_time': endTime});
  static Future<http.Response> getEvents() => request('GET', '/events/');
  static Future<http.Response> getAnalytics({String period = 'All'}) =>
      request('GET', '/analytics/summary/?period=$period');
  static Future<http.Response> monitorStatus() =>
      request('GET', '/monitor/api/status');
  static Future<http.Response> monitorFrame() =>
      request('GET', '/monitor/api/frame');
  static Future<http.Response> startMonitoring() =>
      request('POST', '/monitor/api/monitor/start', body: {});
  static Future<http.Response> stopMonitoring() =>
      request('POST', '/monitor/api/monitor/stop', body: {});
}
