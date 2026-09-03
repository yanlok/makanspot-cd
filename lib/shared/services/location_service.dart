import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator/geolocator.dart' as gl;

/// Outcome of attempting to resolve the device location.
///
/// Distinct from a `Position` so callers can react to "denied" / "service off"
/// without resorting to `try/catch` on a `Position?`.
enum LocationOutcome {
  success,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  unknown,
}

@immutable
class LocationFix {
  const LocationFix({required this.position, required this.fromCache});

  final Position position;

  /// `true` when this fix came from `getLastKnownPosition` instead of a fresh
  /// GPS sample. Useful for callers that want to treat stale fixes differently.
  final bool fromCache;
}

@immutable
class LocationRequestResult {
  const LocationRequestResult({required this.outcome, this.fix});

  final LocationOutcome outcome;
  final LocationFix? fix;

  bool get hasFix => fix != null;

  Position? get position => fix?.position;
}

/// Free, on-device geolocation helper built on `geolocator`. It encapsulates:
///
/// 1. Checking that the platform location service is on.
/// 2. Prompting the user for `LocationPermission.whileInUse` when needed.
/// 3. Returning a cached last-known fix when it's recent enough to be useful.
/// 4. Falling back to a fresh `getCurrentPosition` with a bounded timeout.
///
/// No network calls and no paid APIs are involved — the device GPS / fused
/// location provider does the work.
class LocationService {
  LocationService({
    GeolocatorAdapter? adapter,
    Duration freshFixTimeout = const Duration(seconds: 6),
    Duration maximumCachedAge = const Duration(minutes: 10),
  })  : _adapter = adapter ?? const GeolocatorAdapter(),
        _freshFixTimeout = freshFixTimeout,
        _maximumCachedAge = maximumCachedAge;

  final GeolocatorAdapter _adapter;
  final Duration _freshFixTimeout;
  final Duration _maximumCachedAge;

  /// Resolves the best available fix for the current device.
  ///
  /// Order of preference: cached fix (when fresh enough) → fresh fix. Both
  /// are returned when available, so the caller can decide what to do when
  /// the fresh request times out (the cached fix is often good enough).
  Future<LocationRequestResult> requestCurrentLocation() async {
    try {
      final serviceEnabled = await _adapter.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationRequestResult(outcome: LocationOutcome.serviceDisabled);
      }

      final permission = await _ensurePermission();
      switch (permission) {
        case LocationPermission.denied:
          return const LocationRequestResult(outcome: LocationOutcome.permissionDenied);
        case LocationPermission.deniedForever:
          return const LocationRequestResult(
            outcome: LocationOutcome.permissionDeniedForever,
          );
        case LocationPermission.whileInUse:
        case LocationPermission.always:
        case LocationPermission.unableToDetermine:
          break;
      }

      Position? cached;
      try {
        final lastKnown = await _adapter.getLastKnownPosition();
        if (lastKnown != null &&
            DateTime.now().difference(lastKnown.timestamp) <= _maximumCachedAge) {
          cached = lastKnown;
        }
      } catch (error) {
        debugPrint('Unable to read cached location: $error');
      }

      try {
        final fresh = await _adapter.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: _freshFixTimeout,
          ),
        );
        return LocationRequestResult(
          outcome: LocationOutcome.success,
          fix: LocationFix(position: fresh, fromCache: false),
        );
      } catch (error) {
        debugPrint('Unable to fetch fresh location: $error');
        if (cached != null) {
          return LocationRequestResult(
            outcome: LocationOutcome.success,
            fix: LocationFix(position: cached, fromCache: true),
          );
        }
        return const LocationRequestResult(outcome: LocationOutcome.timeout);
      }
    } catch (error) {
      debugPrint('Unexpected location error: $error');
      return const LocationRequestResult(outcome: LocationOutcome.unknown);
    }
  }

  Future<LocationPermission> _ensurePermission() async {
    var permission = await _adapter.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _adapter.requestPermission();
    }
    return permission;
  }
}

/// Thin wrapper around `geolocator` so the service can be unit-tested without
/// pulling in the platform channel.
@immutable
class GeolocatorAdapter {
  const GeolocatorAdapter();

  Future<bool> isLocationServiceEnabled() => Geolocator.isLocationServiceEnabled();

  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  Future<LocationPermission> requestPermission() => Geolocator.requestPermission();

  Future<Position?> getLastKnownPosition() => Geolocator.getLastKnownPosition();

  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) {
    return Geolocator.getCurrentPosition(
      locationSettings: locationSettings,
    );
  }
}

/// Re-export `geolocator`'s types through this file so callers don't have to
/// import the plugin directly. Keeps the public surface narrow.
typedef Position = gl.Position;
typedef LocationPermission = gl.LocationPermission;
typedef LocationAccuracy = gl.LocationAccuracy;
typedef LocationSettings = gl.LocationSettings;