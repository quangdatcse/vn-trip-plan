import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/tokens.dart';
import '../../models/enums.dart';
import '../../models/place.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/ui.dart';
import 'explore_screen.dart';

/// Case- and accent-insensitive match on name, local name, area and category.
bool placeMatches(Place p, String query) {
  final q = foldVietnamese(query.trim().toLowerCase());
  if (q.isEmpty) return true;
  final haystack = foldVietnamese(
      [p.nameEn, p.nameLocal ?? '', p.area, p.category.label].join(' ').toLowerCase());
  return q.split(RegExp(r'\s+')).every(haystack.contains);
}

/// Strips Vietnamese diacritics so "cho han" finds "Chợ Hàn".
String foldVietnamese(String s) {
  const groups = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };
  final buffer = StringBuffer();
  for (final ch in s.split('')) {
    var out = ch;
    for (final entry in groups.entries) {
      if (entry.value.contains(ch)) {
        out = entry.key;
        break;
      }
    }
    buffer.write(out);
  }
  return buffer.toString();
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialInterest});

  final Interest? initialInterest;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  late Interest? _interest = widget.initialInterest;
  String? _destinationId;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final places = ref.watch(allPlacesProvider);
    final destinations = ref.watch(destinationsProvider).value ?? const [];
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.explore),
        ),
        title: Padding(
          padding: const EdgeInsets.only(right: Space.lg),
          child: TextField(
            controller: _controller,
            autofocus: widget.initialInterest == null,
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search places',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(_controller.clear),
                    ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.pill),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.pill),
                borderSide: BorderSide.none,
              ),
              fillColor: theme.colorScheme.surfaceContainer,
            ),
          ),
        ),
      ),
      body: AsyncValueView(
        value: places,
        onRetry: () => ref.invalidate(allPlacesProvider),
        data: (all) {
          final results = all
              .where((p) => _interest == null || p.interests.contains(_interest))
              .where((p) => _destinationId == null || p.destinationId == _destinationId)
              .where((p) => placeMatches(p, _controller.text))
              .toList();
          return ListView(
            padding: const EdgeInsets.only(bottom: Space.xxl),
            children: [
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Space.page, vertical: Space.sm),
                  children: [
                    for (final d in destinations)
                      Padding(
                        padding: const EdgeInsets.only(right: Space.sm),
                        child: SelectPill(
                          label: d.name,
                          icon: Icons.location_city_outlined,
                          selected: _destinationId == d.id,
                          onTap: () => setState(
                              () => _destinationId = _destinationId == d.id ? null : d.id),
                        ),
                      ),
                    for (final i in Interest.values)
                      Padding(
                        padding: const EdgeInsets.only(right: Space.sm),
                        child: SelectPill(
                          label: i.label,
                          icon: interestIcon(i),
                          selected: _interest == i,
                          onTap: () => setState(() => _interest = _interest == i ? null : i),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.page, Space.md, Space.page, Space.sm),
                child: Text('${results.length} ${results.length == 1 ? 'place' : 'places'}',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
              if (results.isEmpty)
                const MessageView(
                  icon: Icons.travel_explore,
                  title: 'No places found',
                  message: 'Try another word or remove a filter.',
                ),
              for (final p in results) PlaceRow(place: p),
            ],
          );
        },
      ),
    );
  }
}
