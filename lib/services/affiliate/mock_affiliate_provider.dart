import '../../models/affiliate_offer.dart';
import 'affiliate_provider.dart';

/// MOCK DATA for building the UI before any partner grants API access.
///
/// - Titles are generic placeholders, not real products.
/// - No prices: the app never invents prices.
/// - Links are plain Viator search pages with no affiliate or tracking
///   parameters, so no commission is earned from them.
class MockAffiliateProvider implements AffiliateProvider {
  const MockAffiliateProvider();

  @override
  String get id => 'mock';

  @override
  String get displayName => 'Sample data (no partner connected)';

  @override
  bool get isMock => true;

  @override
  Duration get cacheTtl => const Duration(days: 1);

  @override
  Set<String> get allowedHosts => const {'viator.com'};

  static const _samples = <String, List<(String, String, String?)>>{
    'da_nang': [
      ('Sample: Marble Mountains half-day tour', 'Marble Mountains Da Nang', 'dn_marble_mountains'),
      ('Sample: Ba Na Hills day trip', 'Ba Na Hills', 'dn_ba_na_hills'),
      ('Sample: Da Nang street food evening', 'Da Nang food tour', null),
      ('Sample: Hai Van Pass motorbike tour', 'Hai Van Pass', 'dn_hai_van_pass'),
    ],
    'hoi_an': [
      ('Sample: Hoi An cooking class', 'Hoi An cooking class', null),
      ('Sample: Basket boat ride in Cam Thanh', 'Cam Thanh basket boat', 'ha_cam_thanh_coconut'),
      ('Sample: My Son Sanctuary morning trip', 'My Son Sanctuary', 'ha_my_son'),
      ('Sample: Hoi An lantern-making workshop', 'Hoi An lantern making', null),
    ],
  };

  @override
  Future<List<AffiliateOffer>> fetchOffers({required String destinationId}) async {
    final now = DateTime.now().toUtc();
    final samples = _samples[destinationId] ?? const [];
    return [
      for (var i = 0; i < samples.length; i++)
        AffiliateOffer(
          id: '${destinationId}_$i',
          providerId: id,
          providerName: displayName,
          destinationId: destinationId,
          placeId: samples[i].$3,
          title: samples[i].$1,
          bookingUrl: Uri.https('www.viator.com', '/searchResults/all',
              {'text': samples[i].$2}).toString(),
          isMock: true,
          fetchedAt: now,
          expiresAt: now.add(cacheTtl),
        ),
    ];
  }
}
