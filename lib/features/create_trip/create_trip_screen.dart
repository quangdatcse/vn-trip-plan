import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/routing/app_router.dart';
import '../../core/utils/dates.dart';
import '../../models/enums.dart';
import '../../models/trip.dart';
import '../../shared/widgets/place_widgets.dart';
import '../../shared/widgets/state_views.dart';
import '../itinerary/trip_actions.dart';

class CreateTripScreen extends ConsumerStatefulWidget {
  const CreateTripScreen({super.key});

  @override
  ConsumerState<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends ConsumerState<CreateTripScreen> {
  final _draft = TripDraft();
  List<String> _errors = const [];
  bool _saving = false;

  Future<void> _pickDates() async {
    // The picker works in local time; the draft stores UTC date-only values.
    DateTime local(DateTime d) => DateTime(d.year, d.month, d.day);
    final today = DateUtils.dateOnly(DateTime.now());
    final range = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 730)),
      initialDateRange: _draft.startDate != null && _draft.endDate != null
          ? DateTimeRange(start: local(_draft.startDate!), end: local(_draft.endDate!))
          : null,
      helpText: 'Travel dates',
    );
    if (range != null) {
      setState(() {
        _draft.startDate = dateOnly(range.start);
        _draft.endDate = dateOnly(range.end);
      });
    }
  }

  Future<void> _submit() async {
    final errors = _draft.validate();
    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;

    setState(() => _saving = true);
    try {
      final tripId = await ref.read(tripActionsProvider).createTrip(_draft);
      if (mounted) context.pushReplacement(Routes.trip(tripId));
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, 'Could not create the trip: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final destinations = ref.watch(destinationsProvider);
    final theme = Theme.of(context);
    final start = _draft.startDate;
    final end = _draft.endDate;

    return Scaffold(
      appBar: AppBar(title: const Text('Create a Trip')),
      body: AsyncValueView(
        value: destinations,
        onRetry: () => ref.invalidate(destinationsProvider),
        data: (items) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Trip name (optional)',
                hintText: 'e.g. Central Vietnam getaway',
              ),
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (v) => _draft.title = v,
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Starting from',
                hintText: 'e.g. Da Nang International Airport',
                prefixIcon: Icon(Icons.flight_land_outlined),
              ),
              maxLength: 100,
              textCapitalization: TextCapitalization.words,
              onChanged: (v) => _draft.origin = v,
            ),
            _Label('Destinations', theme: theme, hint: 'Visited in the order you select them'),
            Wrap(
              spacing: 8,
              children: [
                for (final d in items)
                  FilterChip(
                    label: Text(d.name),
                    selected: _draft.destinationIds.contains(d.id),
                    onSelected: (on) => setState(() {
                      on ? _draft.destinationIds.add(d.id) : _draft.destinationIds.remove(d.id);
                    }),
                  ),
              ],
            ),
            _Label('Dates', theme: theme),
            OutlinedButton.icon(
              onPressed: _pickDates,
              icon: const Icon(Icons.date_range_outlined),
              label: Text(start == null || end == null
                  ? 'Choose dates'
                  : '${formatShortDate(start)} – ${formatShortDate(end)} '
                      '(${end.difference(start).inDays + 1} days)'),
            ),
            _Label('Travelers', theme: theme),
            Row(
              children: [
                IconButton.outlined(
                  tooltip: 'Fewer travelers',
                  onPressed: _draft.travelers > 1
                      ? () => setState(() => _draft.travelers--)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: 56,
                  child: Text('${_draft.travelers}',
                      textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
                ),
                IconButton.outlined(
                  tooltip: 'More travelers',
                  onPressed: _draft.travelers < TripDraft.maxTravelers
                      ? () => setState(() => _draft.travelers++)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            _Label('Budget (optional)', theme: theme, hint: 'Total for the trip, for your reference'),
            TextField(
              decoration: InputDecoration(labelText: 'Amount', suffixText: _draft.currency),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) => _draft.budgetText = v,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final c in TripDraft.currencies)
                  ChoiceChip(
                    label: Text(c),
                    selected: _draft.currency == c,
                    onSelected: (_) => setState(() => _draft.currency = c),
                  ),
              ],
            ),
            _Label('Interests', theme: theme),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final i in Interest.values)
                  FilterChip(
                    label: Text(i.label),
                    selected: _draft.interests.contains(i),
                    onSelected: (on) => setState(() {
                      on ? _draft.interests.add(i) : _draft.interests.remove(i);
                    }),
                  ),
              ],
            ),
            _Label('Pace', theme: theme, hint: _draft.pace.description),
            SegmentedButton<Pace>(
              segments: [
                for (final p in Pace.values) ButtonSegment(value: p, label: Text(p.label)),
              ],
              selected: {_draft.pace},
              onSelectionChanged: (s) => setState(() => _draft.pace = s.first),
            ),
            _Label('Getting around', theme: theme),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final m in TransportMode.values)
                  ChoiceChip(
                    avatar: Icon(transportIcon(m), size: 18),
                    label: Text(m.label),
                    selected: _draft.transport == m,
                    onSelected: (_) => setState(() => _draft.transport = m),
                  ),
              ],
            ),
            if (_errors.isNotEmpty) ...[
              const SizedBox(height: 20),
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final e in _errors)
                        Text('• $e',
                            style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome_outlined),
              label: const Text('Generate itinerary'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {required this.theme, this.hint});

  final String text;
  final String? hint;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: theme.textTheme.titleSmall),
            if (hint != null)
              Text(hint!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      );
}
