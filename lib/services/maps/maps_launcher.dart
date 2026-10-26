import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/enums.dart';
import '../../models/place.dart';

/// Opens places and routes in an external maps app via public URLs.
/// No API key, no paid API, and no location permission in this app:
/// the maps app handles "current location" itself.
class MapsLauncher {
  const MapsLauncher();

  bool get _useAppleMaps => defaultTargetPlatform == TargetPlatform.iOS && !kIsWeb;

  Uri placeUri(Place place) {
    final ll = '${place.latitude},${place.longitude}';
    if (_useAppleMaps) {
      return Uri.https('maps.apple.com', '/', {'q': place.nameEn, 'll': ll});
    }
    return Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': ll});
  }

  Uri directionsUri(Place place, TransportMode mode) {
    final ll = '${place.latitude},${place.longitude}';
    if (_useAppleMaps) {
      final flag = mode == TransportMode.walking ? 'w' : 'd';
      return Uri.https('maps.apple.com', '/', {'daddr': ll, 'dirflg': flag});
    }
    return Uri.https('www.google.com', '/maps/dir/',
        {'api': '1', 'destination': ll, 'travelmode': _googleMode(mode)});
  }

  /// Multi-stop route for a day. Apple Maps URLs do not support waypoints,
  /// so this always uses Google Maps (app or browser).
  Uri? dayRouteUri(List<Place> stops, TransportMode mode) {
    if (stops.length < 2) return null;
    String ll(Place p) => '${p.latitude},${p.longitude}';
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'origin': ll(stops.first),
      'destination': ll(stops.last),
      if (stops.length > 2)
        'waypoints': stops.sublist(1, stops.length - 1).map(ll).join('|'),
      'travelmode': _googleMode(mode),
    });
  }

  static String _googleMode(TransportMode mode) => switch (mode) {
        TransportMode.walking => 'walking',
        TransportMode.bicycle => 'bicycling',
        TransportMode.motorbike => 'two-wheeler',
        TransportMode.taxi || TransportMode.privateCar => 'driving',
      };
}

/// Returns false when no app could handle the link.
Future<bool> openExternal(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('Could not open $uri: $e');
    return false;
  }
}
