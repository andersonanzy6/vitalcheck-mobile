import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://vitalcheck-56uj.onrender.com/api',
);
const secureStorage = FlutterSecureStorage();

final apiProvider = Provider<ApiClient>((ref) => ApiClient());
final authProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref.read(apiProvider)),
);
final socketProvider = Provider<io.Socket?>(
  (ref) => ref.watch(authProvider).token == null
      ? null
      : createSocket(ref.watch(authProvider).token!),
);

class ApiClient {
  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: apiBaseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await secureStorage.read(key: 'accessToken');
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 &&
              !error.requestOptions.path.endsWith('/auth/refresh')) {
            try {
              final refresh = await secureStorage.read(key: 'refreshToken');
              if (refresh != null) {
                final response = await Dio().post(
                  '$apiBaseUrl/auth/refresh',
                  data: {'refreshToken': refresh},
                );
                final data = response.data['data'] as Map<String, dynamic>;
                final token = data['accessToken'] ?? data['token'];
                if (token != null) {
                  await secureStorage.write(
                    key: 'accessToken',
                    value: token.toString(),
                  );
                  if (data['refreshToken'] != null) {
                    await secureStorage.write(
                      key: 'refreshToken',
                      value: data['refreshToken'].toString(),
                    );
                  }
                  final retry = error.requestOptions
                    ..headers['Authorization'] = 'Bearer $token';
                  handler.resolve(await dio.fetch(retry));
                  return;
                }
              }
            } catch (_) {}
            await secureStorage.deleteAll();
          }
          handler.next(error);
        },
      ),
    );
  }
  late final Dio dio;
  Future<dynamic> get(String path, [Map<String, dynamic>? query]) async =>
      _data((await dio.get(path, queryParameters: query)).data);
  Future<dynamic> post(String path, [Object? body]) async =>
      _data((await dio.post(path, data: body)).data);
  Future<dynamic> put(String path, [Object? body]) async =>
      _data((await dio.put(path, data: body)).data);
  dynamic _data(dynamic response) {
    if (response is Map && response['success'] == false) {
      throw Exception(response['error']?['message'] ?? 'Request failed');
    }
    return response is Map && response.containsKey('data')
        ? response['data']
        : response;
  }
}

class AuthState {
  const AuthState({this.token, this.user, this.loading = false, this.error});
  final String? token;
  final Map<String, dynamic>? user;
  final bool loading;
  final String? error;
  AuthState copyWith({
    String? token,
    Map<String, dynamic>? user,
    bool? loading,
    String? error,
    bool clearError = false,
  }) => AuthState(
    token: token ?? this.token,
    user: user ?? this.user,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
  );
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this.api) : super(const AuthState()) {
    restore();
  }
  final ApiClient api;
  Future<void> restore() async {
    final token = await secureStorage.read(key: 'accessToken');
    if (token == null) return;
    state = AuthState(token: token, loading: true);
    try {
      final user = await api.get('/auth/me');
      state = AuthState(token: token, user: _map(user));
    } catch (_) {
      await secureStorage.deleteAll();
      state = const AuthState();
    }
  }

  Future<void> login(String email, String password) =>
      _authenticate('/auth/login', {'email': email, 'password': password});
  Future<void> register(Map<String, dynamic> details) =>
      _authenticate('/auth/register', details);
  Future<void> _authenticate(String path, Map<String, dynamic> body) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final response = _map(await api.post(path, body));
      final token = (response['accessToken'] ?? response['token'])?.toString();
      if (token == null) {
        throw Exception('The server did not return an access token.');
      }
      await secureStorage.write(key: 'accessToken', value: token);
      final refresh = response['refreshToken'];
      if (refresh != null) {
        await secureStorage.write(
          key: 'refreshToken',
          value: refresh.toString(),
        );
      }
      state = AuthState(token: token, user: _map(response['user'] ?? response));
    } catch (error) {
      state = AuthState(loading: false, error: _friendly(error));
    }
  }

  Future<void> logout() async {
    await secureStorage.deleteAll();
    state = const AuthState();
  }
}

Map<String, dynamic> _map(dynamic value) => value is Map<String, dynamic>
    ? value
    : value is Map
    ? Map<String, dynamic>.from(value)
    : <String, dynamic>{};
String _friendly(Object error) => error is DioException
    ? (error.response?.data?['error']?['message']?.toString() ??
          error.message ??
          'Could not connect')
    : error.toString().replaceFirst('Exception: ', '');
io.Socket createSocket(String token) => io.io(
  apiBaseUrl.replaceFirst(RegExp(r'/api/?$'), ''),
  io.OptionBuilder()
      .setTransports(['websocket'])
      .setAuth({'token': token})
      .setExtraHeaders({'Authorization': 'Bearer $token'})
      .enableReconnection()
      .build(),
);
