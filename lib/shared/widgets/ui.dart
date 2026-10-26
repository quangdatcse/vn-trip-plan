import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/dates.dart';
import '../../models/place.dart';
import 'artwork.dart';

/// Scales down slightly while pressed, like native iOS cards.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.borderRadius});

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap != null && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                widget.onTap!();
              },
        child: AnimatedScale(
          scale: _down ? 0.97 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.subtitle, this.actionLabel, this.onAction});

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.page, Space.xl, Space.page - 8, Space.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ),
              ],
            ),
          ),
          if (actionLabel != null) TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// Selectable pill used for interests, currencies and filters.
class SelectPill extends StatelessWidget {
  const SelectPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.onPrimary : scheme.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(horizontal: icon == null ? 16 : 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 6)],
              Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small rounded info badge.
class InfoBadge extends StatelessWidget {
  const InfoBadge({super.key, required this.label, this.icon, this.color, this.onDark = false});

  final String label;
  final IconData? icon;
  final Color? color;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = onDark ? Colors.white : (color ?? scheme.onSurfaceVariant);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: onDark
            ? Colors.white.withValues(alpha: 0.18)
            : (color ?? scheme.onSurfaceVariant).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 4)],
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, letterSpacing: 0.1)),
        ],
      ),
    );
  }
}

/// Heart toggle for saving a place.
class SaveButton extends ConsumerWidget {
  const SaveButton({super.key, required this.placeId, this.onDark = false, this.size = 22});

  final String placeId;
  final bool onDark;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedPlaceIdsProvider).value?.contains(placeId) ?? false;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: onDark ? Colors.black.withValues(alpha: 0.25) : scheme.surfaceContainerLowest,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: saved ? 'Remove from saved' : 'Save place',
        iconSize: size,
        visualDensity: VisualDensity.compact,
        onPressed: () async {
          HapticFeedback.lightImpact();
          await ref.read(savedPlacesRepositoryProvider).toggle(placeId);
          ref.invalidate(savedPlaceIdsProvider);
        },
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
          child: Icon(
            saved ? Icons.favorite : Icons.favorite_border,
            key: ValueKey(saved),
            color: saved ? Palette.lanternRed : (onDark ? Colors.white : scheme.onSurface),
          ),
        ),
      ),
    );
  }
}

/// Vertical card for horizontal carousels.
class PlaceCard extends StatelessWidget {
  const PlaceCard({super.key, required this.place, this.width = 200});

  final Place place;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Pressable(
        onTap: () => context.push(Routes.place(place.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.lg),
              child: AspectRatio(
                aspectRatio: 1.05,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CategoryCover(category: place.category, seed: place.id, iconSize: 30),
                    Positioned(top: 8, right: 8, child: SaveButton(placeId: place.id, onDark: true, size: 20)),
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: InfoBadge(
                        label: formatMinutes(place.suggestedDurationMinutes),
                        icon: Icons.schedule,
                        onDark: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Space.sm + 2),
            Text(place.nameEn, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
            const SizedBox(height: 2),
            Text('${place.category.label} · ${place.area}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

/// Full-width row card for lists.
class PlaceRow extends StatelessWidget {
  const PlaceRow({super.key, required this.place, this.trailing, this.onTap, this.subtitle});

  final Place place;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Pressable(
      onTap: onTap ?? () => context.push(Routes.place(place.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.page, vertical: Space.sm),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.md),
              child: SizedBox.square(
                dimension: 72,
                child: CategoryCover(category: place.category, seed: place.id, iconSize: 22),
              ),
            ),
            const SizedBox(width: Space.md + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.nameEn, style: theme.textTheme.titleSmall?.copyWith(fontSize: 15)),
                  const SizedBox(height: 3),
                  Text(
                    subtitle ??
                        '${place.category.label} · ${place.area} · ${formatMinutes(place.suggestedDurationMinutes)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            trailing ?? SaveButton(placeId: place.id),
          ],
        ),
      ),
    );
  }
}

/// Back button readable on top of artwork. Falls back to Explore when the
/// page was opened directly (e.g. a web refresh) and there is nothing to pop.
class ArtworkBackButton extends StatelessWidget {
  const ArtworkBackButton({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(Space.sm),
        child: IconButton(
          tooltip: 'Back',
          style: IconButton.styleFrom(backgroundColor: Colors.black26, foregroundColor: Colors.white),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.explore),
        ),
      );
}

/// Numeric summary tile.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label, this.icon});

  final String value;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(height: 6),
          Text(value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(fontSize: value.length > 10 ? 14 : 18)),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
