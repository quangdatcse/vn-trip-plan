import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/routing/app_router.dart';
import '../../core/utils/dates.dart';
import '../../models/destination.dart';
import '../../models/trip.dart';
import '../../shared/widgets/state_views.dart';
import '../itinerary/trip_actions.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinations = ref.watch(destinationsProvider);
    final trips = ref.watch(tripsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Vietnam TripMate'),
            actions: [
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => context.push(Routes.settings),
              ),
            ],
          ),
          const SliverToBoxAdapter(child: _HeroCard()),
          SliverToBoxAdapter(child: _SectionTitle('Popular destinations', theme: theme)),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 150,
              child: AsyncValueView(
                value: destinations,
                onRetry: () => ref.invalidate(destinationsProvider),
                data: (items) => ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => _DestinationCard(items[i]),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _SectionTitle('Your trips', theme: theme)),
          ...trips.when(
            loading: () => [const SliverToBoxAdapter(child: LoadingView())],
            error: (e, _) => [
              SliverToBoxAdapter(
                  child: ErrorView(error: e, onRetry: () => ref.invalidate(tripsProvider))),
            ],
            data: (items) => items.isEmpty
                ? [
                    const SliverToBoxAdapter(
                      child: MessageView(
                        icon: Icons.luggage_outlined,
                        title: 'No trips yet',
                        message: 'Create your first trip. It is saved on this device '
                            'and works offline.',
                      ),
                    ),
                  ]
                : [
                    SliverList.builder(
                      itemCount: items.length,
                      itemBuilder: (context, i) => _TripTile(items[i]),
                    ),
                  ],
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [scheme.primary, Color.lerp(scheme.primary, scheme.secondary, 0.55)!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Plan your Vietnam trip',
                style: theme.textTheme.headlineSmall?.copyWith(color: scheme.onPrimary)),
            const SizedBox(height: 8),
            Text(
              'Day-by-day itineraries for Da Nang and Hoi An, grouped by area '
              'and matched to your interests.',
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onPrimary),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.onPrimary,
                foregroundColor: scheme.primary,
              ),
              onPressed: () => context.push(Routes.createTrip),
              icon: const Icon(Icons.add),
              label: const Text('Create a Trip'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {required this.theme});

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(text, style: theme.textTheme.titleLarge),
      );
}

class _DestinationCard extends StatelessWidget {
  const _DestinationCard(this.destination);

  final Destination destination;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 240,
      child: Card(
        child: InkWell(
          onTap: () => context.push(Routes.destination(destination.id)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.location_city_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(destination.name, style: theme.textTheme.titleMedium)),
                ]),
                if (destination.localName != null)
                  Text(destination.localName!, style: theme.textTheme.labelMedium),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    destination.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TripTile extends ConsumerWidget {
  const _TripTile(this.trip);

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        child: ListTile(
          leading: const Icon(Icons.map_outlined),
          title: Text(trip.title),
          subtitle: Text('${formatMediumDate(trip.startDate)} · ${trip.dayCount} '
              '${trip.dayCount == 1 ? 'day' : 'days'} · ${trip.travelers} '
              '${trip.travelers == 1 ? 'traveler' : 'travelers'}'),
          onTap: () => context.push(Routes.trip(trip.id)),
          trailing: IconButton(
            tooltip: 'Delete trip',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => confirmDeleteTrip(context, ref, trip),
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
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
      ],
    ),
  );
  if (ok != true) return false;
  await ref.read(tripActionsProvider).deleteTrip(trip.id);
  return true;
}
