import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/routing/app_router.dart';
import '../../core/utils/dates.dart';
import '../../models/enums.dart';
import '../../shared/widgets/place_widgets.dart';
import '../../shared/widgets/state_views.dart';

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
    final destinations = ref.watch(destinationsProvider);
    final places = ref.watch(placesByDestinationProvider(widget.destinationId));
    final theme = Theme.of(context);
    final destination = destinations.value
        ?.where((d) => d.id == widget.destinationId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(destination?.name ?? 'Places')),
      body: AsyncValueView(
        value: places,
        onRetry: () => ref.invalidate(allPlacesProvider),
        data: (items) {
          final shown = _filter == null
              ? items
              : items.where((p) => p.interests.contains(_filter)).toList();
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              if (destination != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(destination.description, style: theme.textTheme.bodyMedium),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: () => context.push(Routes.offers(widget.destinationId)),
                  icon: const Icon(Icons.local_activity_outlined),
                  label: const Text('Tours, tickets & activities'),
                ),
              ),
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    for (final i in Interest.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(i.label),
                          selected: _filter == i,
                          onSelected: (on) => setState(() => _filter = on ? i : null),
                        ),
                      ),
                  ],
                ),
              ),
              if (shown.isEmpty)
                const MessageView(icon: Icons.search_off, title: 'No places match this filter'),
              for (final p in shown)
                ListTile(
                  leading: CategoryAvatar(category: p.category),
                  title: Text(p.nameEn),
                  subtitle: Text('${p.area} · ${p.category.label} · '
                      '~${formatMinutes(p.suggestedDurationMinutes)}'),
                  onTap: () => context.push(Routes.place(p.id)),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Place information is an editorial draft and has not been verified on site. '
                  'Coordinates are approximate.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
