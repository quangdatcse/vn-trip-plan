import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/routing/app_router.dart';
import '../../core/utils/dates.dart';
import '../../models/enums.dart';
import '../../models/place.dart';
import '../../services/maps/maps_launcher.dart';
import '../../shared/widgets/place_widgets.dart';
import '../../shared/widgets/state_views.dart';

class PlaceDetailScreen extends ConsumerWidget {
  const PlaceDetailScreen({super.key, required this.placeId});

  final String placeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final place = ref.watch(placeProvider(placeId));
    return Scaffold(
      appBar: AppBar(),
      body: AsyncValueView<Place?>(
        value: place,
        onRetry: () => ref.invalidate(placeProvider(placeId)),
        data: (p) => p == null
            ? const MessageView(icon: Icons.search_off, title: 'Place not found')
            : _PlaceDetail(place: p),
      ),
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        Row(
          children: [
            CategoryAvatar(category: p.category, size: 56),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.nameEn, style: theme.textTheme.headlineSmall),
                  if (p.nameLocal != null)
                    Text(p.nameLocal!, style: theme.textTheme.titleSmall),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text(p.category.label)),
            Chip(label: Text(p.area)),
            Chip(label: Text('~${formatMinutes(p.suggestedDurationMinutes)} suggested')),
          ],
        ),
        const SizedBox(height: 12),
        Text(p.description, style: theme.textTheme.bodyLarge),
        if (p.bestSlots.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Best visited: ${p.bestSlots.map((s) => s.label.toLowerCase()).join(', ')}',
              style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => _open(context, maps.placeUri(p)),
              icon: const Icon(Icons.map_outlined),
              label: const Text('Open in Maps'),
            ),
            OutlinedButton.icon(
              onPressed: () => _open(context, maps.directionsUri(p, TransportMode.taxi)),
              icon: const Icon(Icons.directions_outlined),
              label: const Text('Directions'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push(Routes.offers(p.destinationId)),
              icon: const Icon(Icons.local_activity_outlined),
              label: const Text('Tours nearby'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('About this information', style: theme.textTheme.titleSmall),
                  const Spacer(),
                  VerificationChip(status: p.verificationStatus),
                ]),
                const SizedBox(height: 8),
                Text('Source: ${p.source}', style: theme.textTheme.bodySmall),
                Text(
                  'Last verified: ${p.verifiedOn == null ? 'not yet' : formatMediumDate(p.verifiedOn!)}',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  'Coordinates: ${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}'
                  '${p.verificationStatus == VerificationStatus.verified ? '' : ' (approximate)'}',
                  style: theme.textTheme.bodySmall,
                ),
                if (p.imageCredit != null)
                  Text('Image: ${p.imageCredit}', style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                Text(
                  'Opening hours and ticket prices are not listed because they have not '
                  'been verified. Please check locally.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
