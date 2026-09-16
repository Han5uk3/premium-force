import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:premium_force_main/services/crash_reporting.dart';
import 'package:url_launcher/url_launcher.dart';

/// How the installed build compares to what Remote Config asks for.
enum AppUpdateStatus {
  /// Nothing to do.
  upToDate,

  /// A newer build is out; offer it, but let the customer carry on.
  optional,

  /// This build is no longer supported; the app must not be used until updated.
  required,
}

/// Decides whether the installed build has to be updated, from Firebase Remote
/// Config.
///
/// The driver app shares this Firebase project, so each app reads its own
/// parameter — this one reads `customer_app_update`, a JSON value shaped:
///
/// ```json
/// {
///   "android": { "min_build": 60, "latest_build": 61, "store_url": "..." },
///   "ios":     { "min_build": 60, "latest_build": 61, "store_url": "..." }
/// }
/// ```
///
/// * `min_build` — any installed build below it is blocked.
/// * `latest_build` — any installed build below it is offered the update.
/// * `store_url` — optional; the store listing is used when absent.
///
/// Builds are compared by build number (the `+60` in `version: 1.5.0+60`),
/// not by version name: the stores already show different version names for
/// the same app, so only the build number is reliable. The platforms are set
/// separately because an iOS release can sit in review days after Android's.
///
/// Every failure — no network, a malformed value, an unreadable build number —
/// resolves to [AppUpdateStatus.upToDate]. A broken config must never lock
/// customers out of the app.
class AppUpdateService {
  AppUpdateService._();

  static const String _parameter = 'customer_app_update';

  static const String _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.brandbik.premiumforce';
  static const String _appStoreUrl = 'https://apps.apple.com/app/id6759467571';

  /// How long the splash waits for a fresh config before deciding on the last
  /// one fetched. The fetch keeps going and is activated for the next launch.
  static const Duration _fetchWait = Duration(seconds: 4);

  static FirebaseRemoteConfig get _config => FirebaseRemoteConfig.instance;

  static bool _initialised = false;

  /// Configure Remote Config and start listening for published changes.
  ///
  /// The listener activates a new value as soon as it is published, so the
  /// very next launch enforces it without waiting for the fetch interval.
  static Future<void> _init() async {
    if (_initialised) return;
    _initialised = true;

    await _config.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: kDebugMode
            ? Duration.zero
            : const Duration(hours: 1),
      ),
    );
    await _config.setDefaults({_parameter: '{}'});

    _config.onConfigUpdated.listen(
      (update) {
        if (update.updatedKeys.contains(_parameter)) _config.activate();
      },
      // The real-time channel drops on flaky networks; the next launch's fetch
      // covers it, so there is nothing to recover here.
      onError: (_) {},
    );
  }

  /// Check the installed build against the latest config.
  ///
  /// Never throws.
  static Future<AppUpdateStatus> check() async {
    try {
      await _init();
      try {
        await _config.fetchAndActivate().timeout(_fetchWait);
      } catch (_) {
        // Offline or slow: decide on the last activated config instead.
      }

      final rules = _platformRules();
      if (rules == null) return AppUpdateStatus.upToDate;

      final info = await PackageInfo.fromPlatform();
      final installed = int.tryParse(info.buildNumber);
      if (installed == null) return AppUpdateStatus.upToDate;

      final minBuild = _readInt(rules['min_build']);
      final latestBuild = _readInt(rules['latest_build']);

      if (minBuild != null && installed < minBuild) {
        return AppUpdateStatus.required;
      }
      if (latestBuild != null && installed < latestBuild) {
        return AppUpdateStatus.optional;
      }
      return AppUpdateStatus.upToDate;
    } catch (e, stack) {
      CrashReporting.recordError(e, stack, reason: 'App update check failed');
      return AppUpdateStatus.upToDate;
    }
  }

  /// Open this app's page in the platform's store.
  static Future<void> openStore() async {
    final configured = _platformRules()?['store_url'];
    final url = configured is String && configured.isNotEmpty
        ? configured
        : (Platform.isIOS ? _appStoreUrl : _playStoreUrl);

    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      // No store or browser to hand off to — the button just does nothing.
    }
  }

  /// This platform's block of the config, or null when it has none.
  static Map<String, dynamic>? _platformRules() {
    try {
      final decoded = jsonDecode(_config.getString(_parameter));
      if (decoded is! Map<String, dynamic>) return null;
      final rules = decoded[Platform.isIOS ? 'ios' : 'android'];
      return rules is Map<String, dynamic> ? rules : null;
    } catch (_) {
      return null;
    }
  }

  /// Accepts `60` and `"60"` alike — the console makes it easy to type either.
  static int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}
