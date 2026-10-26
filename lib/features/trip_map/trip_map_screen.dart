import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/utils/dates.dart';
import '../../models/place.dart';
import '../../services/maps/maps_launcher.dart';
import '../../shared/widgets/place_widgets.dart';
import '../../shared/widgets/state_views.dart';

/// Lists each day's stops with links to an external maps app. No in-app map
/// SDK or paid map API is used in the MVP.
class TripMapScreen extends ConsumerWidget {
  const TripMapScreen({super.key, required this.tripId});

  final String tripId;

  Future<void> _open(BuildContext context, Uri uri) async {
    if (!await openExternal(uri) && context.mounted) {
      showSnack(context, 'Could not open a maps app.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(tripPlanProvider(tripId));
    final places = ref.watch(allPlacesProvider);
    final maps = ref.watch(mapsLauncherProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Map & directions')),
      body: AsyncValueView(
        value: plan,
        onRetry: () => ref.invalidate(tripPlanProvider(tripId)),
        data: (p) {
          final catalog = places.value;
          if (p == null) return const MessageView(icon: Icons.search_off, title: 'Trip not found');
          if (catalog == null) return const LoadingView();
          final byId = {for (final place in catalog) place.id: place};
          final mode = p.trip.transport;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(
                'Opens Apple Maps or Google Maps. Your location is only used by the maps app, '
                'never by TripMate.',
                style: theme.textTheme.bodySmall,
              ),
              for (final day in p.days) ...[
                const SizedBox(height: 16),
                Builder(builder: (context) {
                  final stops = [
                    for (final item in day.orderedItems)
                      if (byId[item.placeId] != null) byId[item.placeId]!,
                  ];
                  final route = maps.dayRouteUri(stops, mode);
                  return Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListTile(
                          title: Text('Day ${day.dayIndex + 1} · ${formatShortDate(day.date)}',
                              style: theme.textTheme.titleMedium),
                          subtitle: Text(stops.isEmpty ? 'No stops' : '${stops.length} stops'),
                          trailing: route == null
                              ? null
                              : TextButton.icon(
                                  onPressed: () => _open(context, route),
                                  icon: const Icon(Icons.route_outlined),
                                  label: const Text('Day route'),
                                ),
                        ),
                        for (var i = 0; i < stops.length; i++)
                          _StopTile(
                            index: i + 1,
                            place: stops[i],
                            onOpen: () => _open(context, maps.placeUri(stops[i])),
                            onDirections: () => _open(context, maps.directionsUri(stops[i], mode)),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _StopTile extends StatelessWidget {
  const _StopTile({
    required this.index,
    required this.place,
    required this.onOpen,
    required this.onDirections,
  });

  final int index;
  final Place place;
  final VoidCallback onOpen;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: CircleAvatar(radius: 14, child: Text('$index')),
        title: Text(place.nameEn),
        subtitle: Text(place.area),
        onTap: onOpen,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Open in Maps',
              icon: Icon(categoryIcon(place.category)),
              onPressed: onOpen,
            ),
            IconButton(
              tooltip: 'Directions',
              icon: const Icon(Icons.directions_outlined),
              onPressed: onDirections,
            ),
          ],
        ),
      );
}
