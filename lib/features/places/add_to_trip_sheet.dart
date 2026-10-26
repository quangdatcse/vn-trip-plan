import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/dates.dart';
import '../../models/enums.dart';
import '../../models/itinerary.dart';
import '../../models/place.dart';
import '../../models/trip.dart';
import '../../shared/widgets/place_widgets.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/ui.dart';
import '../itinerary/trip_actions.dart';

/// Lets the user add [place] to a day of one of their trips that visits the
/// place's destination.
Future<void> showAddToTripSheet(BuildContext context, Place place) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddToTripSheet(place: place),
    );

class _AddToTripSheet extends ConsumerStatefulWidget {
  const _AddToTripSheet({required this.place});

  final Place place;

  @override
  ConsumerState<_AddToTripSheet> createState() => _AddToTripSheetState();
}

class _AddToTripSheetState extends ConsumerState<_AddToTripSheet> {
  Trip? _trip;
  TripPlan? _plan;
  ItineraryDay? _day;
  late DaySlot _slot = widget.place.bestSlots.isEmpty
      ? DaySlot.morning
      : DaySlot.values.firstWhere(widget.place.bestSlots.contains);
  bool _busy = false;
  bool _autoSelected = false;

  Future<void> _selectTrip(Trip trip) async {
    setState(() {
      _trip = trip;
      _plan = null;
      _day = null;
    });
    final plan = await ref.read(tripPlanProvider(trip.id).future);
    if (!mounted || plan == null) return;
    final days = plan.days.where((d) => d.destinationId == widget.place.destinationId);
    setState(() {
      _plan = plan;
      _day = days.firstOrNull;
    });
  }

  Future<void> _add() async {
    final plan = _plan;
    final day = _day;
    if (plan == null || day == null) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      await ref.read(tripActionsProvider).addPlace(plan, day, widget.place, _slot);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(
        content: Text('Added to day ${day.dayIndex + 1} of ${plan.trip.title}'),
        action: SnackBarAction(label: 'View', onPressed: () => router.push(Routes.trip(plan.trip.id))),
      ));
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, 'Could not add the place: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trips = ref.watch(tripsProvider);
    final today = dateOnly(DateTime.now());

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.lg),
        child: AsyncValueView(
          value: trips,
          data: (all) {
            final eligible = sortTripsForDisplay(all, today)
                .where((t) => t.destinationIds.contains(widget.place.destinationId))
                .toList();
            // Preselect the soonest trip to save a tap.
            if (!_autoSelected && eligible.isNotEmpty) {
              _autoSelected = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _selectTrip(eligible.first);
              });
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add to trip', style: theme.textTheme.titleLarge),
                Text(widget.place.nameEn,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: Space.lg),
                if (eligible.isEmpty) ...[
                  Text('You have no trips that include this destination yet.',
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: Space.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        context.push(Routes.createTrip(destinationId: widget.place.destinationId));
                      },
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Plan a new trip'),
                    ),
                  ),
                ] else ...[
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final t in eligible)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            selected: _trip?.id == t.id,
                            leading: Icon(_trip?.id == t.id
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked),
                            onTap: () => _selectTrip(t),
                            title: Text(t.title),
                            subtitle: Text('${formatShortDate(t.startDate)} – ${formatShortDate(t.endDate)}'),
                          ),
                      ],
                    ),
                  ),
                  if (_plan != null) ...[
                    const SizedBox(height: Space.md),
                    Text('Day', style: theme.textTheme.titleSmall),
                    const SizedBox(height: Space.sm),
                    Wrap(
                      spacing: Space.sm,
                      runSpacing: Space.sm,
                      children: [
                        for (final d in _plan!.days.where((d) => d.destinationId == widget.place.destinationId))
                          SelectPill(
                            label: 'Day ${d.dayIndex + 1} · ${formatShortDate(d.date)}',
                            selected: _day?.id == d.id,
                            onTap: () => setState(() => _day = d),
                          ),
                      ],
                    ),
                    const SizedBox(height: Space.md),
                    Text('Time of day', style: theme.textTheme.titleSmall),
                    const SizedBox(height: Space.sm),
                    Wrap(
                      spacing: Space.sm,
                      children: [
                        for (final s in DaySlot.values)
                          SelectPill(
                            label: s.label,
                            icon: slotIcon(s),
                            selected: _slot == s,
                            onTap: () => setState(() => _slot = s),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: Space.xl),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _day == null || _busy ? null : _add,
                      child: Text(_busy ? 'Adding…' : 'Add to itinerary'),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
