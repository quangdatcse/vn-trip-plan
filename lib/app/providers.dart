import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../core/utils/ids.dart';
import '../data/repositories/catalog_repository.dart';
import '../data/repositories/offers_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/trip_repository.dart';
import '../models/destination.dart';
import '../models/itinerary.dart';
import '../models/place.dart';
import '../models/trip.dart';
import '../services/affiliate/affiliate_provider.dart';
import '../services/affiliate/mock_affiliate_provider.dart';
import '../services/analytics/deal_click_counter.dart';
import '../services/itinerary/itinerary_planner.dart';
import '../services/maps/maps_launcher.dart';

/// Opened in `main()` and injected with `overrideWithValue`.
final databaseProvider = Provider<Database>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final catalogRepositoryProvider =
    Provider((ref) => CatalogRepository(ref.watch(databaseProvider)));
final tripRepositoryProvider =
    Provider((ref) => TripRepository(ref.watch(databaseProvider)));
final settingsRepositoryProvider =
    Provider((ref) => SettingsRepository(ref.watch(databaseProvider)));

/// Swap for a real partner adapter once API access is approved.
final affiliateProviderProvider =
    Provider<AffiliateProvider>((ref) => const MockAffiliateProvider());
final offersRepositoryProvider = Provider(
  (ref) => OffersRepository(ref.watch(databaseProvider), ref.watch(affiliateProviderProvider)),
);

final plannerProvider = Provider((ref) => ItineraryPlanner(newId: newId));
final mapsLauncherProvider = Provider((ref) => const MapsLauncher());
final dealClickCounterProvider =
    Provider((ref) => DealClickCounter(ref.watch(settingsRepositoryProvider)));

final destinationsProvider = FutureProvider<List<Destination>>(
  (ref) => ref.watch(catalogRepositoryProvider).getDestinations(),
);

final allPlacesProvider = FutureProvider<List<Place>>(
  (ref) => ref.watch(catalogRepositoryProvider).getPlaces(),
);

final placesByDestinationProvider = FutureProvider.family<List<Place>, String>(
  (ref, destinationId) async => (await ref.watch(allPlacesProvider.future))
      .where((p) => p.destinationId == destinationId)
      .toList(),
);

final placeProvider = FutureProvider.family<Place?, String>(
  (ref, id) => ref.watch(catalogRepositoryProvider).getPlace(id),
);

final tripsProvider = FutureProvider<List<Trip>>(
  (ref) => ref.watch(tripRepositoryProvider).listTrips(),
);

final tripPlanProvider = FutureProvider.autoDispose.family<TripPlan?, String>(
  (ref, tripId) => ref.watch(tripRepositoryProvider).getPlan(tripId),
);

final offersProvider = FutureProvider.autoDispose.family<OffersResult, String>(
  (ref, destinationId) => ref.watch(offersRepositoryProvider).offersFor(destinationId),
);

final dealClickCountingProvider = FutureProvider<bool>(
  (ref) => ref
      .watch(settingsRepositoryProvider)
      .getBool(SettingsRepository.dealClickCountingKey),
);
