import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/repositories/settings_repository.dart';
import '../../shared/widgets/state_views.dart';
import '../affiliate_offers/offers_screen.dart';
import '../itinerary/trip_actions.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const appVersion = '0.1.0 (MVP)';

  Future<void> _deleteAll(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all trips?'),
        content: const Text('All saved trips and itineraries will be removed from this device. '
            'This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete all')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(tripActionsProvider).deleteAllTrips();
    final settings = ref.read(settingsRepositoryProvider);
    await settings.remove(SettingsRepository.dealClickCountKey);
    if (context.mounted) showSnack(context, 'All trips deleted.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counting = ref.watch(dealClickCountingProvider);
    final theme = Theme.of(context);

    Widget section(String title) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        );
    Widget body(String text) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(text, style: theme.textTheme.bodyMedium),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          section('Your data'),
          body('No account is needed. Your trips are stored only on this device and are '
              'not uploaded anywhere.'),
          SwitchListTile(
            title: const Text('Count deal clicks on this device'),
            subtitle: const Text('Keeps a local count of "View Deal" taps. Nothing is sent.'),
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
            title: const Text('Delete all trips'),
            subtitle: const Text('Removes every saved trip from this device'),
            onTap: () => _deleteAll(context, ref),
          ),
          section('Affiliate disclosure'),
          body(affiliateDisclosure),
          section('About place information'),
          body('Places are curated by the TripMate team. Each place shows its source and '
              'verification status. Opening hours, prices and travel times are not '
              'guaranteed; always check locally.'),
          section('About'),
          body('Vietnam TripMate $appVersion'),
        ],
      ),
    );
  }
}
