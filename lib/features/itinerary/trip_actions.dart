import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/utils/ids.dart';
import '../../models/enums.dart';
import '../../models/itinerary.dart';
import '../../models/place.dart';
import '../../models/trip.dart';
import '../../services/itinerary/itinerary_editor.dart';

/// Business logic behind the trip screens: create, edit and delete trips.
/// Every change is saved immediately so nothing is lost offline.
class TripActions {
  TripActions(this._ref);

  final Ref _ref;

  Future<String> createTrip(TripDraft draft) async {
    final destinations = await _ref.read(destinationsProvider.future);
    final names = {for (final d in destinations) d.id: d.name};
    final now = DateTime.now().toUtc();
    final trip = draft.toTrip(
      id: newId('trip'),
      now: now,
      fallbackTitle: 'Trip to ${draft.destinationIds.map((id) => names[id] ?? id).join(' & ')}',
    );
    final catalog = await _ref.read(allPlacesProvider.future);
    final days = _ref.read(plannerProvider).generate(trip, catalog);
    await _ref.read(tripRepositoryProvider).savePlan(TripPlan(trip: trip, days: days));
    _ref.invalidate(tripsProvider);
    return trip.id;
  }

  Future<void> deleteTrip(String tripId) async {
    await _ref.read(tripRepositoryProvider).deleteTrip(tripId);
    _ref.invalidate(tripsProvider);
    _ref.invalidate(tripPlanProvider(tripId));
  }

  Future<void> deleteAllTrips() async {
    await _ref.read(tripRepositoryProvider).deleteAllTrips();
    _ref.invalidate(tripsProvider);
    _ref.invalidate(tripPlanProvider);
  }

  Future<void> regenerateDay(TripPlan plan, String dayId) async {
    final catalog = await _ref.read(allPlacesProvider.future);
    final day = _ref.read(plannerProvider).regenerateDay(plan, dayId, catalog);
    await _save(plan.replaceDay(day));
  }

  Future<void> addPlace(TripPlan plan, ItineraryDay day, Place place, DaySlot slot) =>
      _editDay(plan, ItineraryEditor.addPlace(day, place, slot, itemId: newId('item')));

  Future<void> removeItem(TripPlan plan, ItineraryDay day, String itemId) =>
      _editDay(plan, ItineraryEditor.removeItem(day, itemId));

  Future<void> moveItem(TripPlan plan, ItineraryDay day, String itemId, int delta) =>
      _editDay(plan, ItineraryEditor.moveItem(day, itemId, delta));

  Future<void> moveToSlot(TripPlan plan, ItineraryDay day, String itemId, DaySlot slot) =>
      _editDay(plan, ItineraryEditor.moveToSlot(day, itemId, slot));

  Future<void> replacePlace(TripPlan plan, ItineraryDay day, String itemId, Place place) =>
      _editDay(plan, ItineraryEditor.replacePlace(day, itemId, place));

  Future<void> _editDay(TripPlan plan, ItineraryDay edited) async {
    final catalog = await _ref.read(allPlacesProvider.future);
    final day = _ref
        .read(plannerProvider)
        .withTravelEstimates(edited, catalog, plan.trip.transport);
    await _save(plan.replaceDay(day));
  }

  Future<void> _save(TripPlan plan) async {
    final updated = TripPlan(
      trip: plan.trip.copyWith(updatedAt: DateTime.now().toUtc()),
      days: plan.days,
    );
    await _ref.read(tripRepositoryProvider).savePlan(updated);
    _ref.invalidate(tripPlanProvider(plan.trip.id));
    _ref.invalidate(tripsProvider);
  }
}

final tripActionsProvider = Provider(TripActions.new);
