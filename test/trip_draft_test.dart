import 'package:flutter_test/flutter_test.dart';
import 'package:vietnam_tripmate/models/trip.dart';
import 'package:vietnam_tripmate/services/affiliate/affiliate_provider.dart';
import 'package:vietnam_tripmate/services/itinerary/travel_estimator.dart';
import 'package:vietnam_tripmate/models/enums.dart';

import 'helpers.dart';

TripDraft validDraft() => TripDraft()
  ..origin = 'Da Nang Airport'
  ..destinationIds = ['da_nang']
  ..startDate = DateTime.utc(2026, 11, 2)
  ..endDate = DateTime.utc(2026, 11, 4);

void main() {
  group('TripDraft.validate', () {
    test('accepts a complete draft', () {
      expect(validDraft().validate(), isEmpty);
    });

    test('requires origin, destination and dates', () {
      final errors = TripDraft().validate();
      expect(errors, contains('Enter where you are starting from.'));
      expect(errors, contains('Choose at least one destination.'));
      expect(errors, contains('Choose your travel dates.'));
    });

    test('rejects end before start and overly long trips', () {
      final reversed = validDraft()..endDate = DateTime.utc(2026, 11, 1);
      expect(reversed.validate(), contains('End date must be on or after the start date.'));
      final long = validDraft()..endDate = DateTime.utc(2026, 12, 31);
      expect(long.validate(), contains('Trips can be at most 30 days.'));
    });

    test('rejects invalid budgets but allows an empty one', () {
      expect((validDraft()..budgetText = 'abc').validate(),
          contains('Budget must be a positive number.'));
      expect((validDraft()..budgetText = '-5').validate(),
          contains('Budget must be a positive number.'));
      expect((validDraft()..budgetText = '1,500').validate(), isEmpty);
      expect((validDraft()..budgetText = '').validate(), isEmpty);
    });

    test('toTrip trims text and uses the fallback title', () {
      final t = (validDraft()..origin = '  Hotel  ')
          .toTrip(id: 'x', now: DateTime.utc(2026), fallbackTitle: 'Trip to Da Nang');
      expect(t.origin, 'Hotel');
      expect(t.title, 'Trip to Da Nang');
      expect(t.dayCount, 3);
    });
  });

  group('TravelEstimator', () {
    const estimator = TravelEstimator();

    test('is at least 5 minutes and rounded to 5', () {
      final a = place('a', lat: 16.0, lng: 108.0);
      final est = estimator.estimate(a, a, TransportMode.walking);
      expect(est.minutes, 5);
      final b = place('b', lat: 16.05, lng: 108.0);
      expect(estimator.estimate(a, b, TransportMode.taxi).minutes % 5, 0);
    });

    test('walking is slower than a taxi over the same distance', () {
      final a = place('a', lat: 16.00, lng: 108.20);
      final b = place('b', lat: 16.03, lng: 108.22);
      expect(estimator.estimate(a, b, TransportMode.walking).minutes,
          greaterThan(estimator.estimate(a, b, TransportMode.taxi).minutes));
    });
  });

  group('validatedBookingUri', () {
    const hosts = {'viator.com'};

    test('accepts https links on an allowed host and keeps them unchanged', () {
      const url = 'https://www.viator.com/tours/x?pid=P1&mcid=42';
      expect(validatedBookingUri(url, hosts).toString(), url);
    });

    test('rejects other hosts, http and look-alike domains', () {
      expect(validatedBookingUri('https://example.com/x', hosts), isNull);
      expect(validatedBookingUri('http://www.viator.com/x', hosts), isNull);
      expect(validatedBookingUri('https://viator.com.evil.io/x', hosts), isNull);
    });
  });
}
