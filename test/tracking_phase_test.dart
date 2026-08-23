import 'package:flutter_test/flutter_test.dart';
import 'package:premium_force_main/models/v2/booking_v2.dart';
import 'package:premium_force_main/services/driver_location_service.dart';

/// Guards on the two-leg tracking contract between the apps.
///
/// The driver app publishes which leg it is driving; this app draws it. The
/// wire values are the contract, so a rename on either side has to break a test
/// rather than silently leave every customer looking at the wrong destination.
void main() {
  group('TrackingPhase.fromWire', () {
    test('reads the values the driver app publishes', () {
      expect(TrackingPhase.fromWire('to_pickup'), TrackingPhase.toPickup);
      expect(TrackingPhase.fromWire('to_dropoff'), TrackingPhase.toDropOff);
      expect(TrackingPhase.fromWire('in_progress'), TrackingPhase.inProgress);
    });

    test('falls back to the approach for a session with no phase', () {
      // Sessions opened by a driver build older than the two-leg split carry no
      // phase at all, and behaved as the approach leg.
      expect(TrackingPhase.fromWire(null), TrackingPhase.toPickup);
      expect(TrackingPhase.fromWire(''), TrackingPhase.toPickup);
      expect(TrackingPhase.fromWire('something-else'), TrackingPhase.toPickup);
    });

    test('only the hourly-hire leg has nothing to route to', () {
      expect(TrackingPhase.toPickup.hasDestination, isTrue);
      expect(TrackingPhase.toDropOff.hasDestination, isTrue);
      expect(TrackingPhase.inProgress.hasDestination, isFalse);
    });
  });

  group('BookingStatusV2.isTrackable', () {
    test('covers the whole window the driver app publishes through', () {
      // Opens when the driver sets off, so the customer can watch the car
      // approach rather than only once they are already in it.
      expect(BookingStatusV2.driverEnRoute.isTrackable, isTrue);
      expect(BookingStatusV2.driverArrived.isTrackable, isTrue);
      expect(BookingStatusV2.tripStarted.isTrackable, isTrue);

      expect(BookingStatusV2.driverAssigned.isTrackable, isFalse);
      expect(BookingStatusV2.confirmed.isTrackable, isFalse);
      expect(BookingStatusV2.completed.isTrackable, isFalse);
      expect(BookingStatusV2.cancelled.isTrackable, isFalse);
    });
  });
}
