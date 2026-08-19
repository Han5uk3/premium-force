import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Structured request/response logging for the app's Dio clients.
///
/// Written for the v2 booking API and since attached to the general [ApiService]
/// client too; [label] keeps the two apart in the console.
///
/// Replaces Dio's [LogInterceptor] for four reasons:
///
/// * **Credentials.** `POST /bookings/session/confirm` returns live PayTabs
///   `serverKey`/`clientKey`, and every request carries a bearer token. Those
///   are masked here rather than printed in full.
/// * **Correlation.** Each exchange gets a short id and an elapsed time, so a
///   response can be matched to its request when calls overlap.
/// * **Completeness.** `debugPrint` throttles long lines, which silently
///   truncates JSON bodies; payloads are emitted line-by-line instead.
/// * **Multipart.** [LogInterceptor] renders a `FormData` body as the useless
///   `Instance of 'FormData'`. Profile updates are multipart, so its fields are
///   expanded here and attachments noted by filename and size.
///
/// Logging is debug-only — [BookingApiLogger] is never attached in release, so
/// customer names, phone numbers and addresses do not reach production logs.
class BookingApiLogger extends Interceptor {
  BookingApiLogger({this.maxBodyChars = 4000, this.label = 'v2'});

  /// Bodies longer than this are truncated, with the omitted length noted.
  ///
  /// The vehicle list can run long; a full dump buries everything around it.
  final int maxBodyChars;

  /// Short tag prefixing every line, so two Dio instances logging into the same
  /// console stay distinguishable (`v2` for the booking API, `api` for the
  /// general one).
  final String label;

  /// Keys whose values are masked wherever they appear in a payload.
  /// Compared after lowercasing and stripping underscores, so `id_token`,
  /// `idToken` and `IDTOKEN` all match the same entry.
  static const Set<String> _sensitiveKeys = {
    'serverkey',
    'clientkey',
    'profileid',
    'token',
    'accesstoken',
    'refreshtoken',
    'authorization',
    'password',
    // Carried by the general API: social sign-in, push registration and OTP
    // verification all put a credential in the request body.
    'idtoken',
    'socialidtoken',
    'fcmtoken',
    'devicetoken',
    'otp',
    'secret',
    'apikey',
  };

  static const JsonEncoder _pretty = JsonEncoder.withIndent('  ');

  /// Monotonic counter so each exchange is identifiable in the log.
  static int _sequence = 0;

  /// Key under which the correlation id and start time ride along on the
  /// request, so the response handler can recover them.
  static const String _traceKey = '_v2_trace';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final trace = _Trace(id: ++_sequence, startedAt: DateTime.now());
    options.extra[_traceKey] = trace;

    final query = options.queryParameters.isEmpty
        ? ''
        : '?${options.queryParameters.entries.map((e) => '${e.key}=${e.value}').join('&')}';

    _line(
      '➡️  $label #${trace.id} │ ${options.method} '
      '${_path(options)}$query',
    );

    final auth = options.headers['Authorization'];
    if (auth is String) {
      _line('   $label #${trace.id} │ auth: ${_maskToken(auth)}');
    }

    if (options.data != null) {
      _body('   $label #${trace.id} │ request', options.data);
    }

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final trace = response.requestOptions.extra[_traceKey];
    final id = trace is _Trace ? trace.id : 0;
    final elapsed = trace is _Trace ? trace.elapsedMs : null;
    final status = response.statusCode ?? 0;

    // 4xx arrives here rather than in onError because the client treats
    // "not serviceable" as a normal, displayable outcome.
    final marker = status >= 400 ? '⚠️ ' : '⬅️ ';

    _line(
      '$marker $label #$id │ $status ${_path(response.requestOptions)}'
      '${elapsed == null ? '' : ' (${elapsed}ms)'}',
    );

    // A binary body (the invoice PDF) is not worth rendering: pretty-printing it
    // would turn a few hundred kilobytes into a multi-megabyte string, so only
    // its size is logged.
    if (response.requestOptions.responseType == ResponseType.bytes) {
      final data = response.data;
      final size = data is List ? data.length : null;
      _line(
        '   $label #$id │ response: <binary${size == null ? '' : ', $size bytes'}>',
      );
    } else {
      _body('   $label #$id │ response', response.data);
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final trace = err.requestOptions.extra[_traceKey];
    final id = trace is _Trace ? trace.id : 0;
    final elapsed = trace is _Trace ? trace.elapsedMs : null;

    _line(
      '❌ $label #$id │ ${err.type.name} ${_path(err.requestOptions)}'
      '${elapsed == null ? '' : ' (${elapsed}ms)'}'
      '${err.response?.statusCode == null ? '' : ' status=${err.response!.statusCode}'}',
    );
    if (err.message != null) {
      _line('   $label #$id │ ${err.message}');
    }
    if (err.response?.data != null) {
      _body('   $label #$id │ error body', err.response!.data);
    }

    handler.next(err);
  }

  /// Path relative to the base URL, so lines stay short and comparable.
  String _path(RequestOptions options) {
    final path = options.path;
    if (path.startsWith('http')) {
      return Uri.tryParse(path)?.path ?? path;
    }
    return path;
  }

  /// Render a payload with secrets masked, wrapped in a labelled block.
  void _body(String label, dynamic data) {
    final rendered = _render(data);
    if (rendered.isEmpty) return;

    _line('$label:');
    for (final line in rendered.split('\n')) {
      // debugPrint throttles by line, so emitting one line at a time keeps the
      // whole payload intact.
      _line('   │ $line');
    }
  }

  /// Exposed so the masking of gateway credentials can be asserted in tests.
  @visibleForTesting
  String renderForTest(dynamic data) => _render(data);

  String _render(dynamic data) {
    try {
      // A multipart body is not JSON-encodable: show its fields, and note each
      // attachment by name and size rather than dumping the bytes.
      if (data is FormData) {
        return _pretty.convert(
          _redact({
            for (final field in data.fields) field.key: field.value,
            for (final file in data.files)
              file.key:
                  '<file ${file.value.filename ?? 'unnamed'}, '
                  '${file.value.length} bytes>',
          }),
        );
      }

      final decoded = data is String ? _tryDecode(data) : data;
      final redacted = _redact(decoded);
      final text = redacted is String ? redacted : _pretty.convert(redacted);
      if (text.length <= maxBodyChars) return text;
      return '${text.substring(0, maxBodyChars)}\n'
          '… truncated ${text.length - maxBodyChars} chars';
    } catch (_) {
      // Never let logging break a request.
      return data.toString();
    }
  }

  dynamic _tryDecode(String raw) {
    final trimmed = raw.trim();
    if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) return raw;
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return raw;
    }
  }

  /// Recursively mask values whose key looks like a credential.
  dynamic _redact(dynamic value) {
    if (value is Map) {
      return value.map((key, child) {
        final normalised = key.toString().toLowerCase().replaceAll('_', '');
        if (_sensitiveKeys.contains(normalised)) {
          return MapEntry(key, _mask(child));
        }
        return MapEntry(key, _redact(child));
      });
    }
    if (value is List) return value.map(_redact).toList();
    return value;
  }

  /// Replace a secret with its length alone.
  ///
  /// No prefix is kept: even a few leading characters of a JWT or gateway key
  /// are more than a log needs, and the length is enough to spot an empty or
  /// truncated value.
  String _mask(dynamic value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty) return '';
    return '<redacted, ${text.length} chars>';
  }

  String _maskToken(String header) {
    final parts = header.split(' ');
    if (parts.length != 2) return _mask(header);
    // The scheme is not a secret, and showing it confirms the header was
    // formed correctly when a request comes back 401.
    return '${parts.first} ${_mask(parts.last)}';
  }

  void _line(String message) => debugPrint(message);
}

/// Correlation id plus start time for one request/response exchange.
class _Trace {
  _Trace({required this.id, required this.startedAt});

  final int id;
  final DateTime startedAt;

  int get elapsedMs => DateTime.now().difference(startedAt).inMilliseconds;
}
