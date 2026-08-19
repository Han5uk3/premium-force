/// Defensive JSON coercion helpers.
///
/// The v2 backend response shapes are still being finalised, so the models in
/// `lib/models/v2/` parse through these helpers instead of casting directly.
/// They tolerate missing keys, alternate key spellings (`_id` vs `id` vs
/// `vehicleId`), and values arriving as the wrong primitive type — a common
/// occurrence with loosely-typed JSON.
///
/// Usage:
/// ```dart
/// final id = pickString(json, ['_id', 'id', 'vehicleId']);
/// final fare = pickDouble(json, ['baseFare', 'base_fare']) ?? 0;
/// ```
library;

/// Return the first non-null value among [keys], or `null` if none are present.
dynamic pickRaw(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value != null) return value;
  }
  return null;
}

/// Coerce [value] to a `String`, treating empty strings as absent.
String? asString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value.trim().isEmpty ? null : value;
  return value.toString();
}

/// Coerce [value] to a `double`, parsing numeric strings.
double? asDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

/// Coerce [value] to an `int`, parsing numeric strings and truncating doubles.
int? asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final trimmed = value.trim();
    return int.tryParse(trimmed) ?? double.tryParse(trimmed)?.toInt();
  }
  return null;
}

/// Coerce [value] to a `bool`, accepting `"true"`/`"false"` and `1`/`0`.
bool? asBool(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalised = value.trim().toLowerCase();
    if (normalised == 'true' || normalised == '1' || normalised == 'yes') {
      return true;
    }
    if (normalised == 'false' || normalised == '0' || normalised == 'no') {
      return false;
    }
  }
  return null;
}

/// Coerce [value] to a JSON object, returning an empty map when it is not one.
Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
  return const {};
}

/// Coerce [value] to a list of JSON objects, discarding non-object entries.
List<Map<String, dynamic>> asMapList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map(asMap)
      .where((entry) => entry.isNotEmpty)
      .toList();
}

/// Parse [value] as a `DateTime`, accepting ISO-8601 and epoch milliseconds.
DateTime? asDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) return parsed;
    final epoch = int.tryParse(trimmed);
    if (epoch != null) {
      return DateTime.fromMillisecondsSinceEpoch(epoch, isUtc: true);
    }
  }
  return null;
}

// -----------------------------------------------------------------------------
// Keyed lookups — read the first present key and coerce in one step.
// -----------------------------------------------------------------------------

String? pickString(Map<String, dynamic> json, List<String> keys) =>
    asString(pickRaw(json, keys));

double? pickDouble(Map<String, dynamic> json, List<String> keys) =>
    asDouble(pickRaw(json, keys));

int? pickInt(Map<String, dynamic> json, List<String> keys) =>
    asInt(pickRaw(json, keys));

bool? pickBool(Map<String, dynamic> json, List<String> keys) =>
    asBool(pickRaw(json, keys));

Map<String, dynamic> pickMap(Map<String, dynamic> json, List<String> keys) =>
    asMap(pickRaw(json, keys));

List<Map<String, dynamic>> pickMapList(
  Map<String, dynamic> json,
  List<String> keys,
) => asMapList(pickRaw(json, keys));

DateTime? pickDateTime(Map<String, dynamic> json, List<String> keys) =>
    asDateTime(pickRaw(json, keys));

/// Resolve an entity id that may arrive either as a bare string or as a
/// populated sub-document (`{"_id": "...", "name": "..."}`).
///
/// Mongo-backed endpoints switch between these two shapes depending on whether
/// the field was populated, so ids are read through this helper.
String? pickId(Map<String, dynamic> json, List<String> keys) {
  final raw = pickRaw(json, keys);
  if (raw is Map) {
    return pickString(asMap(raw), const ['_id', 'id']);
  }
  return asString(raw);
}
