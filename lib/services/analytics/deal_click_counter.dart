import '../../data/repositories/settings_repository.dart';
import '../../models/affiliate_offer.dart';

/// Counts "View Deal" taps on this device only, and only when the user has
/// switched it on in Settings. Nothing is sent anywhere.
class DealClickCounter {
  DealClickCounter(this._settings);

  final SettingsRepository _settings;

  Future<void> record(AffiliateOffer offer) async {
    final enabled = await _settings.getBool(SettingsRepository.dealClickCountingKey);
    if (!enabled) return;
    final current =
        int.tryParse(await _settings.get(SettingsRepository.dealClickCountKey) ?? '') ?? 0;
    await _settings.set(SettingsRepository.dealClickCountKey, '${current + 1}');
  }
}
