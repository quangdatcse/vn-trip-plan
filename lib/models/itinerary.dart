import '../core/utils/dates.dart';
import 'enums.dart';
import 'trip.dart';

class ItineraryItem {
  const ItineraryItem({
    required this.id,
    required this.dayId,
    required this.placeId,
    required this.slot,
    required this.position,
    required this.durationMinutes,
    this.travelMinutesFromPrevious,
    this.travelDistanceKm,
    this.note,
  });

  final String id;
  final String dayId;
  final String placeId;
  final DaySlot slot;
  final int position;
  final int durationMinutes;

  /// Rough estimate from the previous stop of the day. Never live routing.
  final int? travelMinutesFromPrevious;
  final double? travelDistanceKm;
  final String? note;

  ItineraryItem copyWith({
    String? placeId,
    DaySlot? slot,
    int? position,
    int? durationMinutes,
    int? Function()? travelMinutesFromPrevious,
    double? Function()? travelDistanceKm,
  }) =>
      ItineraryItem(
        id: id,
        dayId: dayId,
        placeId: placeId ?? this.placeId,
        slot: slot ?? this.slot,
        position: position ?? this.position,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        travelMinutesFromPrevious: travelMinutesFromPrevious != null
            ? travelMinutesFromPrevious()
            : this.travelMinutesFromPrevious,
        travelDistanceKm:
            travelDistanceKm != null ? travelDistanceKm() : this.travelDistanceKm,
        note: note,
      );

  factory ItineraryItem.fromMap(Map<String, Object?> map) => ItineraryItem(
        id: map['id'] as String,
        dayId: map['day_id'] as String,
        placeId: map['place_id'] as String,
        slot: enumFromName(DaySlot.values, map['slot'] as String?, DaySlot.morning),
        position: (map['position'] as num).toInt(),
        durationMinutes: (map['duration_min'] as num).toInt(),
        travelMinutesFromPrevious: (map['travel_min_from_prev'] as num?)?.toInt(),
        travelDistanceKm: (map['travel_km_from_prev'] as num?)?.toDouble(),
        note: map['note'] as String?,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'day_id': dayId,
        'place_id': placeId,
        'slot': slot.name,
        'position': position,
        'duration_min': durationMinutes,
        'travel_min_from_prev': travelMinutesFromPrevious,
        'travel_km_from_prev': travelDistanceKm,
        'note': note,
      };
}

class ItineraryDay {
  const ItineraryDay({
    required this.id,
    required this.tripId,
    required this.dayIndex,
    required this.date,
    required this.destinationId,
    required this.items,
  });

  final String id;
  final String tripId;

  /// Zero-based.
  final int dayIndex;
  final DateTime date;
  final String destinationId;
  final List<ItineraryItem> items;

  /// Items in visiting order: by slot, then position.
  List<ItineraryItem> get orderedItems => [...items]
    ..sort((a, b) {
      final bySlot = a.slot.index.compareTo(b.slot.index);
      return bySlot != 0 ? bySlot : a.position.compareTo(b.position);
    });

  List<ItineraryItem> itemsIn(DaySlot slot) =>
      orderedItems.where((i) => i.slot == slot).toList();

  ItineraryDay withItems(List<ItineraryItem> items) => ItineraryDay(
        id: id,
        tripId: tripId,
        dayIndex: dayIndex,
        date: date,
        destinationId: destinationId,
        items: List.unmodifiable(items),
      );

  factory ItineraryDay.fromMap(Map<String, Object?> map, List<ItineraryItem> items) =>
      ItineraryDay(
        id: map['id'] as String,
        tripId: map['trip_id'] as String,
        dayIndex: (map['day_index'] as num).toInt(),
        date: parseDate(map['date'] as String),
        destinationId: map['destination_id'] as String,
        items: items,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'trip_id': tripId,
        'day_index': dayIndex,
        'date': formatIsoDate(date),
        'destination_id': destinationId,
      };
}

class TripPlan {
  const TripPlan({required this.trip, required this.days});

  final Trip trip;
  final List<ItineraryDay> days;

  Set<String> get placeIds =>
      {for (final day in days) for (final item in day.items) item.placeId};

  TripPlan replaceDay(ItineraryDay day) => TripPlan(
        trip: trip,
        days: [for (final d in days) d.id == day.id ? day : d],
      );
}
