import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/dates.dart';
import '../../models/destination.dart';
import '../../models/enums.dart';
import '../../models/trip.dart';
import '../../shared/widgets/artwork.dart';
import '../../shared/widgets/place_widgets.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/ui.dart';
import '../explore/explore_screen.dart';
import '../itinerary/trip_actions.dart';

class CreateTripScreen extends ConsumerStatefulWidget {
  const CreateTripScreen({super.key, this.initialDestinationId});

  final String? initialDestinationId;

  @override
  ConsumerState<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends ConsumerState<CreateTripScreen> {
  static const _stepCount = 4;
  static const _stepTitles = ['Where', 'When & who', 'Travel style', 'Review'];

  final _draft = TripDraft();
  final _pages = PageController();
  final _origin = TextEditingController();
  final _budget = TextEditingController();
  final _title = TextEditingController();
  int _step = 0;
  List<String> _errors = const [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final dest = widget.initialDestinationId;
    if (dest != null) _draft.destinationIds.add(dest);
  }

  @override
  void dispose() {
    _pages.dispose();
    _origin.dispose();
    _budget.dispose();
    _title.dispose();
    super.dispose();
  }

  List<String> _validateStep(int step) => switch (step) {
    0 => _draft.validateWhere(),
    1 => _draft.validateWhen(),
    3 => _draft.validate(),
    _ => const [],
  };

  void _goTo(int step) {
    FocusScope.of(context).unfocus();
    setState(() {
      _step = step;
      _errors = const [];
    });
    _pages.animateToPage(step, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  Future<void> _next() async {
    final errors = _validateStep(_step);
    if (errors.isNotEmpty) {
      HapticFeedback.mediumImpact();
      setState(() => _errors = errors);
      return;
    }
    if (_step < _stepCount - 1) {
      _goTo(_step + 1);
      return;
    }
    setState(() => _saving = true);
    try {
      // A short minimum keeps the progress state from flashing.
      final results = await Future.wait([
        ref.read(tripActionsProvider).createTrip(_draft),
        Future<void>.delayed(const Duration(milliseconds: 700)),
      ]);
      if (mounted) context.pushReplacement(Routes.trip(results.first as String));
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, 'Could not create the trip: $e');
      }
    }
  }

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
        _errors = const [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final destinations = ref.watch(destinationsProvider);
    final theme = Theme.of(context);

    return Stack(
      children: [
        _wizard(destinations, theme),
        // Overlay keeps the wizard (and its page) alive if saving fails.
        if (_saving) const Positioned.fill(child: _BuildingView()),
      ],
    );
  }

  Widget _wizard(AsyncValue<List<Destination>> destinations, ThemeData theme) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close),
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.explore),
        ),
        title: Text(
          'Step ${_step + 1} of $_stepCount · ${_stepTitles[_step]}',
          style: theme.textTheme.titleSmall,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: (_step + 1) / _stepCount),
            duration: const Duration(milliseconds: 320),
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 4,
              backgroundColor: theme.colorScheme.surfaceContainer,
            ),
          ),
        ),
      ),
      body: AsyncValueView(
        value: destinations,
        onRetry: () => ref.invalidate(destinationsProvider),
        data: (dests) => PageView(
          controller: _pages,
          physics: const NeverScrollableScrollPhysics(),
          children: [_whereStep(dests), _whenStep(), _styleStep(), _reviewStep(dests)],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(Space.page, Space.md, Space.page, Space.md),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: _errors.isEmpty
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(bottom: Space.md),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
                            const SizedBox(width: Space.sm),
                            Expanded(
                              child: Text(
                                _errors.join('\n'),
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              Row(
                children: [
                  if (_step > 0) ...[
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(54, 54)),
                      onPressed: () => _goTo(_step - 1),
                      child: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: Space.md),
                  ],
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _next,
                      icon: Icon(_step == _stepCount - 1 ? Icons.auto_awesome : Icons.arrow_forward),
                      label: Text(_step == _stepCount - 1 ? 'Build my itinerary' : 'Continue'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepPage({required String title, String? subtitle, required List<Widget> children}) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.page, Space.xl, Space.page, Space.xxl),
      children: [
        Text(title, style: theme.textTheme.headlineMedium),
        if (subtitle != null) ...[
          const SizedBox(height: Space.xs),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: Space.xl),
        ...children,
      ],
    );
  }

  Widget _label(String text, {String? hint}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Space.xl, bottom: Space.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(text, style: theme.textTheme.titleMedium),
          if (hint != null) ...[
            const SizedBox(width: Space.sm),
            Expanded(
              child: Text(
                hint,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Step 1 ------------------------------------------------------------------

  Widget _whereStep(List<Destination> dests) => _stepPage(
    title: 'Where are you going?',
    subtitle: 'Pick one or more. We visit them in the order you choose.',
    children: [
      for (final d in dests)
        Padding(
          padding: const EdgeInsets.only(bottom: Space.md),
          child: _DestinationOption(
            destination: d,
            order: _draft.destinationIds.indexOf(d.id),
            onTap: () => setState(() {
              _errors = const [];
              _draft.destinationIds.contains(d.id)
                  ? _draft.destinationIds.remove(d.id)
                  : _draft.destinationIds.add(d.id);
            }),
          ),
        ),
      _label('Starting from'),
      TextField(
        controller: _origin,
        maxLength: 100,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          hintText: 'Airport, hotel or city',
          prefixIcon: Icon(Icons.flight_land_outlined),
          counterText: '',
        ),
        onChanged: (v) => setState(() {
          _draft.origin = v;
          _errors = const [];
        }),
      ),
      const SizedBox(height: Space.md),
      Wrap(
        spacing: Space.sm,
        runSpacing: Space.sm,
        children: [
          for (final s in const ['Da Nang Airport (DAD)', 'Da Nang city centre', 'Hoi An town'])
            SelectPill(
              label: s,
              selected: _draft.origin == s,
              onTap: () => setState(() {
                _draft.origin = s;
                _origin.text = s;
                _errors = const [];
              }),
            ),
        ],
      ),
    ],
  );

  // Step 2 ------------------------------------------------------------------

  Widget _whenStep() {
    final theme = Theme.of(context);
    final start = _draft.startDate;
    final end = _draft.endDate;
    final days = start == null || end == null ? null : end.difference(start).inDays + 1;
    return _stepPage(
      title: 'When & who?',
      subtitle: 'Trips can be up to ${TripDraft.maxDays} days.',
      children: [
        Semantics(
          button: true,
          label: start == null || end == null
              ? 'Choose travel dates'
              : 'Travel dates ${formatShortDate(start)} to ${formatShortDate(end)}, change',
          excludeSemantics: true,
          child: Pressable(
            onTap: _pickDates,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(Space.lg + 4),
                child: Row(
                  children: [
                    _DateBlock(label: 'Start', date: start),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.md),
                      child: Icon(Icons.arrow_forward, color: theme.colorScheme.outline),
                    ),
                    _DateBlock(label: 'End', date: end),
                    const Spacer(),
                    if (days != null)
                      InfoBadge(
                        label: '$days ${days == 1 ? 'day' : 'days'}',
                        color: theme.colorScheme.primary,
                      )
                    else
                      Icon(Icons.edit_calendar_outlined, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ),
          ),
        ),
        _label('Travelers'),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
            child: Row(
              children: [
                Icon(Icons.people_outline, color: theme.colorScheme.primary),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Text(
                    '${_draft.travelers} ${_draft.travelers == 1 ? 'traveler' : 'travelers'}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'Fewer travelers',
                  onPressed: _draft.travelers > 1 ? () => setState(() => _draft.travelers--) : null,
                  icon: const Icon(Icons.remove),
                ),
                const SizedBox(width: Space.sm),
                IconButton.filled(
                  tooltip: 'More travelers',
                  onPressed: _draft.travelers < TripDraft.maxTravelers
                      ? () => setState(() => _draft.travelers++)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
        ),
        _label('Budget', hint: 'Optional · total for the trip'),
        TextField(
          controller: _budget,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: 'e.g. 1,200',
            prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
            suffixText: _draft.currency,
          ),
          onChanged: (v) => setState(() {
            _draft.budgetText = v;
            _errors = const [];
          }),
        ),
        const SizedBox(height: Space.md),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final c in TripDraft.currencies)
              SelectPill(
                label: c,
                selected: _draft.currency == c,
                onTap: () => setState(() => _draft.currency = c),
              ),
          ],
        ),
      ],
    );
  }

  // Step 3 ------------------------------------------------------------------

  Widget _styleStep() => _stepPage(
    title: 'Your travel style',
    subtitle: 'We match places to what you enjoy.',
    children: [
      _label('Interests', hint: 'Choose any'),
      LayoutBuilder(
        builder: (context, c) {
          final w = (c.maxWidth - Space.md) / 2;
          return Wrap(
            spacing: Space.md,
            runSpacing: Space.md,
            children: [
              for (final i in Interest.values)
                SizedBox(
                  width: w,
                  child: _OptionTile(
                    icon: interestIcon(i),
                    label: i.label,
                    selected: _draft.interests.contains(i),
                    onTap: () => setState(() {
                      _draft.interests.contains(i) ? _draft.interests.remove(i) : _draft.interests.add(i);
                    }),
                  ),
                ),
            ],
          );
        },
      ),
      _label('Pace'),
      for (final p in Pace.values)
        Padding(
          padding: const EdgeInsets.only(bottom: Space.sm),
          child: _OptionTile(
            icon: switch (p) {
              Pace.relaxed => Icons.self_improvement,
              Pace.balanced => Icons.directions_walk,
              Pace.packed => Icons.directions_run,
            },
            label: p.label,
            description: p.description,
            selected: _draft.pace == p,
            radio: true,
            onTap: () => setState(() => _draft.pace = p),
          ),
        ),
      _label('Getting around'),
      Wrap(
        spacing: Space.sm,
        runSpacing: Space.sm,
        children: [
          for (final m in TransportMode.values)
            SelectPill(
              label: m.label,
              icon: transportIcon(m),
              selected: _draft.transport == m,
              onTap: () => setState(() => _draft.transport = m),
            ),
        ],
      ),
    ],
  );

  // Step 4 ------------------------------------------------------------------

  Widget _reviewStep(List<Destination> dests) {
    final theme = Theme.of(context);
    final names = {for (final d in dests) d.id: d.name};
    final route = _draft.destinationIds.map((id) => names[id] ?? id).join(' → ');
    final start = _draft.startDate;
    final end = _draft.endDate;
    final budget = _draft.budget;

    Widget row(IconData icon, String label, String value, int step) => ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      subtitle: Text(value, style: theme.textTheme.titleSmall?.copyWith(fontSize: 15)),
      trailing: TextButton(onPressed: () => _goTo(step), child: const Text('Edit')),
    );

    return _stepPage(
      title: 'Ready to go?',
      subtitle: 'Check the details, then we build your plan.',
      children: [
        TextField(
          controller: _title,
          maxLength: 80,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Trip name',
            hintText: route.isEmpty ? 'My Vietnam trip' : 'Trip to ${route.replaceAll(' → ', ' & ')}',
            prefixIcon: const Icon(Icons.edit_outlined),
            counterText: '',
          ),
          onChanged: (v) => _draft.title = v,
        ),
        const SizedBox(height: Space.lg),
        Card(
          child: Column(
            children: [
              row(Icons.route_outlined, 'Route', route.isEmpty ? '—' : route, 0),
              row(
                Icons.flight_land_outlined,
                'Starting from',
                _draft.origin.isEmpty ? '—' : _draft.origin,
                0,
              ),
              row(
                Icons.calendar_today_outlined,
                'Dates',
                start == null || end == null
                    ? '—'
                    : '${formatShortDate(start)} – ${formatShortDate(end)} · ${end.difference(start).inDays + 1} days',
                1,
              ),
              row(Icons.people_outline, 'Travelers', '${_draft.travelers}', 1),
              row(
                Icons.account_balance_wallet_outlined,
                'Budget',
                budget == null ? 'Not set' : '${budget.toStringAsFixed(0)} ${_draft.currency}',
                1,
              ),
              row(
                Icons.interests_outlined,
                'Interests',
                _draft.interests.isEmpty ? 'Anything' : _draft.interests.map((i) => i.label).join(', '),
                2,
              ),
              row(
                Icons.speed,
                'Pace · Getting around',
                '${_draft.pace.label} · ${_draft.transport.label}',
                2,
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.lg),
        Text(
          'Your plan uses our curated places. Times and travel are estimates; '
          'opening hours and prices are not verified.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _DestinationOption extends StatelessWidget {
  const _DestinationOption({required this.destination, required this.order, required this.onTap});

  final Destination destination;

  /// Position in the visit order, or -1 when not selected.
  final int order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = order >= 0;
    return Semantics(
      button: true,
      selected: selected,
      label: destination.name,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(Space.sm + 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(
              color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.md),
                child: SizedBox(width: 92, height: 92, child: SceneArtwork(destinationId: destination.id)),
              ),
              const SizedBox(width: Space.md + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(destination.name, style: theme.textTheme.titleMedium),
                    if (destination.localName != null)
                      Text(
                        destination.localName!,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: Space.xs),
                    Text(
                      destination.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.sm),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? theme.colorScheme.primary : Colors.transparent,
                  border: Border.all(color: selected ? theme.colorScheme.primary : theme.colorScheme.outline),
                ),
                child: selected
                    ? Text(
                        '${order + 1}',
                        style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onPrimary),
                      )
                    : null,
              ),
              const SizedBox(width: Space.xs),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.description,
    this.radio = false,
  });

  final IconData icon;
  final String label;
  final String? description;
  final bool selected;
  final bool radio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md + 2),
          decoration: BoxDecoration(
            color: selected ? scheme.primary.withValues(alpha: 0.08) : scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? scheme.primary : scheme.onSurfaceVariant),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.titleSmall),
                    if (description != null)
                      Text(
                        description!,
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              if (radio)
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: selected ? scheme.primary : scheme.outline,
                )
              else if (selected)
                Icon(Icons.check_circle, color: scheme.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.label, required this.date});

  final String label;
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text(
          date == null ? 'Add date' : formatShortDate(date!),
          style: theme.textTheme.titleMedium?.copyWith(
            color: date == null ? theme.colorScheme.primary : theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

/// Shown while the itinerary is generated and saved.
class _BuildingView extends StatelessWidget {
  const _BuildingView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(strokeWidth: 5, color: theme.colorScheme.secondary),
              ),
              const SizedBox(height: Space.xl),
              Text('Building your itinerary', style: theme.textTheme.titleLarge),
              const SizedBox(height: Space.sm),
              Text(
                'Grouping nearby places and balancing each day…',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
