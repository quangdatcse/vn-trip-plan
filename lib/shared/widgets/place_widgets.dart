import 'package:flutter/material.dart';

import '../../models/enums.dart';

IconData categoryIcon(PlaceCategory category) => switch (category) {
      PlaceCategory.landmark => Icons.place_outlined,
      PlaceCategory.museum => Icons.museum_outlined,
      PlaceCategory.religiousSite => Icons.temple_buddhist_outlined,
      PlaceCategory.heritageSite => Icons.account_balance_outlined,
      PlaceCategory.market => Icons.storefront_outlined,
      PlaceCategory.beach => Icons.beach_access_outlined,
      PlaceCategory.nature => Icons.landscape_outlined,
      PlaceCategory.village => Icons.cottage_outlined,
      PlaceCategory.entertainment => Icons.attractions_outlined,
    };

IconData slotIcon(DaySlot slot) => switch (slot) {
      DaySlot.morning => Icons.wb_twilight,
      DaySlot.afternoon => Icons.wb_sunny_outlined,
      DaySlot.evening => Icons.nights_stay_outlined,
    };

IconData transportIcon(TransportMode mode) => switch (mode) {
      TransportMode.walking => Icons.directions_walk,
      TransportMode.bicycle => Icons.directions_bike,
      TransportMode.motorbike => Icons.two_wheeler,
      TransportMode.taxi => Icons.local_taxi_outlined,
      TransportMode.privateCar => Icons.directions_car_outlined,
    };

/// Placeholder used until licensed images are available.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({super.key, required this.category, this.size = 44});

  final PlaceCategory category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(size / 3.5),
      ),
      child: Icon(categoryIcon(category), color: scheme.onPrimaryContainer, size: size * 0.5),
    );
  }
}

class VerificationChip extends StatelessWidget {
  const VerificationChip({super.key, required this.status});

  final VerificationStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final verified = status == VerificationStatus.verified;
    final color = verified ? scheme.primary : scheme.tertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(verified ? Icons.verified_outlined : Icons.info_outline, size: 14, color: color),
          const SizedBox(width: 4),
          Text(status.label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
        ],
      ),
    );
  }
}
