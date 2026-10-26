class AffiliateOffer {
  const AffiliateOffer({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.destinationId,
    this.placeId,
    required this.title,
    this.imageUrl,
    this.priceAmount,
    this.priceCurrency,
    required this.bookingUrl,
    required this.isMock,
    required this.fetchedAt,
    required this.expiresAt,
  });

  final String id;
  final String providerId;
  final String providerName;
  final String destinationId;
  final String? placeId;
  final String title;
  final String? imageUrl;

  /// Only set when the partner supplied a price. Never estimated by the app.
  final double? priceAmount;
  final String? priceCurrency;

  /// Exactly as supplied by the partner. The app must not edit its parameters.
  final String bookingUrl;

  /// True for development sample data that does not come from a partner.
  final bool isMock;
  final DateTime fetchedAt;
  final DateTime expiresAt;

  factory AffiliateOffer.fromMap(Map<String, Object?> map) => AffiliateOffer(
        id: map['id'] as String,
        providerId: map['provider_id'] as String,
        providerName: map['provider_name'] as String,
        destinationId: map['destination_id'] as String,
        placeId: map['place_id'] as String?,
        title: map['title'] as String,
        imageUrl: map['image_url'] as String?,
        priceAmount: (map['price_amount'] as num?)?.toDouble(),
        priceCurrency: map['price_currency'] as String?,
        bookingUrl: map['booking_url'] as String,
        isMock: (map['is_mock'] as num) == 1,
        fetchedAt: DateTime.parse(map['fetched_at'] as String),
        expiresAt: DateTime.parse(map['expires_at'] as String),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'provider_id': providerId,
        'provider_name': providerName,
        'destination_id': destinationId,
        'place_id': placeId,
        'title': title,
        'image_url': imageUrl,
        'price_amount': priceAmount,
        'price_currency': priceCurrency,
        'booking_url': bookingUrl,
        'is_mock': isMock ? 1 : 0,
        'fetched_at': fetchedAt.toUtc().toIso8601String(),
        'expires_at': expiresAt.toUtc().toIso8601String(),
      };
}
