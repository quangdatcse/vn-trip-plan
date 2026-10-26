import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/routing/app_router.dart';
import '../../core/utils/dates.dart';
import '../../models/destination.dart';
import '../../models/enums.dart';
import '../../models/itinerary.dart';
import '../../models/place.dart';
import '../../services/itinerary/travel_estimator.dart';
import '../../shared/widgets/place_widgets.dart';
import '../../shared/widgets/state_views.dart';
import '../home/home_screen.dart';
import '../places/place_picker_sheet.dart';
import 'trip_actions.dart';

class ItineraryScreen extends ConsumerWidget {
  const ItineraryScreen({super.key, required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(tripPlanProvider(tripId));
    final places = ref.watch(allPlacesProvider);
    final destinations = ref.watch(destinationsProvider);

    Widget shell(Widget body) => Scaffold(appBar: AppBar(), body: body);

    if (plan.hasError || places.hasError || destinations.hasError) {
      return shell(ErrorView(
        error: plan.error ?? places.error ?? destinations.error!,
        onRetry: () {
          ref.invalidate(tripPlanProvider(tripId));
          ref.invalidate(allPlacesProvider);
          ref.invalidate(destinationsProvider);
        },
      ));
    }
    final p = plan.value;
    final catalog = places.value;
    final dests = destinations.value;
    if (catalog == null || dests == null || (p == null && plan.isLoading)) {
      return shell(const LoadingView());
    }
    if (p == null) {
      return shell(MessageView(
        icon: Icons.search_off,
        title: 'Trip not found',
        message: 'It may have been deleted.',
        action: FilledButton(onPressed: () => context.go(Routes.home), child: const Text('Home')),
      ));
    }

    final placesById = {for (final place in catalog) place.id: place};
    final destById = {for (final d in dests) d.id: d};

    return DefaultTabController(
      length: p.days.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(p.trip.title),
          actions: [
            IconButton(
              tooltip: 'Map & directions',
              icon: const Icon(Icons.map_outlined),
              onPressed: () => context.push(Routes.tripMap(tripId)),
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'delete') {
                  final deleted = await confirmDeleteTrip(context, ref, p.trip);
                  if (deleted && context.mounted) context.go(Routes.home);
                } else {
                  context.push(Routes.offers(value));
                }
              },
              itemBuilder: (context) => [
                for (final id in p.trip.destinationIds)
                  PopupMenuItem(
                    value: id,
                    child: Text('Tours & tickets in ${destById[id]?.name ?? id}'),
                  ),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'delete', child: Text('Delete trip')),
              ],
            ),
          ],
          bottom: p.days.isEmpty
              ? null
              : TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    for (final day in p.days)
                      Tab(text: 'Day ${day.dayIndex + 1} · ${formatShortDate(day.date)}'),
                  ],
                ),
        ),
        body: p.days.isEmpty
            ? const MessageView(icon: Icons.event_busy, title: 'This trip has no days')
            : TabBarView(
                children: [
                  for (final day in p.days)
                    _DayView(
                      plan: p,
                      day: day,
                      placesById: placesById,
                      destination: destById[day.destinationId],
                    ),
                ],
              ),
      ),
    );
  }
}

class _DayView extends ConsumerWidget {
  const _DayView({
    required this.plan,
    required this.day,
    required this.placesById,
    required this.destination,
  });

  final TripPlan plan;
  final ItineraryDay day;
  final Map<String, Place> placesById;
  final Destination? destination;

  Future<void> _act(
      BuildContext context, WidgetRef ref, Future<void> Function(TripActions a) fn) async {
    try {
      await fn(ref.read(tripActionsProvider));
    } catch (e) {
      if (context.mounted) showSnack(context, 'Could not update the itinerary: $e');
    }
  }

  Future<void> _pickPlace(BuildContext context, WidgetRef ref,
      {required DaySlot slot, ItineraryItem? replacing}) async {
    final candidates = placesById.values
        .where((p) => p.destinationId == day.destinationId)
        .toList();
    final place = await showPlacePicker(
      context,
      places: candidates,
      usedPlaceIds: plan.placeIds,
      slot: slot,
      reference: replacing == null ? null : placesById[replacing.placeId],
      title: replacing == null ? 'Add to ${slot.label.toLowerCase()}' : 'Replace with…',
    );
    if (place == null || !context.mounted) return;
    await _act(
      context,
      ref,
      (a) => replacing == null
          ? a.addPlace(plan, day, place, slot)
          : a.replacePlace(plan, day, replacing.id, place),
    );
  }

  Future<void> _regenerate(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Regenerate day ${day.dayIndex + 1}?'),
        content: const Text(
            'This day will be re-planned. Other days stay exactly as they are.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true), child: const Text('Regenerate')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await _act(context, ref, (a) => a.regenerateDay(plan, day.id));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ordered = day.orderedItems;
    final visitMinutes = ordered.fold<int>(0, (s, i) => s + i.durationMinutes);
    final travelMinutes =
        ordered.fold<int>(0, (s, i) => s + (i.travelMinutesFromPrevious ?? 0));
    final dayWindow = DaySlot.values.fold<int>(0, (s, slot) => s + slot.lengthMinutes);
    final free = dayWindow - visitMinutes - travelMinutes;
    final mode = plan.trip.transport;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${formatShortDate(day.date)} · ${destination?.name ?? day.destinationId}',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  ordered.isEmpty
                      ? 'Nothing planned yet.'
                      : '${ordered.length} stops · ${formatMinutes(visitMinutes)} visiting · '
                          '~${formatMinutes(travelMinutes)} travel (estimated)',
                  style: theme.textTheme.bodyMedium,
                ),
                if (ordered.isNotEmpty)
                  Text(
                    free >= 0
                        ? '~${formatMinutes(free)} free time as buffer'
                        : 'This day looks too full. Consider removing a stop.',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: free >= 0 ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.error),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _regenerate(context, ref),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Regenerate day'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.push(Routes.offers(day.destinationId)),
                      icon: const Icon(Icons.local_activity_outlined),
                      label: const Text('Tours & tickets'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        for (final slot in DaySlot.values) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(slotIcon(slot), color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(slot.label, style: theme.textTheme.titleMedium),
              const SizedBox(width: 8),
              Text(slot.window, style: theme.textTheme.bodySmall),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _pickPlace(context, ref, slot: slot),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          if (day.itemsIn(slot).isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 32, bottom: 4),
              child: Text('Free time', style: theme.textTheme.bodySmall),
            ),
          for (final item in day.itemsIn(slot)) ...[
            if (item.travelMinutesFromPrevious != null)
              _TravelRow(item: item, mode: mode),
            _ItemCard(
              item: item,
              place: placesById[item.placeId],
              isFirst: item.id == ordered.first.id,
              isLast: item.id == ordered.last.id,
              onMenu: (action) async {
                switch (action) {
                  case _ItemAction.up:
                    await _act(context, ref, (a) => a.moveItem(plan, day, item.id, -1));
                  case _ItemAction.down:
                    await _act(context, ref, (a) => a.moveItem(plan, day, item.id, 1));
                  case _ItemAction.morning:
                  case _ItemAction.afternoon:
                  case _ItemAction.evening:
                    final target = DaySlot.values.byName(action.name);
                    await _act(context, ref, (a) => a.moveToSlot(plan, day, item.id, target));
                  case _ItemAction.replace:
                    await _pickPlace(context, ref, slot: item.slot, replacing: item);
                  case _ItemAction.remove:
                    await _act(context, ref, (a) => a.removeItem(plan, day, item.id));
                }
              },
            ),
          ],
        ],
        const SizedBox(height: 24),
        Text(
          'Times and durations are suggestions. Opening hours, prices and travel '
          'times are not verified; check locally before you go. '
          '${TravelEstimator.explanation}',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _TravelRow extends StatelessWidget {
  const _TravelRow({required this.item, required this.mode});

  final ItineraryItem item;
  final TransportMode mode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final km = item.travelDistanceKm;
    return Padding(
      padding: const EdgeInsets.only(left: 20, top: 2, bottom: 2),
      child: Row(
        children: [
          Icon(transportIcon(mode), size: 16, color: theme.colorScheme.outline),
          const SizedBox(width: 8),
          Text(
            '~${formatMinutes(item.travelMinutesFromPrevious!)}'
            '${km == null ? '' : ' · ${km.toStringAsFixed(1)} km'} (estimate)',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

enum _ItemAction { up, down, morning, afternoon, evening, replace, remove }

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.place,
    required this.isFirst,
    required this.isLast,
    required this.onMenu,
  });

  final ItineraryItem item;
  final Place? place;
  final bool isFirst;
  final bool isLast;
  final ValueChanged<_ItemAction> onMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = place;
    final longVisit = item.durationMinutes > item.slot.lengthMinutes;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 12, right: 4),
        leading: p == null
            ? const Icon(Icons.help_outline)
            : CategoryAvatar(category: p.category),
        title: Text(p?.nameEn ?? 'Unknown place'),
        subtitle: Text(
          [
            if (p != null) p.area,
            '~${formatMinutes(item.durationMinutes)} suggested',
            if (longVisit) 'continues into the next part of the day',
          ].join(' · '),
          style: theme.textTheme.bodySmall,
        ),
        onTap: p == null ? null : () => context.push(Routes.place(p.id)),
        trailing: PopupMenuButton<_ItemAction>(
          tooltip: 'Edit stop',
          onSelected: onMenu,
          itemBuilder: (context) => [
            if (!isFirst)
              const PopupMenuItem(value: _ItemAction.up, child: Text('Move earlier')),
            if (!isLast)
              const PopupMenuItem(value: _ItemAction.down, child: Text('Move later')),
            for (final slot in DaySlot.values)
              if (slot != item.slot)
                PopupMenuItem(
                  value: _ItemAction.values.byName(slot.name),
                  child: Text('Move to ${slot.label.toLowerCase()}'),
                ),
            const PopupMenuItem(value: _ItemAction.replace, child: Text('Replace…')),
            const PopupMenuItem(value: _ItemAction.remove, child: Text('Remove')),
          ],
        ),
      ),
    );
  }
}
