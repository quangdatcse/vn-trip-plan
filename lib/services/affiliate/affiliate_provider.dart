import '../../models/affiliate_offer.dart';

/// Contract for a tours/tickets partner (e.g. Viator once API access is
/// granted). Implementations must return partner data unchanged: no
/// invented products or prices, and booking URLs exactly as supplied.
abstract interface class AffiliateProvider {
  String get id;
  String get displayName;

  /// True when the data is development sample data, not from a partner.
  bool get isMock;

  /// How long results may be cached. Must follow the partner's caching policy.
  Duration get cacheTtl;

  /// Hosts allowed for booking links from this provider.
  Set<String> get allowedHosts;

  Future<List<AffiliateOffer>> fetchOffers({required String destinationId});
}

/// Rejects anything that is not an https link to one of [allowedHosts].
/// The URL itself is never modified.
Uri? validatedBookingUri(String url, Set<String> allowedHosts) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') return null;
  final host = uri.host.toLowerCase();
  final allowed = allowedHosts.any((h) => host == h || host.endsWith('.$h'));
  return allowed ? uri : null;
}
