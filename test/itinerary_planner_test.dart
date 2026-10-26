import 'package:flutter_test/flutter_test.dart';
import 'package:vietnam_tripmate/models/enums.dart';
import 'package:vietnam_tripmate/models/itinerary.dart';
import 'package:vietnam_tripmate/services/itinerary/itinerary_planner.dart';

import 'helpers.dart';

void main() {
  late ItineraryPlanner planner;

  setUp(() => planner = ItineraryPlanner(newId: sequentialIds()));

  group('allocateDays', () {
    test('splits days into consecutive blocks, extra days first', () {
      expect(ItineraryPlanner.allocateDays(5, ['a', 'b']), ['a', 'a', 'a', 'b', 'b']);
    });

    test('uses only as many destinations as there are days', () {
      expect(ItineraryPlanner.allocateDays(1, ['a', 'b']), ['a']);
    });

    test('returns nothing for invalid input', () {
      expect(ItineraryPlanner.allocateDays(0, ['a']), isEmpty);
      expect(ItineraryPlanner.allocateDays(3, []), isEmpty);
    });
  });

  group('generate', () {
    test('creates one day per trip date with consecutive dates', () {
      final t = trip(days: 3);
      final days = planner.generate(t, [for (var i = 0; i < 9; i++) place('p$i')]);
      expect(days, hasLength(3));
      expect(days.map((d) => d.dayIndex), [0, 1, 2]);
      expect(days[2].date, t.startDate.add(const Duration(days: 2)));
    });

    test('never repeats a place across days', () {
      final days =
          planner.generate(trip(days: 3), [for (var i = 0; i < 12; i++) place('p$i')]);
      final ids = [for (final d in days) for (final i in d.items) i.placeId];
      expect(ids.toSet().length, ids.length);
    });

    test('only uses places of the day\'s destination', () {
      final catalog = [
        for (var i = 0; i < 4; i++) place('a$i', destination: 'd1'),
        for (var i = 0; i < 4; i++) place('b$i', destination: 'd2'),
      ];
      final days = planner.generate(trip(days: 2, destinations: ['d1', 'd2']), catalog);
      expect(days[0].items.every((i) => i.placeId.startsWith('a')), isTrue);
      expect(days[1].items.every((i) => i.placeId.startsWith('b')), isTrue);
    });

    test('prefers places matching the interests', () {
      final catalog = [
        place('beach', interests: {Interest.beaches}),
        place('museum', interests: {Interest.culture}),
        place('market', interests: {Interest.shopping}),
      ];
      final days = planner.generate(
          trip(days: 1, interests: {Interest.beaches}, pace: Pace.relaxed), catalog);
      expect(days.single.orderedItems.first.placeId, 'beach');
    });

    test('respects best slots', () {
      final catalog = [
        place('night', slots: {DaySlot.evening}),
        place('day', slots: {DaySlot.morning}),
      ];
      final day = planner.generate(trip(days: 1), catalog).single;
      final bySlot = {for (final i in day.items) i.placeId: i.slot};
      expect(bySlot['night'], DaySlot.evening);
      expect(bySlot['day'], DaySlot.morning);
    });

    test('respects the per-slot limit of the pace', () {
      final catalog = [for (var i = 0; i < 10; i++) place('p$i', minutes: 30)];
      final day = planner.generate(trip(days: 1, pace: Pace.relaxed), catalog).single;
      for (final slot in DaySlot.values) {
        expect(day.itemsIn(slot).length, lessThanOrEqualTo(1));
      }
    });

    test('keeps buffer time: planned minutes stay within the pace share', () {
      final catalog = [for (var i = 0; i < 20; i++) place('p$i', minutes: 50)];
      final rules = PaceRules.of(Pace.balanced);
      final day = planner.generate(trip(days: 1), catalog).single;
      for (final slot in DaySlot.values) {
        final items = day.itemsIn(slot);
        final planned = items.fold<int>(0, (s, i) => s + i.durationMinutes) +
            (items.length > 1
                ? (items.length - 1) * ItineraryPlanner.transferAllowanceMinutes
                : 0);
        expect(planned, lessThanOrEqualTo(rules.plannableMinutes(slot)));
      }
    });

    test('a full-day visit blocks the following slot', () {
      final catalog = [
        place('fullday', minutes: 420, slots: {DaySlot.morning}),
        place('other1'),
        place('other2'),
      ];
      final day = planner.generate(trip(days: 1), catalog).single;
      expect(day.itemsIn(DaySlot.morning).single.placeId, 'fullday');
      expect(day.itemsIn(DaySlot.afternoon), isEmpty);
    });

    test('clusters by area and skips far-away places', () {
      final catalog = [
        place('near1', area: 'Town', lat: 15.877, lng: 108.326),
        place('near2', area: 'Town', lat: 15.878, lng: 108.330),
        place('far', area: 'Remote', lat: 15.764, lng: 108.124), // ~25 km away
      ];
      final day = planner.generate(trip(days: 1), catalog).single;
      expect(day.items.map((i) => i.placeId), isNot(contains('far')));
    });

    test('adds estimated travel time between consecutive stops only', () {
      final catalog = [
        place('a', lat: 16.060, lng: 108.220),
        place('b', lat: 16.070, lng: 108.225),
        place('c', lat: 16.065, lng: 108.230),
      ];
      final day = planner.generate(trip(days: 1, pace: Pace.packed), catalog).single;
      final ordered = day.orderedItems;
      expect(ordered.first.travelMinutesFromPrevious, isNull);
      for (final item in ordered.skip(1)) {
        expect(item.travelMinutesFromPrevious, greaterThanOrEqualTo(5));
        expect(item.travelDistanceKm, isNotNull);
      }
    });

    test('returns empty days instead of failing when places run out', () {
      final days = planner.generate(trip(days: 3), [place('only')]);
      expect(days, hasLength(3));
      expect(days[1].items, isEmpty);
      expect(days[2].items, isEmpty);
    });
  });

  group('regenerateDay', () {
    test('changes only the chosen day and avoids places used elsewhere', () {
      final catalog = [for (var i = 0; i < 12; i++) place('p$i', minutes: 45)];
      final t = trip(days: 2);
      final plan = TripPlan(trip: t, days: planner.generate(t, catalog));
      final target = plan.days[1];

      final regenerated = planner.regenerateDay(plan, target.id, catalog);

      expect(regenerated.id, target.id);
      expect(regenerated.dayIndex, 1);
      final dayOneIds = plan.days[0].items.map((i) => i.placeId).toSet();
      expect(regenerated.items.map((i) => i.placeId).toSet().intersection(dayOneIds), isEmpty);
      // Day 0 untouched.
      expect(plan.replaceDay(regenerated).days[0], same(plan.days[0]));
    });

    test('prefers places that were not on the day before', () {
      final catalog = [for (var i = 0; i < 8; i++) place('p$i', minutes: 45)];
      final t = trip(days: 1, pace: Pace.relaxed);
      final plan = TripPlan(trip: t, days: planner.generate(t, catalog));
      final before = plan.days.single.items.map((i) => i.placeId).toSet();

      final after = planner
          .regenerateDay(plan, plan.days.single.id, catalog)
          .items
          .map((i) => i.placeId)
          .toSet();

      expect(after.intersection(before), isEmpty);
    });
  });
}
