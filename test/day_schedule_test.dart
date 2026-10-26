import 'package:flutter_test/flutter_test.dart';
import 'package:vietnam_tripmate/features/explore/search_screen.dart';
import 'package:vietnam_tripmate/features/itinerary/trip_actions.dart';
import 'package:vietnam_tripmate/models/enums.dart';
import 'package:vietnam_tripmate/models/itinerary.dart';
import 'package:vietnam_tripmate/services/itinerary/day_schedule.dart';

import 'helpers.dart';

ItineraryItem item(String id, DaySlot slot, int position, int minutes, {int? travel}) => ItineraryItem(
      id: id,
      dayId: 'day',
      placeId: id,
      slot: slot,
      position: position,
      durationMinutes: minutes,
      travelMinutesFromPrevious: travel,
    );

ItineraryDay day(List<ItineraryItem> items) => ItineraryDay(
      id: 'day',
      tripId: 't',
      dayIndex: 0,
      date: DateTime.utc(2026, 11, 2),
      destinationId: 'd1',
      items: items,
    );

void main() {
  group('scheduleDay', () {
    test('starts each slot at its window and adds travel between stops', () {
      final s = scheduleDay(day([
        item('a', DaySlot.morning, 0, 60),
        item('b', DaySlot.morning, 1, 30, travel: 15),
        item('c', DaySlot.evening, 0, 45, travel: 10),
      ]));
      expect(s.map((e) => formatClock(e.startMinute)), ['08:00', '09:15', '18:30']);
    });

    test('a long visit pushes later stops back', () {
      final s = scheduleDay(day([
        item('full', DaySlot.morning, 0, 420),
        item('late', DaySlot.afternoon, 0, 60, travel: 20),
      ]));
      // 08:00 + 7h = 15:00, + 20 min travel.
      expect(formatClock(s[1].startMinute), '15:20');
    });
  });

  group('trip status', () {
    final today = DateTime.utc(2026, 11, 2);

    test('labels relative to today', () {
      expect(tripStatusLabel(trip(days: 3), today), 'Starts today');
      expect(tripStatusLabel(trip(days: 3), today.subtract(const Duration(days: 3))), 'In 3 days');
      expect(tripStatusLabel(trip(days: 3), today.add(const Duration(days: 1))), 'Day 2 of 3');
      expect(tripStatusLabel(trip(days: 3), today.add(const Duration(days: 5))), 'Ended');
    });
  });

  group('search', () {
    test('matches without Vietnamese accents', () {
      final p = place('x', name: 'Han Market', local: 'Chợ Hàn');
      expect(placeMatches(p, 'cho han'), isTrue);
      expect(placeMatches(p, 'market'), isTrue);
      expect(placeMatches(p, 'beach'), isFalse);
    });
  });
}
