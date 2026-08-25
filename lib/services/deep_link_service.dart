/// Incoming App Links, and where they land in the app.
///
/// A link is only ever a request to open something the app already has a
/// screen for; nothing here fetches or decides anything itself. The whole job
/// is three steps: recognise a URL as ours, work out which booking it names,
/// and push that booking's page once there is a navigator able to receive it.
///
/// Two things make the last step less obvious than it sounds:
///
/// * **A cold start has no navigator yet.** Tapping a link on a closed app
///   launches it at the splash screen, which spends three seconds checking
///   auth before it decides between [Home] and the login page. Pushing the
///   booking during that window would either throw or be replaced a moment
///   later by the splash's own `pushReplacement`. So an early link is *held*
///   and replayed from [notifyReady].
/// * **A signed-out customer cannot be shown a booking.** Held links survive
///   the login screen and open once the customer reaches [Home], which is the
///   one screen every authenticated path lands on — from the splash, from
///   login, from OTP, and from signup. That is why [notifyReady] is called
///   there rather than in five separate places.
library;

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:premium_force_main/bookings/booking_details_page.dart';
import 'package:premium_force_main/main.dart' show navigatorKey;
import 'package:premium_force_main/utils/screen_logger.dart';

/// Console tag prefixing this service's log lines.
const String _log = 'deep-link';

/// Hosts whose links this app answers for.
///
/// Both spellings of the domain are listed because a link can be written
/// either way and Android matches the host exactly — the same pair is declared
/// in `AndroidManifest.xml` and `Runner.entitlements`, and the three have to
/// agree or the link opens in a browser instead.
const Set<String> kAppLinkHosts = {
  'premiumforcegroup.com',
  'www.premiumforcegroup.com',
};

/// The one path shape the app claims: `/booking/<bookingId>`.
const String _bookingSegment = 'booking';

class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  /// A link that arrived before the app could act on it.
  ///
  /// Only the most recent is kept: if two links arrive during startup the
  /// customer meant the second one, and opening both would leave the first
  /// stranded under the second in the navigation stack.
  Uri? _pending;

  /// Whether [notifyReady] has been reached, i.e. whether a push would land.
  bool _isReady = false;

  /// The cold-start link, remembered so the stream cannot open it twice.
  ///
  /// Android delivers the launching intent to [AppLinks.uriLinkStream] as well
  /// as to [AppLinks.getInitialLink], so without this guard a link that opened
  /// the app would push the booking page two deep. Only the first stream
  /// emission is checked against it — tapping the *same* link again later is a
  /// real request and still opens.
  Uri? _initialLink;
  bool _sawFirstStreamEvent = false;

  /// Start listening. Safe to call more than once; only the first call binds.
  Future<void> init() async {
    if (_subscription != null) return;

    _subscription = _appLinks.uriLinkStream.listen(
      _onLink,
      onError: (Object error) => logScreen(_log, 'stream error: $error'),
    );

    // Read the launching link separately: on a cold start the stream may not
    // be listening yet when the intent is delivered.
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        _initialLink = initial;
        logScreen(_log, 'cold start via $initial');
        _onLink(initial);
      }
    } catch (error) {
      logScreen(_log, 'could not read initial link: $error');
    }
  }

  /// Called once the app is showing a screen a booking can be pushed onto.
  ///
  /// [Home.initState] is the caller: every authenticated entry path passes
  /// through it, so a link held across the splash or across a whole login
  /// opens here without either of those screens knowing about deep links.
  void notifyReady() {
    _isReady = true;

    final held = _pending;
    if (held == null) return;
    _pending = null;

    logScreen(_log, 'replaying held link $held');
    // The frame that builds Home is still in flight; pushing inside it would
    // mutate the tree mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _open(held));
  }

  /// Forget any held link, e.g. on sign-out, so it cannot open for whoever
  /// signs in next.
  void clearPending() {
    if (_pending != null) logScreen(_log, 'discarded held link $_pending');
    _pending = null;
    _isReady = false;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  void _onLink(Uri uri) {
    // Skip the stream's echo of the launching intent — see [_initialLink].
    if (!_sawFirstStreamEvent && _initialLink != null && uri == _initialLink) {
      _sawFirstStreamEvent = true;
      return;
    }
    _sawFirstStreamEvent = true;

    final bookingId = bookingIdFrom(uri);
    if (bookingId == null) {
      // Not a shape the app claims. Nothing to do: Android only routes what
      // the manifest matched, but a link can still arrive malformed.
      logScreen(_log, 'ignored $uri (no booking id)');
      return;
    }

    if (!_isReady) {
      logScreen(_log, 'holding $uri until the app is ready');
      _pending = uri;
      return;
    }

    _open(uri);
  }

  void _open(Uri uri) {
    final bookingId = bookingIdFrom(uri);
    if (bookingId == null) return;

    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      // Readiness was reported but the navigator has gone — hold rather than
      // drop, so the link is not lost.
      logScreen(_log, 'no navigator; holding $uri');
      _pending = uri;
      return;
    }

    logScreen(_log, 'opening booking $bookingId');
    navigator.push(
      MaterialPageRoute(
        builder: (_) => BookingDetailsPage(bookingId: bookingId),
      ),
    );
  }
}

/// The booking id a link names, or null when it names none.
///
/// Accepts `https://<host>/booking/<id>` on either spelling of the domain, and
/// tolerates a trailing slash or extra segments after the id so a longer URL
/// (`/booking/<id>/track`) still opens the booking rather than nothing.
///
/// Deliberately strict about scheme and host: an App Link is always https, and
/// matching a host the manifest never claimed would open a page for a URL the
/// app was not verified for.
@visibleForTesting
String? bookingIdFrom(Uri uri) {
  if (uri.scheme != 'https') return null;
  if (!kAppLinkHosts.contains(uri.host.toLowerCase())) return null;

  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.length < 2) return null;
  if (segments.first.toLowerCase() != _bookingSegment) return null;

  final id = segments[1].trim();
  return id.isEmpty ? null : id;
}
