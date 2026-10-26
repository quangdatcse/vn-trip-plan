import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/affiliate_offer.dart';
import '../../services/affiliate/affiliate_provider.dart';

class OffersResult {
  const OffersResult({required this.offers, this.fromCache = false, this.error});

  final List<AffiliateOffer> offers;

  /// True when the provider failed and unexpired cached offers are shown.
  final bool fromCache;
  final Object? error;
}

/// Fetches offers from the provider and caches them in `affiliate_offers`
/// for offline use, within the provider's [AffiliateProvider.cacheTtl].
class OffersRepository {
  OffersRepository(this._db, this._provider);

  final Database _db;
  final AffiliateProvider _provider;

  AffiliateProvider get provider => _provider;

  Future<OffersResult> offersFor(String destinationId) async {
    try {
      final offers = await _provider
          .fetchOffers(destinationId: destinationId)
          .timeout(const Duration(seconds: 15));
      await _store(destinationId, offers);
      return OffersResult(offers: offers);
    } catch (e) {
      debugPrint('Affiliate fetch failed: $e');
      return OffersResult(offers: await _cached(destinationId), fromCache: true, error: e);
    }
  }

  Future<void> _store(String destinationId, List<AffiliateOffer> offers) async {
    await _db.transaction((txn) async {
      await txn.delete('affiliate_offers',
          where: 'provider_id = ? AND destination_id = ?',
          whereArgs: [_provider.id, destinationId]);
      for (final offer in offers) {
        await txn.insert('affiliate_offers', offer.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<AffiliateOffer>> _cached(String destinationId) async {
    final rows = await _db.query('affiliate_offers',
        where: 'provider_id = ? AND destination_id = ? AND expires_at > ?',
        whereArgs: [
          _provider.id,
          destinationId,
          DateTime.now().toUtc().toIso8601String(),
        ]);
    return rows.map(AffiliateOffer.fromMap).toList();
  }
}
