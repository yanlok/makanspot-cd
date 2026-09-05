import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Builds a Google Maps search URL for a restaurant.
///
/// Priority: stored Google Maps URL → coordinates → name/address text search.
/// Returns null if no usable destination can be constructed.
Uri? buildGoogleMapsUrl({
  String? googleMapsUrl,
  double? latitude,
  double? longitude,
  String? name,
  String? address,
}) {
  // Prefer a stored Google Maps link from the original Instagram post.
  if (googleMapsUrl != null && googleMapsUrl.trim().isNotEmpty) {
    final stored = Uri.tryParse(googleMapsUrl.trim());
    if (stored != null && stored.hasScheme && stored.host.isNotEmpty) {
      return stored;
    }
  }

  if (_hasFiniteCoords(latitude, longitude)) {
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '$latitude,$longitude',
    });
  }

  final query = _textFallbackQuery(name, address);
  if (query.isEmpty) return null;

  return Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': query,
  });
}

/// Launches the given Google Maps [url] externally.
///
/// Returns a [MapsLaunchResult] indicating success or a specific failure.
/// This is the only function that touches platform plugins; all URL
/// construction lives in [buildGoogleMapsUrl] for test isolation.
Future<MapsLaunchResult> launchGoogleMaps(Uri url) async {
  if (url.host.isEmpty || url.query.isEmpty) {
    return const MapsLaunchResult.failure('No usable map destination');
  }

  try {
    final canOpen = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (canOpen) {
      return const MapsLaunchResult.success();
    }
    // Fallback: try platform default mode (some platforms need this)
    final canOpenFallback = await launchUrl(
      url,
      mode: LaunchMode.platformDefault,
    );
    if (canOpenFallback) {
      return const MapsLaunchResult.success();
    }
    return const MapsLaunchResult.failure(
      'No app found to open maps on this device',
    );
  } on FormatException catch (e) {
    return MapsLaunchResult.failure('Invalid maps URL: ${e.message}');
  } on Object catch (e) {
    debugPrint('Maps launch error: $e');
    return MapsLaunchResult.failure('Could not open maps. Please try again.');
  }
}

/// Validates that latitude and longitude are finite (not null, NaN, or infinity).
bool _hasFiniteCoords(double? latitude, double? longitude) {
  if (latitude == null || longitude == null) return false;
  if (!latitude.isFinite || !longitude.isFinite) return false;
  return true;
}

/// Builds a text fallback query from name and/or address.
/// Returns empty string if both are null or empty.
String _textFallbackQuery(String? name, String? address) {
  final parts = <String>[
    if (name != null && name.trim().isNotEmpty) name.trim(),
    if (address != null && address.trim().isNotEmpty) address.trim(),
  ];
  return parts.join(' ');
}

/// Result of a maps launch attempt.
class MapsLaunchResult {
  const MapsLaunchResult.success() : isSuccess = true, errorMessage = null;

  const MapsLaunchResult.failure(this.errorMessage) : isSuccess = false;

  final bool isSuccess;
  final String? errorMessage;

  @override
  String toString() => isSuccess
      ? 'MapsLaunchResult.success'
      : 'MapsLaunchResult.failure($errorMessage)';
}
