import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/dates.dart';
import '../../models/destination.dart';
import '../../models/enums.dart';
import '../../models/itinerary.dart';
import '../../models/place.dart';
import '../../services/itinerary/day_schedule.dart';
import '../../services/itinerary/travel_estimator.dart';
import '../../shared/widgets/artwork.dart';
import '../../shared/widgets/place_widgets.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/ui.dart';
import '../places/place_picker_sheet.dart';
import '../trips/trips_screen.dart';
import 'trip_actions.dart';

class ItineraryScreen extends ConsumerStatefulWidget {
  const ItineraryScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends ConsumerState<ItineraryScreen> {
  int _dayIndex = 0;

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(tripPlanProvider(widget.tripId));
    final places = ref.watch(allPlacesProvider);
    final destinations = ref.watch(destinationsProvider);

    Widget shell(Widget body) => Scaffold(appBar: AppBar(), body: body);

    if (plan.hasError || places.hasError || destinations.hasError) {
      return shell(ErrorView(
        error: plan.error ?? places.error ?? destinations.error!,
        onRetry: () {
          ref.invalidate(tripPlanProvider(widget.tripId));
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
        action: FilledButton(onPressed: () => context.go(Routes.trips), child: const Text('My trips')),
      ));
    }
    if (p.days.isEmpty) {
      return shell(const MessageView(icon: Icons.event_busy, title: 'This trip has no days'));
    }

    final dayIndex = _dayIndex.clamp(0, p.days.length - 1);
    final day = p.days[dayIndex];
    final placesById = {for (final place in catalog) place.id: place};
    final destById = {for (final d in dests) d.id: d};
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            stretch: true,
            leading: const ArtworkBackButton(),
            actions: [
              _HeaderAction(
                icon: Icons.map_outlined,
                tooltip: 'Map & directions',
                onTap: () => context.push(Routes.tripMap(widget.tripId)),
              ),
              PopupMenuButton<String>(
                tooltip: 'More',
                icon: const _HeaderIcon(Icons.more_horiz),
                onSelected: (value) async {
                  if (value == 'delete') {
                    final deleted = await confirmDeleteTrip(context, ref, p.trip);
                    if (deleted && context.mounted) context.go(Routes.trips);
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
              const SizedBox(width: Space.xs),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: SceneArtwork(key: ValueKey(day.destinationId), destinationId: day.destinationId),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x66000000), Colors.transparent, Color(0xB3000000)],
                        stops: [0, 0.35, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: Space.page,
                    right: Space.page,
                    bottom: Space.lg + 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.trip.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white)),
                        const SizedBox(height: Space.sm),
                        Wrap(
                          spacing: Space.sm,
                          runSpacing: Space.xs,
                          children: [
                            InfoBadge(
                              onDark: true,
                              icon: Icons.calendar_today_outlined,
                              label: '${formatShortDate(p.trip.startDate)} – ${formatShortDate(p.trip.endDate)}',
                            ),
                            InfoBadge(onDark: true, icon: Icons.people_outline, label: '${p.trip.travelers}'),
                            InfoBadge(onDark: true, icon: transportIcon(p.trip.transport), label: p.trip.transport.label),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _DayTabsDelegate(
              days: p.days,
              selected: dayIndex,
              destinations: destById,
              background: theme.colorScheme.surface,
              onSelect: (i) {
                HapticFeedback.selectionClick();
                setState(() => _dayIndex = i);
              },
            ),
          ),
          SliverToBoxAdapter(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _DayContent(
                key: ValueKey(day.id),
                plan: p,
                day: day,
                placesById: placesById,
                destination: destById[day.destinationId],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(color: Colors.black26, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 20),
      );
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) =>
      IconButton(tooltip: tooltip, onPressed: onTap, icon: _HeaderIcon(icon));
}

class _DayTabsDelegate extends SliverPersistentHeaderDelegate {
  _DayTabsDelegate({
    required this.days,
    required this.selected,
    required this.destinations,
    required this.background,
    required this.onSelect,
  });

  final List<ItineraryDay> days;
  final int selected;
  final Map<String, Destination> destinations;
  final Color background;
  final ValueChanged<int> onSelect;

  @override
  double get minExtent => 84;
  @override
  double get maxExtent => 84;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      color: background,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(Space.page, Space.md, Space.page, Space.md),
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
        itemBuilder: (context, i) {
          final d = days[i];
          final active = i == selected;
          return Semantics(
            button: true,
            selected: active,
            label: 'Day ${i + 1}, ${formatShortDate(d.date)}',
            excludeSemantics: true,
            child: Pressable(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 76,
                decoration: BoxDecoration(
                  color: active ? scheme.primary : scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(color: active ? scheme.primary : scheme.outlineVariant),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('DAY ${i + 1}',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: active ? scheme.onPrimary.withValues(alpha: 0.8) : scheme.onSurfaceVariant)),
                    Text(formatShortDate(d.date).split(' ').take(2).join(' '),
                        style: theme.textTheme.titleSmall?.copyWith(color: active ? scheme.onPrimary : scheme.onSurface)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  bool shouldRebuild(_DayTabsDelegate old) =>
      old.selected != selected || old.days != days || old.background != background;
}

enum _ItemAction { details, up, down, morning, afternoon, evening, replace, remove }

class _DayContent extends ConsumerWidget {
  const _DayContent({
    super.key,
    required this.plan,
    required this.day,
    required this.placesById,
    required this.destination,
  });

  final TripPlan plan;
  final ItineraryDay day;
  final Map<String, Place> placesById;
  final Destination? destination;

  Future<void> _act(BuildContext context, WidgetRef ref, Future<void> Function(TripActions a) fn) async {
    try {
      await fn(ref.read(tripActionsProvider));
    } catch (e) {
      if (context.mounted) showSnack(context, 'Could not update the itinerary: $e');
    }
  }

  Future<void> _pickPlace(BuildContext context, WidgetRef ref,
      {required DaySlot slot, ItineraryItem? replacing}) async {
    final candidates = placesById.values.where((p) => p.destinationId == day.destinationId).toList();
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
        content: const Text('This day will be re-planned with different places where possible. '
            'Other days stay exactly as they are.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await _act(context, ref, (a) => a.regenerateDay(plan, day.id));
    }
  }

  Future<void> _onItem(BuildContext context, WidgetRef ref, ItineraryItem item, bool first, bool last) async {
    final place = placesById[item.placeId];
    final action = await showModalBottomSheet<_ItemAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.sm),
              child: Text(place?.nameEn ?? 'Stop', style: Theme.of(context).textTheme.titleLarge),
            ),
            if (place != null)
              _sheetTile(context, Icons.info_outline, 'View details', _ItemAction.details),
            if (!first) _sheetTile(context, Icons.arrow_upward, 'Move earlier', _ItemAction.up),
            if (!last) _sheetTile(context, Icons.arrow_downward, 'Move later', _ItemAction.down),
            for (final slot in DaySlot.values)
              if (slot != item.slot)
                _sheetTile(context, slotIcon(slot), 'Move to ${slot.label.toLowerCase()}',
                    _ItemAction.values.byName(slot.name)),
            _sheetTile(context, Icons.swap_horiz, 'Replace with another place', _ItemAction.replace),
            _sheetTile(context, Icons.delete_outline, 'Remove from day', _ItemAction.remove, destructive: true),
            const SizedBox(height: Space.sm),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _ItemAction.details:
        context.push(Routes.place(item.placeId));
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
        final messenger = ScaffoldMessenger.of(context);
        final actions = ref.read(tripActionsProvider);
        await _act(context, ref, (a) => a.removeItem(plan, day, item.id));
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text('Removed ${place?.nameEn ?? 'stop'}'),
            action: SnackBarAction(label: 'Undo', onPressed: () => actions.restore(plan)),
          ));
    }
  }

  Widget _sheetTile(BuildContext context, IconData icon, String label, _ItemAction value,
      {bool destructive = false}) {
    final color = destructive ? Theme.of(context).colorScheme.error : null;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.page),
      leading: Icon(icon, color: color),
      title: Text(label, style: color == null ? null : TextStyle(color: color)),
      onTap: () => Navigator.pop(context, value),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ordered = day.orderedItems;
    final schedule = {for (final s in scheduleDay(day)) s.item.id: s};
    final visit = ordered.fold<int>(0, (s, i) => s + i.durationMinutes);
    final travel = ordered.fold<int>(0, (s, i) => s + (i.travelMinutesFromPrevious ?? 0));
    final window = DaySlot.values.fold<int>(0, (s, slot) => s + slot.lengthMinutes);
    final free = window - visit - travel;
    final mode = plan.trip.transport;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.page, Space.xs, Space.page, Space.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${formatShortDate(day.date)} · ${destination?.name ?? day.destinationId}',
              style: theme.textTheme.titleLarge),
          const SizedBox(height: Space.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    StatTile(icon: Icons.place_outlined, value: '${ordered.length}', label: 'Stops'),
                    StatTile(icon: Icons.schedule, value: formatMinutes(visit), label: 'Visiting'),
                    StatTile(icon: transportIcon(mode), value: '~${formatMinutes(travel)}', label: 'Travel (est.)'),
                  ]),
                  const SizedBox(height: Space.lg),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.pill),
                    child: LinearProgressIndicator(
                      value: ((visit + travel) / window).clamp(0, 1).toDouble(),
                      minHeight: 8,
                      backgroundColor: scheme.surfaceContainer,
                      color: free >= 0 ? scheme.primary : scheme.error,
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                  Text(
                    ordered.isEmpty
                        ? 'A free day. Add stops below or regenerate.'
                        : free >= 0
                            ? '~${formatMinutes(free)} free time kept as buffer'
                            : 'This day looks too full. Consider removing a stop.',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: free >= 0 ? scheme.onSurfaceVariant : scheme.error),
                  ),
                  const SizedBox(height: Space.md),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _regenerate(context, ref),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Regenerate'),
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push(Routes.offers(day.destinationId)),
                          icon: const Icon(Icons.local_activity_outlined, size: 18),
                          label: const Text('Tours'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          for (final slot in DaySlot.values) ...[
            const SizedBox(height: Space.xl),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: scheme.secondary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                  child: Icon(slotIcon(slot), size: 18, color: scheme.secondary),
                ),
                const SizedBox(width: Space.sm + 2),
                Text(slot.label, style: theme.textTheme.titleMedium),
                const SizedBox(width: Space.sm),
                Text(slot.window, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _pickPlace(context, ref, slot: slot),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            if (day.itemsIn(slot).isEmpty)
              _FreeSlot(onTap: () => _pickPlace(context, ref, slot: slot)),
            for (final item in day.itemsIn(slot)) ...[
              if (item.travelMinutesFromPrevious != null) _TravelConnector(item: item, mode: mode),
              _TimelineStop(
                item: item,
                place: placesById[item.placeId],
                start: schedule[item.id]?.startMinute,
                onTap: () => _onItem(context, ref, item, item.id == ordered.first.id, item.id == ordered.last.id),
              ),
            ],
          ],
          const SizedBox(height: Space.xl),
          Container(
            padding: const EdgeInsets.all(Space.lg),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Text(
              'Start times are suggestions. Opening hours, prices and travel times are not '
              'verified; check locally before you go. ${TravelEstimator.explanation}',
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

const _timeColumn = 52.0;

class _TimelineStop extends StatelessWidget {
  const _TimelineStop({required this.item, required this.place, required this.start, required this.onTap});

  final ItineraryItem item;
  final Place? place;
  final int? start;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = place;
    final longVisit = item.durationMinutes > item.slot.lengthMinutes;
    return Semantics(
      button: true,
      label: '${p?.nameEn ?? 'Stop'}, edit options',
      child: Pressable(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _timeColumn,
              child: Padding(
                padding: const EdgeInsets.only(top: Space.lg),
                child: Text(start == null ? '' : formatClock(start!),
                    style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: Space.xs),
                padding: const EdgeInsets.all(Space.md),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(Radii.md + 2),
                  border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
                  boxShadow: [
                    BoxShadow(color: Palette.ink.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.sm + 2),
                      child: SizedBox.square(
                        dimension: 56,
                        child: p == null
                            ? ColoredBox(color: scheme.surfaceContainer, child: const Icon(Icons.help_outline))
                            : CategoryCover(category: p.category, seed: p.id, iconSize: 18),
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p?.nameEn ?? 'Unknown place', style: theme.textTheme.titleSmall?.copyWith(fontSize: 15)),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (p != null) p.area,
                              formatMinutes(item.durationMinutes),
                              if (longVisit) 'long visit',
                            ].join(' · '),
                            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.more_vert, color: scheme.onSurfaceVariant, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TravelConnector extends StatelessWidget {
  const _TravelConnector({required this.item, required this.mode});

  final ItineraryItem item;
  final TransportMode mode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final km = item.travelDistanceKm;
    return Padding(
      padding: const EdgeInsets.only(left: _timeColumn + Space.xl, top: 2, bottom: 6),
      child: Row(
        children: [
          Container(width: 2, height: 22, color: scheme.outlineVariant),
          const SizedBox(width: Space.md),
          Icon(transportIcon(mode), size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Text(
            '~${formatMinutes(item.travelMinutesFromPrevious!)}'
            '${km == null ? '' : ' · ${km.toStringAsFixed(1)} km'} · estimate',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _FreeSlot extends StatelessWidget {
  const _FreeSlot({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: _timeColumn),
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: Space.lg, horizontal: Space.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: scheme.outlineVariant),
            color: scheme.surfaceContainer.withValues(alpha: 0.4),
          ),
          child: Row(
            children: [
              Icon(Icons.wb_sunny_outlined, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text('Free time — relax or add a stop',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ),
              Icon(Icons.add_circle_outline, size: 20, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
