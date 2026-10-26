import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/tokens.dart';
import '../../data/repositories/settings_repository.dart';
import '../../shared/widgets/state_views.dart';
import '../affiliate_offers/offers_screen.dart';
import '../itinerary/trip_actions.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const appVersion = '0.2.0 (MVP)';

  Future<void> _deleteAll(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all data?'),
        content: const Text('All trips and saved places will be removed from this device. '
            'This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(tripActionsProvider).deleteAllData();
    await ref.read(settingsRepositoryProvider).remove(SettingsRepository.dealClickCountKey);
    if (context.mounted) showSnack(context, 'All data deleted.');
  }

  void _showText(BuildContext context, String title, String text) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: Space.md),
              Text(text, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counting = ref.watch(dealClickCountingProvider);
    final themeMode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), toolbarHeight: 64),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.xxl),
        children: [
          _Group(title: 'Appearance', children: [
            Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto_outlined)),
                    ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
                  ],
                  selected: {themeMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.first),
                ),
              ),
            ),
          ]),
          _Group(title: 'Privacy & data', children: [
            const ListTile(
              leading: Icon(Icons.phone_iphone_outlined),
              title: Text('Stored on this device'),
              subtitle: Text('No account. Trips and saved places never leave your phone.'),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.touch_app_outlined),
              title: const Text('Count deal clicks'),
              subtitle: const Text('Local count of "View Deal" taps. Nothing is sent.'),
              value: counting.value ?? false,
              onChanged: counting.isLoading
                  ? null
                  : (on) async {
                      await ref
                          .read(settingsRepositoryProvider)
                          .setBool(SettingsRepository.dealClickCountingKey, on);
                      ref.invalidate(dealClickCountingProvider);
                    },
            ),
            ListTile(
              leading: Icon(Icons.delete_forever_outlined, color: theme.colorScheme.error),
              title: Text('Delete all data', style: TextStyle(color: theme.colorScheme.error)),
              subtitle: const Text('Trips and saved places'),
              onTap: () => _deleteAll(context, ref),
            ),
          ]),
          _Group(title: 'About', children: [
            ListTile(
              leading: const Icon(Icons.handshake_outlined),
              title: const Text('Affiliate disclosure'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showText(context, 'Affiliate disclosure', affiliateDisclosure),
            ),
            ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: const Text('About place information'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showText(
                context,
                'About place information',
                'Places are curated by the TripMate team. Each place shows its source and '
                    'verification status. Opening hours, prices and travel times are not '
                    'guaranteed; always check locally before you go.',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.replay_outlined),
              title: const Text('Show welcome screens'),
              onTap: () async {
                await ref.read(onboardingDoneProvider.notifier).setDone(false);
                if (context.mounted) context.go(Routes.onboarding);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Version'),
              trailing: Text(appVersion, style: theme.textTheme.bodySmall),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.xs, Space.xl, 0, Space.sm),
          child: Text(title.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
        Card(child: Column(children: children)),
      ],
    );
  }
}
