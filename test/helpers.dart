import 'package:vietnam_tripmate/models/enums.dart';
import 'package:vietnam_tripmate/models/place.dart';
import 'package:vietnam_tripmate/models/trip.dart';

Place place(
  String id, {
  String destination = 'd1',
  String area = 'A',
  double lat = 16.0,
  double lng = 108.0,
  Set<Interest> interests = const {Interest.culture},
  int minutes = 60,
  Set<DaySlot> slots = const {},
  String? name,
  String? local,
}) =>
    Place(
      id: id,
      nameEn: name ?? id,
      nameLocal: local,
      destinationId: destination,
      area: area,
      latitude: lat,
      longitude: lng,
      category: PlaceCategory.landmark,
      interests: interests,
      description: 'test',
      suggestedDurationMinutes: minutes,
      bestSlots: slots,
      source: 'test',
      verificationStatus: VerificationStatus.unverified,
    );

Trip trip({
  int days = 2,
  List<String> destinations = const ['d1'],
  Set<Interest> interests = const {},
  Pace pace = Pace.balanced,
  TransportMode transport = TransportMode.taxi,
}) {
  final start = DateTime.utc(2026, 11, 2);
  return Trip(
    id: 'trip1',
    title: 'Test',
    origin: 'Airport',
    destinationIds: destinations,
    startDate: start,
    endDate: start.add(Duration(days: days - 1)),
    travelers: 2,
    currency: 'USD',
    interests: interests,
    pace: pace,
    transport: transport,
    createdAt: start,
    updatedAt: start,
  );
}

/// Deterministic ID generator for tests.
String Function(String) sequentialIds() {
  var n = 0;
  return (prefix) => '${prefix}_${n++}';
}
