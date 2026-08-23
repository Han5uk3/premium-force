import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:premium_force_main/api/api_logger.dart';
import 'package:premium_force_main/api/api_result.dart';
import 'package:premium_force_main/storage/user_local_storage.dart';
import 'package:premium_force_main/utils/json_utils.dart';

/// Shared plumbing for every `/api/v2/` client.
///
/// The v2 surface is uniform: a JSON envelope of `{success, message, data}`,
/// bearer auth with the same JWT the v1 [ApiService] stores, and a 401 that
/// means "refresh and retry once". Rather than repeat that in each client, the
/// subclasses ([BookingApiV2], [NotificationApiV2], [ReviewApiV2],
/// [UserApiV2]) inherit a configured [dio] and the [request] helper and only
/// declare their own endpoints.
///
/// Usage:
/// ```dart
/// class MyApiV2 extends V2ApiClient {
///   Future<ApiResult<Thing>> getThing() => request(
///         () => dio.get('things/1'),
///         parse: (payload) => Thing.fromJson(asMap(payload)),
///       );
/// }
/// ```
abstract class V2ApiClient {
  V2ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Accept': 'application/json'},
        // Several v2 endpoints use 4xx to carry a displayable message rather
        // than to signal a crash, so anything below 500 is unwrapped normally.
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    // Debug-only: payloads carry customer PII and, on confirm, live gateway
    // credentials. See BookingApiLogger for what it masks.
    if (kDebugMode) {
      dio.interceptors.add(BookingApiLogger());
    }

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = UserLocalStorage.getToken();
          if (token != null && options.headers['Authorization'] == null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode != 401) return handler.next(e);

          final newToken = await refreshAccessToken();
          if (newToken == null) return handler.next(e);

          try {
            e.requestOptions.headers['Authorization'] = 'Bearer $newToken';
            // A multipart body is a one-shot stream, already consumed by the
            // attempt that 401'd; the retry needs its own copy.
            final data = e.requestOptions.data;
            if (data is FormData) {
              e.requestOptions.data = data.clone();
            }
            final retried = await dio.fetch(e.requestOptions);
            return handler.resolve(retried);
          } catch (_) {
            return handler.next(e);
          }
        },
      ),
    );
  }

  /// Root of the v2 surface.
  static const String baseUrl = 'https://api.premiumforcegroup.com/api/v2/';

  /// Token refresh still lives on the v1 auth surface (no `v2` prefix).
  static const String refreshUrl = 'https://api.premiumforcegroup.com/api/';

  /// Configured client — authenticated, logged in debug, 4xx-tolerant.
  late final Dio dio;

  /// Exchange the stored refresh token for a new access token.
  ///
  /// Uses a bare [Dio] so the retry cannot re-enter this interceptor.
  static Future<String?> refreshAccessToken() async {
    final refreshToken = UserLocalStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return null;

    try {
      final refreshDio = Dio(
        BaseOptions(
          baseUrl: refreshUrl,
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );
      if (kDebugMode) refreshDio.interceptors.add(BookingApiLogger());

      final response = await refreshDio.post(
        'otp/refresh-token',
        data: {'refreshToken': refreshToken},
      );

      final body = asMap(response.data);
      final tokens = pickMap(body, const ['tokens']).isNotEmpty
          ? pickMap(body, const ['tokens'])
          : pickMap(pickMap(body, const ['data']), const ['tokens']);

      final access =
          pickString(tokens, const ['accessToken', 'token']) ??
          pickString(body, const ['accessToken', 'token']);
      final refresh =
          pickString(tokens, const ['refreshToken', 'refresh_token']) ??
          pickString(body, const ['refreshToken', 'refresh_token']);

      if (access == null) return null;

      await UserLocalStorage.saveTokens(
        accessToken: access,
        refreshToken: refresh ?? refreshToken,
      );
      return access;
    } catch (error) {
      return null;
    }
  }

  /// Run [send], unwrap the `{success, message, data}` envelope, and hand the
  /// inner payload to [parse].
  ///
  /// [onNotFound] converts a 404 into a successful result — used by the geo
  /// lookups, where "nothing matched" is an answer rather than an error.
  Future<ApiResult<T>> request<T>(
    Future<Response<dynamic>> Function() send, {
    required T Function(dynamic payload) parse,
    T Function(String? message)? onNotFound,
  }) async {
    try {
      final response = await send();
      final body = asMap(response.data);
      final status = response.statusCode ?? 0;
      final message = pickString(body, const ['message', 'error']);
      // `success` may be absent on bare payloads; fall back to the status code.
      final succeeded =
          pickBool(body, const ['success']) ?? (status >= 200 && status < 300);

      if (!succeeded || status >= 400) {
        if (status == 404 && onNotFound != null) {
          return ApiResult<T>.ok(onNotFound(message), message: message);
        }
        // A 2xx carrying `success: false` is easy to miss in the raw log, so
        // the interpreted outcome is recorded separately.
        return ApiResult<T>.failure(
          message ?? statusMessage(status),
          statusCode: status,
        );
      }

      // Endpoints nest their payload under `data`; a few return it at the root.
      final payload = body.containsKey('data') ? body['data'] : body;
      final parsed = parse(payload);
      return ApiResult<T>.ok(parsed, message: message);
    } on DioException catch (error) {
      return ApiResult<T>.failure(
        dioMessage(error),
        statusCode: error.response?.statusCode,
      );
    } catch (error) {
      // Almost always a shape mismatch between the response and the model.
      // Named explicitly because the v2 payloads are still being finalised, and
      // a parse failure must not crash the booking flow.
      return ApiResult<T>.failure('Something went wrong. Please try again.');
    }
  }

  /// Read a list that may arrive bare or nested under one of [keys].
  static List<Map<String, dynamic>> listOf(dynamic payload, List<String> keys) {
    if (payload is List) return asMapList(payload);
    return pickMapList(asMap(payload), keys);
  }

  static String statusMessage(int statusCode) => switch (statusCode) {
    400 => 'Please check the details and try again.',
    401 => 'Your session has expired. Please sign in again.',
    403 => 'You are not allowed to perform this action.',
    404 => 'This service is not available for the selected details.',
    409 => 'This booking has already been processed.',
    422 => 'Please check the details and try again.',
    _ => 'Server error ($statusCode). Please try again.',
  };

  static String dioMessage(DioException error) {
    final data = error.response?.data;
    final serverMessage = data is Map
        ? pickString(asMap(data), const ['message', 'error'])
        : null;
    if (serverMessage != null) return serverMessage;

    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => 'Request timed out. Please try again.',
      DioExceptionType.connectionError =>
        'No internet connection. Please check your network.',
      DioExceptionType.cancel => 'Request was cancelled.',
      _ => statusMessage(error.response?.statusCode ?? 0),
    };
  }
}
