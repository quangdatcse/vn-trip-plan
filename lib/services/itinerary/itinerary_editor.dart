import '../../models/enums.dart';
import '../../models/itinerary.dart';
import '../../models/place.dart';

/// Pure edit operations on a single day. Callers recompute travel
/// estimates afterwards with `ItineraryPlanner.withTravelEstimates`.
class ItineraryEditor {
  const ItineraryEditor._();

  static ItineraryDay addPlace(
    ItineraryDay day,
    Place place,
    DaySlot slot, {
    required String itemId,
  }) {
    final item = ItineraryItem(
      id: itemId,
      dayId: day.id,
      placeId: place.id,
      slot: slot,
      position: day.itemsIn(slot).length,
      durationMinutes: place.suggestedDurationMinutes,
    );
    return _renumber(day, [...day.orderedItems, item]);
  }

  static ItineraryDay removeItem(ItineraryDay day, String itemId) =>
      _renumber(day, day.orderedItems.where((i) => i.id != itemId).toList());

  /// Moves an item one step earlier (`delta = -1`) or later (`delta = 1`).
  /// At the edge of a slot it crosses into the neighbouring slot first.
  static ItineraryDay moveItem(ItineraryDay day, String itemId, int delta) {
    final list = day.orderedItems;
    final index = list.indexWhere((i) => i.id == itemId);
    final target = index + delta;
    if (index < 0 || target < 0 || target >= list.length) return day;

    final item = list[index];
    final neighbour = list[target];
    if (neighbour.slot != item.slot) {
      list[index] = item.copyWith(slot: neighbour.slot);
    } else {
      list[index] = neighbour;
      list[target] = item;
    }
    return _renumber(day, list);
  }

  static ItineraryDay moveToSlot(ItineraryDay day, String itemId, DaySlot slot) {
    final list = day.orderedItems;
    final index = list.indexWhere((i) => i.id == itemId);
    if (index < 0 || list[index].slot == slot) return day;
    // Appended last, so it lands at the end of the target slot.
    list.add(list.removeAt(index).copyWith(slot: slot));
    return _renumber(day, list);
  }

  static ItineraryDay replacePlace(ItineraryDay day, String itemId, Place place) =>
      day.withItems([
        for (final i in day.items)
          i.id == itemId
              ? i.copyWith(
                  placeId: place.id, durationMinutes: place.suggestedDurationMinutes)
              : i,
      ]);

  /// Re-sorts by (slot, current order) and assigns positions 0..n per slot.
  static ItineraryDay _renumber(ItineraryDay day, List<ItineraryItem> items) {
    final ordered = <ItineraryItem>[];
    for (final slot in DaySlot.values) {
      final inSlot = <ItineraryItem>[];
      for (final i in items) {
        if (i.slot == slot) inSlot.add(i);
      }
      for (var p = 0; p < inSlot.length; p++) {
        ordered.add(inSlot[p].copyWith(position: p));
      }
    }
    return day.withItems(ordered);
  }
}
