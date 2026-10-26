import 'dart:math' as math;

import '../../core/utils/geo.dart';
import '../../models/enums.dart';
import '../../models/itinerary.dart';
import '../../models/place.dart';
import '../../models/trip.dart';
import 'travel_estimator.dart';

/// Pace-dependent limits. The unused share of each slot is buffer time.
class PaceRules {
  const PaceRules({
    required this.slotFill,
    required this.maxItemsPerSlot,
    required this.minItemsPerDay,
  });

  /// Share of each slot that may be planned (the rest is buffer).
  final double slotFill;
  final int maxItemsPerSlot;

  /// Below this, places that don't match the interests are used as filler.
  final int minItemsPerDay;

  static PaceRules of(Pace pace) => switch (pace) {
        Pace.relaxed =>
          const PaceRules(slotFill: 0.6, maxItemsPerSlot: 1, minItemsPerDay: 2),
        Pace.balanced =>
          const PaceRules(slotFill: 0.8, maxItemsPerSlot: 2, minItemsPerDay: 3),
        Pace.packed =>
          const PaceRules(slotFill: 0.95, maxItemsPerSlot: 3, minItemsPerDay: 4),
      };

  int plannableMinutes(DaySlot slot) => (slot.lengthMinutes * slotFill).floor();
}

/// Builds day-by-day itineraries from the local place catalog.
///
/// Strategy per day: pick the best-matching unused place as an anchor, then
/// fill the day with places in the same area or closest to the anchor,
/// respecting each place's suitable slots and the pace limits.
class ItineraryPlanner {
  ItineraryPlanner({
    required this.newId,
    this.travel = const TravelEstimator(),
  });

  /// Places farther than this from the day's anchor are skipped, unless in
  /// the same area.
  static const maxClusterKm = 12.0;

  /// Allowance between two stops in the same slot while filling. Real
  /// estimates are computed afterwards by [withTravelEstimates].
  static const transferAllowanceMinutes = 15;

  final String Function(String prefix) newId;
  final TravelEstimator travel;

  List<ItineraryDay> generate(Trip trip, List<Place> catalog) {
    final allocation = allocateDays(trip.dayCount, trip.destinationIds);
    final used = <String>{};
    final days = <ItineraryDay>[];
    for (var i = 0; i < allocation.length; i++) {
      final dayId = newId('day');
      final pool = catalog
          .where((p) => p.destinationId == allocation[i] && !used.contains(p.id))
          .toList();
      final items = _fillDay(trip, dayId, pool, demoted: const {});
      used.addAll(items.map((e) => e.placeId));
      final day = ItineraryDay(
        id: dayId,
        tripId: trip.id,
        dayIndex: i,
        date: trip.startDate.add(Duration(days: i)),
        destinationId: allocation[i],
        items: items,
      );
      days.add(withTravelEstimates(day, catalog, trip.transport));
    }
    return days;
  }

  /// Rebuilds one day without touching the others. Places used on other
  /// days are excluded; the day's previous places are tried last for variety.
  ItineraryDay regenerateDay(TripPlan plan, String dayId, List<Place> catalog) {
    final day = plan.days.firstWhere((d) => d.id == dayId);
    final usedElsewhere = {
      for (final d in plan.days)
        if (d.id != dayId) for (final item in d.items) item.placeId,
    };
    final previous = day.items.map((e) => e.placeId).toSet();
    final pool = catalog
        .where((p) => p.destinationId == day.destinationId && !usedElsewhere.contains(p.id))
        .toList();
    final items = _fillDay(plan.trip, day.id, pool, demoted: previous);
    return withTravelEstimates(day.withItems(items), catalog, plan.trip.transport);
  }

  /// Splits [dayCount] days into consecutive blocks per destination. Earlier
  /// destinations get the extra days.
  static List<String> allocateDays(int dayCount, List<String> destinationIds) {
    if (dayCount <= 0 || destinationIds.isEmpty) return const [];
    final k = math.min(dayCount, destinationIds.length);
    final base = dayCount ~/ k;
    final extra = dayCount % k;
    return [
      for (var d = 0; d < k; d++)
        for (var j = 0; j < base + (d < extra ? 1 : 0); j++) destinationIds[d],
    ];
  }

  /// Number of the trip's interests a place matches. With no interests
  /// selected every place scores 1.
  static int score(Place place, Set<Interest> interests) {
    if (interests.isEmpty) return 1;
    return place.interests.where(interests.contains).length;
  }

  List<ItineraryItem> _fillDay(
    Trip trip,
    String dayId,
    List<Place> pool, {
    required Set<String> demoted,
  }) {
    if (pool.isEmpty) return const [];
    final rules = PaceRules.of(trip.pace);

    int rank(Place p) => score(p, trip.interests) - (demoted.contains(p.id) ? 100 : 0);
    // Ties go to places with more neighbours, so the day starts in a cluster.
    final neighbours = {
      for (final p in pool)
        p.id: pool
            .where((q) =>
                q.id != p.id &&
                haversineKm(p.latitude, p.longitude, q.latitude, q.longitude) <=
                    maxClusterKm)
            .length,
    };
    final ranked = [...pool]
      ..sort((a, b) {
        final byRank = rank(b).compareTo(rank(a));
        if (byRank != 0) return byRank;
        final byNeighbours = neighbours[b.id]!.compareTo(neighbours[a.id]!);
        return byNeighbours != 0 ? byNeighbours : a.id.compareTo(b.id);
      });

    final anchor = ranked.first;
    double distance(Place p) =>
        haversineKm(anchor.latitude, anchor.longitude, p.latitude, p.longitude);

    final candidates = ranked
        .where((p) => p.area == anchor.area || distance(p) <= maxClusterKm)
        .toList()
      ..sort((a, b) {
        int tier(Place p) => (score(p, trip.interests) > 0 ? 0 : 2) +
            (demoted.contains(p.id) ? 1 : 0);
        final byTier = tier(a).compareTo(tier(b));
        if (byTier != 0) return byTier;
        final byArea = (a.area == anchor.area ? 0 : 1)
            .compareTo(b.area == anchor.area ? 0 : 1);
        if (byArea != 0) return byArea;
        final byDistance = distance(a).compareTo(distance(b));
        return byDistance != 0 ? byDistance : a.id.compareTo(b.id);
      });
    // The anchor always goes first.
    candidates
      ..remove(anchor)
      ..insert(0, anchor);

    final state = _DayState(rules);
    for (final place in candidates) {
      final matches = score(place, trip.interests) > 0;
      if (!matches && state.placements.length >= rules.minItemsPerDay) continue;
      for (final slot in DaySlot.values) {
        if (state.tryPlace(place, slot)) break;
      }
    }

    final counters = <DaySlot, int>{};
    return [
      for (final (place, slot) in state.placements)
        ItineraryItem(
          id: newId('item'),
          dayId: dayId,
          placeId: place.id,
          slot: slot,
          position: counters.update(slot, (v) => v + 1, ifAbsent: () => 0),
          durationMinutes: place.suggestedDurationMinutes,
        ),
    ];
  }

  /// Recomputes travel estimates between consecutive stops of a day.
  ItineraryDay withTravelEstimates(
      ItineraryDay day, List<Place> catalog, TransportMode mode) {
    final byId = {for (final p in catalog) p.id: p};
    Place? previous;
    final items = <ItineraryItem>[];
    for (final item in day.orderedItems) {
      final place = byId[item.placeId];
      if (previous == null || place == null) {
        items.add(item.copyWith(
            travelMinutesFromPrevious: () => null, travelDistanceKm: () => null));
      } else {
        final est = travel.estimate(previous, place, mode);
        items.add(item.copyWith(
            travelMinutesFromPrevious: () => est.minutes,
            travelDistanceKm: () => est.distanceKm));
      }
      previous = place ?? previous;
    }
    return day.withItems(items);
  }
}

class _DayState {
  _DayState(this.rules);

  final PaceRules rules;
  final placements = <(Place, DaySlot)>[];
  final _used = {for (final s in DaySlot.values) s: 0};
  final _count = {for (final s in DaySlot.values) s: 0};

  bool tryPlace(Place place, DaySlot slot) {
    if (!place.suits(slot) || _count[slot]! >= rules.maxItemsPerSlot) return false;

    final need = place.suggestedDurationMinutes +
        (_count[slot]! > 0 ? ItineraryPlanner.transferAllowanceMinutes : 0);
    if (_used[slot]! + need <= rules.plannableMinutes(slot)) {
      _used[slot] = _used[slot]! + need;
      _count[slot] = _count[slot]! + 1;
      placements.add((place, slot));
      return true;
    }

    // A long visit (e.g. a full-day trip) may start in an empty slot and run
    // into the following empty slots, which are then closed.
    if (_count[slot]! > 0) return false;
    var remaining = place.suggestedDurationMinutes;
    final spanned = <DaySlot>[];
    for (final s in DaySlot.values.skip(slot.index)) {
      if (remaining <= 0) break;
      if (_count[s]! > 0) return false;
      spanned.add(s);
      remaining -= s.lengthMinutes;
    }
    if (remaining > 0) return false;
    for (final s in spanned) {
      _used[s] = rules.plannableMinutes(s);
      _count[s] = rules.maxItemsPerSlot;
    }
    placements.add((place, slot));
    return true;
  }
}
