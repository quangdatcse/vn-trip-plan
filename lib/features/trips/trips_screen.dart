import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/dates.dart';
import '../../models/trip.dart';
import '../../shared/widgets/artwork.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/ui.dart';
import '../itinerary/trip_actions.dart';

class TripsScreen extends ConsumerWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(tripsProvider);
    final destinations = ref.watch(destinationsProvider).value ?? const [];
    final names = {for (final d in destinations) d.id: d.name};
    final today = dateOnly(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('My trips'), toolbarHeight: 64),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.createTrip()),
        icon: const Icon(Icons.add),
        label: const Text('New trip'),
      ),
      body: AsyncValueView(
        value: trips,
        onRetry: () => ref.invalidate(tripsProvider),
        data: (items) {
          if (items.isEmpty) {
            return MessageView(
              icon: Icons.luggage_outlined,
              title: 'No trips yet',
              message: 'Create your first itinerary. It is saved on this device and works offline.',
              action: FilledButton.icon(
                onPressed: () => context.push(Routes.createTrip()),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Plan a trip'),
              ),
            );
          }
          final sorted = sortTripsForDisplay(items, today);
          final upcoming = sorted.where((t) => !t.endDate.isBefore(today)).toList();
          final past = sorted.where((t) => t.endDate.isBefore(today)).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, 100),
            children: [
              if (upcoming.isNotEmpty) ...[
                _GroupLabel('Upcoming'),
                for (final t in upcoming) _TripCard(trip: t, names: names, today: today),
              ],
              if (past.isNotEmpty) ...[
                _GroupLabel('Past'),
                for (final t in past) _TripCard(trip: t, names: names, today: today),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: Space.lg, bottom: Space.md),
        child: Text(text.toUpperCase(),
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

class _TripCard extends ConsumerWidget {
  const _TripCard({required this.trip, required this.names, required this.today});

  final Trip trip;
  final Map<String, String> names;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ended = trip.endDate.isBefore(today);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: Pressable(
        onTap: () => context.push(Routes.trip(trip.id)),
        child: Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 132,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Opacity(
                      opacity: ended ? 0.55 : 1,
                      child: SceneArtwork(destinationId: trip.destinationIds.firstOrNull ?? ''),
                    ),
                    Positioned(
                      left: Space.md,
                      top: Space.md,
                      child: InfoBadge(label: tripStatusLabel(trip, today), icon: Icons.schedule, onDark: true),
                    ),
                    Positioned(
                      right: Space.xs,
                      top: Space.xs,
                      child: IconButton(
                        tooltip: 'Delete trip',
                        style: IconButton.styleFrom(backgroundColor: Colors.black26),
                        icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                        onPressed: () => confirmDeleteTrip(context, ref, trip),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(trip.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: Space.xs),
                    Text(
                      trip.destinationIds.map((id) => names[id] ?? id).join(' → '),
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary).w(700),
                    ),
                    const SizedBox(height: Space.sm),
                    Wrap(
                      spacing: Space.sm,
                      runSpacing: Space.xs,
                      children: [
                        InfoBadge(
                          icon: Icons.calendar_today_outlined,
                          label: '${formatShortDate(trip.startDate)} – ${formatShortDate(trip.endDate)}',
                        ),
                        InfoBadge(
                          icon: Icons.people_outline,
                          label: '${trip.travelers}',
                        ),
                        InfoBadge(icon: Icons.speed, label: trip.pace.label),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Returns true when the trip was deleted.
Future<bool> confirmDeleteTrip(BuildContext context, WidgetRef ref, Trip trip) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete trip?'),
      content: Text('"${trip.title}" and its itinerary will be removed from this device.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            minimumSize: const Size(0, 44),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  await ref.read(tripActionsProvider).deleteTrip(trip.id);
  return true;
}
