import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../models/affiliate_offer.dart';
import '../../services/affiliate/affiliate_provider.dart';
import '../../services/maps/maps_launcher.dart';
import '../../shared/widgets/state_views.dart';

const affiliateDisclosure =
    'Some links are affiliate links. If you book through them, Vietnam TripMate may '
    'earn a commission at no extra cost to you. Bookings, prices and availability are '
    'handled by the partner website.';

class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key, required this.destinationId});

  final String destinationId;

  Future<void> _openDeal(BuildContext context, WidgetRef ref, AffiliateOffer offer) async {
    final provider = ref.read(affiliateProviderProvider);
    final uri = validatedBookingUri(offer.bookingUrl, provider.allowedHosts);
    if (uri == null) {
      showSnack(context, 'This link is not valid and was not opened.');
      return;
    }
    await ref.read(dealClickCounterProvider).record(offer);
    if (!await openExternal(uri) && context.mounted) {
      showSnack(context, 'Could not open the partner website.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(offersProvider(destinationId));
    final provider = ref.watch(affiliateProviderProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Tours & tickets')),
      body: AsyncValueView(
        value: result,
        onRetry: () => ref.invalidate(offersProvider(destinationId)),
        data: (r) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Card(
              color: theme.colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(affiliateDisclosure,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSecondaryContainer)),
              ),
            ),
            if (provider.isMock)
              Card(
                color: theme.colorScheme.tertiaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'MOCK DATA: no partner is connected yet. These cards are samples for '
                    'testing the layout, not real products. Links open a plain partner '
                    'search page without affiliate tracking.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onTertiaryContainer),
                  ),
                ),
              ),
            if (r.fromCache)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  r.offers.isEmpty
                      ? 'Offers could not be loaded. Check your connection and try again.'
                      : 'Showing saved offers because the latest could not be loaded.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            if (r.offers.isEmpty && !r.fromCache)
              const MessageView(
                icon: Icons.local_activity_outlined,
                title: 'No offers for this destination yet',
              ),
            for (final offer in r.offers)
              _OfferCard(offer: offer, onViewDeal: () => _openDeal(context, ref, offer)),
          ],
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer, required this.onViewDeal});

  final AffiliateOffer offer;
  final VoidCallback onViewDeal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = offer.priceAmount == null
        ? 'Price shown on partner site'
        : 'From ${offer.priceAmount!.toStringAsFixed(2)} ${offer.priceCurrency ?? ''}';
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 7,
            child: offer.imageUrl == null
                ? ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(Icons.local_activity_outlined,
                        size: 40, color: theme.colorScheme.outline),
                  )
                : Image.network(
                    offer.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (offer.isMock)
                  Text('MOCK', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.tertiary)),
                Text(offer.title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('${offer.providerName} · $price', style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: onViewDeal,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('View Deal'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
