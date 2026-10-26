import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/dates.dart';
import '../../models/destination.dart';
import '../../models/enums.dart';
import '../../models/place.dart';
import '../../models/trip.dart';
import '../../shared/widgets/artwork.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/ui.dart';
import '../itinerary/trip_actions.dart';

class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinations = ref.watch(destinationsProvider);
    final places = ref.watch(allPlacesProvider);
    final trips = ref.watch(tripsProvider);
    final theme = Theme.of(context);
    final today = dateOnly(DateTime.now());
    final nextTrip = trips.value == null
        ? null
        : sortTripsForDisplay(trips.value!, today)
            .where((t) => !t.endDate.isBefore(today))
            .firstOrNull;

    if (destinations.hasError || places.hasError) {
      return Scaffold(
        body: ErrorView(
          error: destinations.error ?? places.error!,
          onRetry: () {
            ref.invalidate(destinationsProvider);
            ref.invalidate(allPlacesProvider);
          },
        ),
      );
    }
    final dests = destinations.value;
    final catalog = places.value;
    if (dests == null || catalog == null) return const Scaffold(body: LoadingView());

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverSafeArea(
            bottom: false,
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Palette.lantern, Palette.lanternRed]),
                            borderRadius: BorderRadius.circular(Radii.sm),
                          ),
                          child: const Icon(Icons.light_outlined, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: Space.sm + 2),
                        Text('TripMate', style: theme.textTheme.titleMedium),
                        const Spacer(),
                        InfoBadge(label: 'Central Vietnam', icon: Icons.place_outlined),
                      ],
                    ),
                    const SizedBox(height: Space.xl),
                    Text('Xin chào!',
                        style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.secondary)),
                    const SizedBox(height: Space.xs),
                    Text('Where in Vietnam\nare you heading?', style: theme.textTheme.headlineLarge),
                    const SizedBox(height: Space.lg + 4),
                    _SearchField(onTap: () => context.push(Routes.search())),
                  ],
                ),
              ),
            ),
          ),
          if (nextTrip != null)
            SliverToBoxAdapter(child: _NextTripBanner(trip: nextTrip, today: today)),
          const SliverToBoxAdapter(child: SectionHeader('Destinations', subtitle: 'Start with Central Vietnam')),
          SliverToBoxAdapter(child: _DestinationCarousel(destinations: dests, places: catalog)),
          SliverToBoxAdapter(child: _PlanCta(onTap: () => context.push(Routes.createTrip()))),
          const SliverToBoxAdapter(child: SectionHeader('Browse by interest')),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 104,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Space.page),
                itemCount: Interest.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: Space.md),
                itemBuilder: (context, i) => _InterestTile(Interest.values[i]),
              ),
            ),
          ),
          for (final d in dests) ...[
            SliverToBoxAdapter(
              child: SectionHeader(
                'Explore ${d.name}',
                actionLabel: 'See all',
                onAction: () => context.push(Routes.destination(d.id)),
              ),
            ),
            SliverToBoxAdapter(
              child: _PlaceCarousel(places: catalog.where((p) => p.destinationId == d.id).toList()),
            ),
          ],
          const SliverToBoxAdapter(
            child: SectionHeader('After dark', subtitle: 'Best enjoyed in the evening'),
          ),
          SliverToBoxAdapter(
            child: _PlaceCarousel(
              places: catalog.where((p) => p.bestSlots.contains(DaySlot.evening)).toList(),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: Space.xxl)),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: 'Search places',
      child: Pressable(
        onTap: onTap,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: theme.colorScheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Palette.ink.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.search, color: theme.colorScheme.primary),
              const SizedBox(width: Space.md),
              Expanded(
                child: Text('Search places, areas, markets…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextTripBanner extends StatelessWidget {
  const _NextTripBanner({required this.trip, required this.today});

  final Trip trip;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.page, Space.xl, Space.page, 0),
      child: Pressable(
        onTap: () => context.push(Routes.trip(trip.id)),
        child: Container(
          padding: const EdgeInsets.all(Space.lg),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.md),
                child: SizedBox.square(
                  dimension: 56,
                  child: SceneArtwork(destinationId: trip.destinationIds.firstOrNull ?? ''),
                ),
              ),
              const SizedBox(width: Space.md + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tripStatusLabel(trip, today).toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onPrimary.withValues(alpha: 0.8))),
                    const SizedBox(height: 2),
                    Text(trip.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onPrimary)),
                    Text('${formatShortDate(trip.startDate)} – ${formatShortDate(trip.endDate)}',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onPrimary.withValues(alpha: 0.85))),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward, color: theme.colorScheme.onPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

class _DestinationCarousel extends StatelessWidget {
  const _DestinationCarousel({required this.destinations, required this.places});

  final List<Destination> destinations;
  final List<Place> places;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 340,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.page),
        itemCount: destinations.length,
        separatorBuilder: (_, _) => const SizedBox(width: Space.md + 2),
        itemBuilder: (context, i) {
          final d = destinations[i];
          final count = places.where((p) => p.destinationId == d.id).length;
          return Pressable(
            onTap: () => context.push(Routes.destination(d.id)),
            child: SizedBox(
              width: MediaQuery.sizeOf(context).width * 0.74,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.xl),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(tag: 'dest-${d.id}', child: SceneArtwork(destinationId: d.id)),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xCC000000)],
                          stops: [0.45, 1],
                        ),
                      ),
                    ),
                    Positioned(
                      left: Space.lg + 4,
                      right: Space.lg + 4,
                      bottom: Space.lg + 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InfoBadge(label: '$count places', icon: Icons.place_outlined, onDark: true),
                          const SizedBox(height: Space.sm),
                          Text(d.name,
                              style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white)),
                          if (d.localName != null)
                            Text(d.localName!,
                                style: theme.textTheme.titleSmall?.copyWith(color: Colors.white70).w(500)),
                        ],
                      ),
                    ),
                    Positioned(
                      top: Space.lg,
                      right: Space.lg,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.north_east, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PlanCta extends StatelessWidget {
  const _PlanCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.page, Space.xl, Space.page, 0),
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(Space.lg + 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.lg),
            gradient: const LinearGradient(
              colors: [Palette.seaDeep, Palette.sea],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Plan a trip in a minute',
                        style: theme.textTheme.titleLarge?.copyWith(color: Colors.white)),
                    const SizedBox(height: Space.xs),
                    Text('Answer four quick steps and get a full day-by-day itinerary.',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
                  ],
                ),
              ),
              const SizedBox(width: Space.md),
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(color: Palette.lantern, shape: BoxShape.circle),
                child: const Icon(Icons.auto_awesome, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData interestIcon(Interest i) => switch (i) {
      Interest.food => Icons.ramen_dining_outlined,
      Interest.culture => Icons.temple_buddhist_outlined,
      Interest.nature => Icons.forest_outlined,
      Interest.beaches => Icons.beach_access_outlined,
      Interest.adventure => Icons.hiking_outlined,
      Interest.shopping => Icons.shopping_bag_outlined,
      Interest.family => Icons.family_restroom_outlined,
    };

class _InterestTile extends StatelessWidget {
  const _InterestTile(this.interest);

  final Interest interest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Pressable(
      onTap: () => context.push(Routes.search(interest: interest)),
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(Radii.md + 4),
                border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
              ),
              child: Icon(interestIcon(interest), color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 6),
            Text(interest.label,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _PlaceCarousel extends StatelessWidget {
  const _PlaceCarousel({required this.places});

  final List<Place> places;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 262,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Space.page),
          itemCount: places.length,
          separatorBuilder: (_, _) => const SizedBox(width: Space.md + 2),
          itemBuilder: (context, i) => PlaceCard(place: places[i], width: 196),
        ),
      );
}
