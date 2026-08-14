import 'package:premium_force_main/utils/json_utils.dart';

/// What the chauffeur product currently offers, from `GET /chauffeur/options`.
///
/// The bookable durations are configured in the admin panel, so the picker is
/// populated from here rather than from a client-side list that would drift out
/// of date. The endpoint is public — it is called before the user has entered
/// anything that would require a session.

/// The two ways a chauffeur can be booked.
///
/// Session init names the duration field differently for each, so the type and
/// the field it implies are kept together here rather than at the call site.
enum ChauffeurType {
  /// Custom hours within the [HourlyChauffeurOption] bounds.
  hourly,

  /// One of the pre-configured fixed packages.
  package;

  /// Value for the `chauffeurType` request field.
  String get wireValue => switch (this) {
    hourly => 'hourly',
    package => 'package',
  };

  /// Request field carrying the duration: `hours` hourly, `durationHours` for a
  /// package. Sending the wrong one is rejected by the backend.
  String get durationField => switch (this) {
    hourly => 'hours',
    package => 'durationHours',
  };
}

/// Bounds for open-ended hourly hire.
class HourlyChauffeurOption {
  const HourlyChauffeurOption({
    required this.available,
    this.minHours = 1,
    this.maxHours = 24,
  });

  /// Whether hourly hire is enabled at all.
  final bool available;

  final int minHours;
  final int maxHours;

  factory HourlyChauffeurOption.fromJson(Map<String, dynamic> json) {
    return HourlyChauffeurOption(
      available:
          pickBool(json, const ['available', 'isAvailable', 'enabled']) ?? false,
      minHours: pickInt(json, const ['minHours', 'min', 'min_hours']) ?? 1,
      maxHours: pickInt(json, const ['maxHours', 'max', 'max_hours']) ?? 24,
    );
  }

  /// Every hour between [minHours] and [maxHours], or empty when hourly hire is
  /// off or the bounds are inverted.
  List<int> get range {
    if (!available || maxHours < minHours) return const [];
    return [for (var hours = minHours; hours <= maxHours; hours++) hours];
  }
}

/// The chauffeur discovery payload: hourly bounds plus the fixed packages.
class ChauffeurOptions {
  const ChauffeurOptions({required this.hourly, this.packages = const []});

  final HourlyChauffeurOption hourly;

  /// Fixed package durations in hours, e.g. `[4, 6, 8, 12]`, ascending.
  final List<int> packages;

  factory ChauffeurOptions.fromJson(Map<String, dynamic> json) {
    return ChauffeurOptions(
      hourly: HourlyChauffeurOption.fromJson(
        pickMap(json, const ['hourly', 'hourlyChauffeur']),
      ),
      packages: _hours(pickRaw(json, const ['packages', 'packageHours'])),
    );
  }

  /// Whether anything is bookable at all. False when the product is switched
  /// off entirely, or when the payload could not be read.
  bool get hasBookableDurations =>
      packages.isNotEmpty || hourly.range.isNotEmpty;

  /// Read a duration list, tolerating entries that arrive as objects rather
  /// than bare numbers. Deduplicated and sorted so the picker reads in order.
  static List<int> _hours(dynamic raw) {
    if (raw is! List) return const [];

    final hours = <int>{};
    for (final entry in raw) {
      final value = entry is Map
          ? pickInt(asMap(entry), const ['hours', 'duration', 'durationHours'])
          : asInt(entry);
      if (value != null && value > 0) hours.add(value);
    }

    return hours.toList()..sort();
  }
}
