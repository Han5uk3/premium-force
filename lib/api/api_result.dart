/// Typed outcome of a v2 API call.
///
/// The v2 session endpoints return user-facing messages that the booking UI is
/// expected to show verbatim (e.g. *"Pickup location is outside our supported
/// transfer zones"*), so [message] is carried on both the success and failure
/// paths rather than being flattened into a generic error.
class ApiResult<T> {
  const ApiResult.ok(T this.data, {this.message})
    : success = true,
      statusCode = 200;

  const ApiResult.failure(this.message, {this.statusCode})
    : success = false,
      data = null;

  final bool success;
  final T? data;

  /// Server-supplied message. Safe to display when [success] is false.
  final String? message;

  final int? statusCode;

  /// True when the call succeeded and actually carried a payload.
  bool get hasData => success && data != null;

  /// The payload, or [fallback] when the call failed.
  T orElse(T fallback) => data ?? fallback;

  /// Re-wrap a failure for a different payload type, preserving the diagnostics.
  ApiResult<R> castFailure<R>() =>
      ApiResult<R>.failure(message, statusCode: statusCode);

  /// Transform the payload, leaving failures untouched.
  ApiResult<R> map<R>(R Function(T value) transform) {
    final value = data;
    if (!success || value == null) return castFailure<R>();
    return ApiResult<R>.ok(transform(value), message: message);
  }

  @override
  String toString() =>
      'ApiResult(success: $success, statusCode: $statusCode, message: $message)';
}
