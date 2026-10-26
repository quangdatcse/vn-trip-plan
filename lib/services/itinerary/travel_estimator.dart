import '../../core/utils/geo.dart';
import '../../models/enums.dart';
import '../../models/place.dart';

class TravelEstimate {
  const TravelEstimate({required this.minutes, required this.distanceKm});
  final int minutes;
  final double distanceKm;
}

/// Offline travel-time estimate. No routing data is used, so results are
/// always labelled as estimates in the UI.
class TravelEstimator {
  const TravelEstimator();

  /// Roads are rarely straight; 1.4 is a common rule of thumb for cities.
  static const roadFactor = 1.4;

  static const explanation =
      'Rough estimate: straight-line distance × $roadFactor at a typical average '
      'speed. Not based on live routing or traffic.';

  static double speedKmh(TransportMode mode) => switch (mode) {
        TransportMode.walking => 4.5,
        TransportMode.bicycle => 12,
        TransportMode.motorbike => 25,
        TransportMode.taxi => 25,
        TransportMode.privateCar => 25,
      };

  /// Time to find a ride or park.
  static int overheadMinutes(TransportMode mode) =>
      mode == TransportMode.walking ? 0 : 5;

  TravelEstimate estimate(Place from, Place to, TransportMode mode) {
    final km = haversineKm(from.latitude, from.longitude, to.latitude, to.longitude) *
        roadFactor;
    final raw = km / speedKmh(mode) * 60 + overheadMinutes(mode);
    // Round up to 5 minutes, minimum 5.
    final minutes = ((raw / 5).ceil() * 5).clamp(5, 24 * 60).toInt();
    return TravelEstimate(minutes: minutes, distanceKm: double.parse(km.toStringAsFixed(1)));
  }
}
