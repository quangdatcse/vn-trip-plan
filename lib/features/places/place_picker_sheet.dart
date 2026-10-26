import 'package:flutter/material.dart';

import '../../core/utils/dates.dart';
import '../../core/utils/geo.dart';
import '../../models/enums.dart';
import '../../models/place.dart';
import '../../shared/widgets/place_widgets.dart';

/// Bottom sheet to choose a place. Places not yet in the trip and suited to
/// [slot] come first; when replacing, nearer places come first.
Future<Place?> showPlacePicker(
  BuildContext context, {
  required List<Place> places,
  required Set<String> usedPlaceIds,
  required DaySlot slot,
  required String title,
  Place? reference,
}) {
  double distance(Place p) => reference == null
      ? 0
      : haversineKm(reference.latitude, reference.longitude, p.latitude, p.longitude);

  final sorted = places.where((p) => p.id != reference?.id).toList()
    ..sort((a, b) {
      int tier(Place p) =>
          (usedPlaceIds.contains(p.id) ? 2 : 0) + (p.suits(slot) ? 0 : 1);
      final byTier = tier(a).compareTo(tier(b));
      if (byTier != 0) return byTier;
      final byDistance = distance(a).compareTo(distance(b));
      return byDistance != 0 ? byDistance : a.nameEn.compareTo(b.nameEn);
    });

  return showModalBottomSheet<Place>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          Expanded(
            child: sorted.isEmpty
                ? const Center(child: Text('No other places in this destination yet.'))
                : ListView.builder(
                    controller: controller,
                    itemCount: sorted.length,
                    itemBuilder: (context, i) {
                      final p = sorted[i];
                      final notes = [
                        p.area,
                        '~${formatMinutes(p.suggestedDurationMinutes)}',
                        if (reference != null) '${distance(p).toStringAsFixed(1)} km away',
                        if (usedPlaceIds.contains(p.id)) 'already in trip',
                        if (!p.suits(slot)) 'better in the ${p.bestSlots.map((s) => s.label.toLowerCase()).join('/')}',
                      ];
                      return ListTile(
                        leading: CategoryAvatar(category: p.category, size: 40),
                        title: Text(p.nameEn),
                        subtitle: Text(notes.join(' · ')),
                        onTap: () => Navigator.pop(context, p),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}
