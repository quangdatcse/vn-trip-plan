import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/ui.dart';

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(savedPlaceIdsProvider);
    final places = ref.watch(allPlacesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Saved places'), toolbarHeight: 64),
      body: AsyncValueView(
        value: ids,
        onRetry: () => ref.invalidate(savedPlaceIdsProvider),
        data: (savedIds) {
          final byId = {for (final p in places.value ?? const []) p.id: p};
          final saved = [for (final id in savedIds) if (byId[id] != null) byId[id]!];
          if (saved.isEmpty) {
            return MessageView(
              icon: Icons.favorite_border,
              title: 'Nothing saved yet',
              message: 'Tap the heart on any place to keep it here for later.',
              action: OutlinedButton.icon(
                onPressed: () => context.go(Routes.explore),
                icon: const Icon(Icons.explore_outlined),
                label: const Text('Explore places'),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.only(top: Space.sm, bottom: Space.xxl),
            children: [for (final p in saved) PlaceRow(place: p)],
          );
        },
      ),
    );
  }
}
