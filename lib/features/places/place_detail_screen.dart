import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/dates.dart';
import '../../models/enums.dart';
import '../../models/place.dart';
import '../../services/maps/maps_launcher.dart';
import '../../shared/widgets/artwork.dart';
import '../../shared/widgets/place_widgets.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/ui.dart';
import '../explore/explore_screen.dart';
import 'add_to_trip_sheet.dart';

class PlaceDetailScreen extends ConsumerWidget {
  const PlaceDetailScreen({super.key, required this.placeId});

  final String placeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final place = ref.watch(placeProvider(placeId));
    return place.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(error: e, onRetry: () => ref.invalidate(placeProvider(placeId))),
      ),
      data: (p) => p == null
          ? Scaffold(
              appBar: AppBar(),
              body: const MessageView(icon: Icons.search_off, title: 'Place not found'),
            )
          : _PlaceDetail(place: p),
    );
  }
}

class _PlaceDetail extends ConsumerWidget {
  const _PlaceDetail({required this.place});

  final Place place;

  Future<void> _open(BuildContext context, Uri uri) async {
    if (!await openExternal(uri) && context.mounted) {
      showSnack(context, 'Could not open a maps app.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final maps = ref.watch(mapsLauncherProvider);
    final p = place;
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Scaffold(
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(Space.page, Space.md, Space.page, Space.md),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
          ),
          child: Row(
            children: [
              IconButton.outlined(
                tooltip: 'Directions',
                style: IconButton.styleFrom(minimumSize: const Size(54, 54)),
                onPressed: () => _open(context, maps.directionsUri(p, TransportMode.taxi)),
                icon: const Icon(Icons.directions_outlined),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => showAddToTripSheet(context, p),
                  icon: const Icon(Icons.add),
                  label: const Text('Add to trip'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            stretch: true,
            leading: const ArtworkBackButton(),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: Space.sm),
                child: SaveButton(placeId: p.id, onDark: true),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: CategoryCover(category: p.category, seed: p.id, iconSize: 44),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Space.page, Space.xl, Space.page, Space.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.category.label.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.secondary)),
                  const SizedBox(height: Space.xs),
                  Text(p.nameEn, style: theme.textTheme.headlineMedium),
                  if (p.nameLocal != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(p.nameLocal!, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant).w(500)),
                    ),
                  const SizedBox(height: Space.lg),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(Space.lg),
                      child: Row(
                        children: [
                          StatTile(
                            icon: Icons.schedule,
                            value: formatMinutes(p.suggestedDurationMinutes),
                            label: 'Suggested visit',
                          ),
                          StatTile(
                            icon: Icons.wb_twilight,
                            value: p.bestSlots.isEmpty
                                ? 'Any time'
                                : p.bestSlots.map((s) => s.label).join(', '),
                            label: 'Best time',
                          ),
                          StatTile(icon: Icons.near_me_outlined, value: p.area, label: 'Area'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.xl),
                  Text('About', style: theme.textTheme.titleLarge),
                  const SizedBox(height: Space.sm),
                  Text(p.description, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: Space.lg),
                  Wrap(
                    spacing: Space.sm,
                    runSpacing: Space.sm,
                    children: [
                      for (final i in p.interests) InfoBadge(label: i.label, icon: interestIcon(i)),
                    ],
                  ),
                  const SizedBox(height: Space.xl),
                  Text('Getting there', style: theme.textTheme.titleLarge),
                  const SizedBox(height: Space.md),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.map_outlined),
                          title: const Text('Open in Maps'),
                          subtitle: Text('${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}'
                              '${p.verificationStatus == VerificationStatus.verified ? '' : ' · approximate'}'),
                          trailing: const Icon(Icons.open_in_new, size: 18),
                          onTap: () => _open(context, maps.placeUri(p)),
                        ),
                        const Divider(indent: Space.lg, endIndent: Space.lg),
                        ListTile(
                          leading: const Icon(Icons.local_activity_outlined),
                          title: const Text('Tours & tickets nearby'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(Routes.offers(p.destinationId)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.xl),
                  Container(
                    padding: const EdgeInsets.all(Space.lg),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(child: Text('About this information', style: theme.textTheme.titleSmall)),
                          VerificationChip(status: p.verificationStatus),
                        ]),
                        const SizedBox(height: Space.sm),
                        Text('Source: ${p.source}', style: muted),
                        Text('Last verified: ${p.verifiedOn == null ? 'not yet' : formatMediumDate(p.verifiedOn!)}',
                            style: muted),
                        if (p.imageCredit != null) Text('Image: ${p.imageCredit}', style: muted),
                        const SizedBox(height: Space.sm),
                        Text(
                          'Opening hours and ticket prices are not listed because they have not '
                          'been verified. Please check locally.',
                          style: muted,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
