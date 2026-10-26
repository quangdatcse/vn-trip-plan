import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/tokens.dart';
import '../../models/enums.dart';
import '../../shared/widgets/artwork.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/ui.dart';
import '../explore/explore_screen.dart';

/// Destination detail: hero artwork, overview and all its places.
class PlacesScreen extends ConsumerStatefulWidget {
  const PlacesScreen({super.key, required this.destinationId});

  final String destinationId;

  @override
  ConsumerState<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends ConsumerState<PlacesScreen> {
  Interest? _filter;

  @override
  Widget build(BuildContext context) {
    final destination = ref
        .watch(destinationsProvider)
        .value
        ?.where((d) => d.id == widget.destinationId)
        .firstOrNull;
    final places = ref.watch(placesByDestinationProvider(widget.destinationId));
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            stretch: true,
            backgroundColor: theme.colorScheme.surface,
            leading: const ArtworkBackButton(),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(tag: 'dest-${widget.destinationId}', child: SceneArtwork(destinationId: widget.destinationId)),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x55000000), Colors.transparent, Color(0xAA000000)],
                        stops: [0, 0.4, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: Space.page,
                    right: Space.page,
                    bottom: Space.xl,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (destination != null)
                          InfoBadge(label: destination.region, icon: Icons.place_outlined, onDark: true),
                        const SizedBox(height: Space.sm),
                        Text(destination?.name ?? '',
                            style: theme.textTheme.displaySmall?.copyWith(color: Colors.white)),
                        if (destination?.localName != null)
                          Text(destination!.localName!,
                              style: theme.textTheme.titleMedium?.copyWith(color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.page, Space.xl, Space.page, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (destination != null)
                    Text(destination.description, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: Space.lg + 4),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () =>
                              context.push(Routes.createTrip(destinationId: widget.destinationId)),
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Plan a trip here'),
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      IconButton.outlined(
                        tooltip: 'Tours & tickets',
                        iconSize: 22,
                        style: IconButton.styleFrom(minimumSize: const Size(54, 54)),
                        onPressed: () => context.push(Routes.offers(widget.destinationId)),
                        icon: const Icon(Icons.local_activity_outlined),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SectionHeader('Places to visit')),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Space.page),
                children: [
                  for (final i in Interest.values)
                    Padding(
                      padding: const EdgeInsets.only(right: Space.sm),
                      child: SelectPill(
                        label: i.label,
                        icon: interestIcon(i),
                        selected: _filter == i,
                        onTap: () => setState(() => _filter = _filter == i ? null : i),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: Space.sm)),
          ...places.when(
            loading: () => [const SliverToBoxAdapter(child: LoadingView())],
            error: (e, _) => [
              SliverToBoxAdapter(
                child: ErrorView(error: e, onRetry: () => ref.invalidate(allPlacesProvider)),
              ),
            ],
            data: (items) {
              final shown = _filter == null
                  ? items
                  : items.where((p) => p.interests.contains(_filter)).toList();
              if (shown.isEmpty) {
                return [
                  const SliverToBoxAdapter(
                    child: MessageView(icon: Icons.search_off, title: 'No places match this filter'),
                  ),
                ];
              }
              return [SliverList.builder(itemCount: shown.length, itemBuilder: (_, i) => PlaceRow(place: shown[i]))];
            },
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.page, Space.lg, Space.page, Space.xxl),
              child: Text(
                'Place information is an editorial draft and has not been verified on site. '
                'Coordinates are approximate.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
