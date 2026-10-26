import 'package:flutter_test/flutter_test.dart';
import 'package:vietnam_tripmate/models/enums.dart';
import 'package:vietnam_tripmate/models/itinerary.dart';
import 'package:vietnam_tripmate/services/itinerary/itinerary_editor.dart';

import 'helpers.dart';

ItineraryItem item(String id, DaySlot slot, int position) => ItineraryItem(
      id: id,
      dayId: 'day',
      placeId: 'place_$id',
      slot: slot,
      position: position,
      durationMinutes: 60,
    );

ItineraryDay day(List<ItineraryItem> items) => ItineraryDay(
      id: 'day',
      tripId: 'trip1',
      dayIndex: 0,
      date: DateTime.utc(2026, 11, 2),
      destinationId: 'd1',
      items: items,
    );

List<String> order(ItineraryDay d) =>
    d.orderedItems.map((i) => '${i.id}:${i.slot.name}:${i.position}').toList();

void main() {
  final base = day([
    item('a', DaySlot.morning, 0),
    item('b', DaySlot.morning, 1),
    item('c', DaySlot.afternoon, 0),
  ]);

  test('addPlace appends to the end of the slot', () {
    final d = ItineraryEditor.addPlace(base, place('new', minutes: 90), DaySlot.morning,
        itemId: 'n');
    expect(order(d), ['a:morning:0', 'b:morning:1', 'n:morning:2', 'c:afternoon:0']);
    expect(d.items.firstWhere((i) => i.id == 'n').durationMinutes, 90);
  });

  test('removeItem renumbers the slot', () {
    expect(order(ItineraryEditor.removeItem(base, 'a')), ['b:morning:0', 'c:afternoon:0']);
  });

  test('moveItem swaps within a slot', () {
    expect(order(ItineraryEditor.moveItem(base, 'b', -1)),
        ['b:morning:0', 'a:morning:1', 'c:afternoon:0']);
  });

  test('moveItem crosses into the neighbouring slot at the edge', () {
    expect(order(ItineraryEditor.moveItem(base, 'c', -1)),
        ['a:morning:0', 'b:morning:1', 'c:morning:2']);
    expect(order(ItineraryEditor.moveItem(base, 'b', 1)),
        ['a:morning:0', 'b:afternoon:0', 'c:afternoon:1']);
  });

  test('moveItem ignores moves past the ends', () {
    expect(order(ItineraryEditor.moveItem(base, 'a', -1)), order(base));
    expect(order(ItineraryEditor.moveItem(base, 'c', 1)), order(base));
  });

  test('moveToSlot puts the item last in the target slot', () {
    expect(order(ItineraryEditor.moveToSlot(base, 'a', DaySlot.evening)),
        ['b:morning:0', 'c:afternoon:0', 'a:evening:0']);
  });

  test('replacePlace keeps the position and updates the duration', () {
    final d = ItineraryEditor.replacePlace(base, 'b', place('swap', minutes: 30));
    final replaced = d.items.firstWhere((i) => i.id == 'b');
    expect(replaced.placeId, 'swap');
    expect(replaced.durationMinutes, 30);
    expect(order(d), order(base));
  });
}
