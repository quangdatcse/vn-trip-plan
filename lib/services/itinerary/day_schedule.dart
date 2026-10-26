import '../../models/enums.dart';
import '../../models/itinerary.dart';

class ScheduledStop {
  const ScheduledStop(this.item, this.startMinute);

  final ItineraryItem item;

  /// Suggested start, minutes after midnight.
  final int startMinute;
  int get endMinute => startMinute + item.durationMinutes;
}

/// Suggested start times: each slot starts at its window, each stop starts
/// after the previous one plus estimated travel. A long visit pushes later
/// slots back. These are suggestions, not bookings or opening hours.
List<ScheduledStop> scheduleDay(ItineraryDay day) {
  final result = <ScheduledStop>[];
  int? cursor;
  for (final slot in DaySlot.values) {
    for (final item in day.itemsIn(slot)) {
      final travel = item.travelMinutesFromPrevious ?? 0;
      final earliest = cursor == null ? slot.startMinute : cursor + travel;
      final start = earliest < slot.startMinute ? slot.startMinute : earliest;
      result.add(ScheduledStop(item, start));
      cursor = start + item.durationMinutes;
    }
  }
  return result;
}

/// e.g. "08:30". Wraps past midnight.
String formatClock(int minutes) {
  final m = minutes % (24 * 60);
  return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
}
