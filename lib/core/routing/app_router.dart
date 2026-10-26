import 'package:go_router/go_router.dart';

import '../../features/affiliate_offers/offers_screen.dart';
import '../../features/create_trip/create_trip_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/itinerary/itinerary_screen.dart';
import '../../features/places/place_detail_screen.dart';
import '../../features/places/places_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/trip_map/trip_map_screen.dart';

class Routes {
  const Routes._();

  static const home = '/';
  static const createTrip = '/create';
  static const settings = '/settings';
  static String trip(String id) => '/trip/$id';
  static String tripMap(String id) => '/trip/$id/map';
  static String destination(String id) => '/destination/$id';
  static String place(String id) => '/place/$id';
  static String offers(String destinationId) => '/offers/$destinationId';
}

final appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/create', builder: (context, state) => const CreateTripScreen()),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    GoRoute(
      path: '/trip/:id',
      builder: (context, state) => ItineraryScreen(tripId: state.pathParameters['id']!),
      routes: [
        GoRoute(
          path: 'map',
          builder: (context, state) => TripMapScreen(tripId: state.pathParameters['id']!),
        ),
      ],
    ),
    GoRoute(
      path: '/destination/:id',
      builder: (context, state) =>
          PlacesScreen(destinationId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/place/:id',
      builder: (context, state) => PlaceDetailScreen(placeId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/offers/:destinationId',
      builder: (context, state) =>
          OffersScreen(destinationId: state.pathParameters['destinationId']!),
    ),
  ],
);
