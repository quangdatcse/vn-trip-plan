import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../features/affiliate_offers/offers_screen.dart';
import '../../features/create_trip/create_trip_screen.dart';
import '../../features/explore/explore_screen.dart';
import '../../features/explore/search_screen.dart';
import '../../features/itinerary/itinerary_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/places/place_detail_screen.dart';
import '../../features/places/places_screen.dart';
import '../../features/saved/saved_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/trip_map/trip_map_screen.dart';
import '../../features/trips/trips_screen.dart';
import '../../models/enums.dart';

class Routes {
  const Routes._();

  static const explore = '/';
  static const trips = '/trips';
  static const saved = '/saved';
  static const settings = '/settings';
  static const onboarding = '/welcome';
  static String createTrip({String? destinationId}) =>
      destinationId == null ? '/create' : '/create?dest=$destinationId';
  static String search({Interest? interest}) =>
      interest == null ? '/search' : '/search?interest=${interest.name}';
  static String trip(String id) => '/trip/$id';
  static String tripMap(String id) => '/trip/$id/map';
  static String destination(String id) => '/destination/$id';
  static String place(String id) => '/place/$id';
  static String offers(String destinationId) => '/offers/$destinationId';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    redirect: (context, state) {
      final done = ref.read(onboardingDoneProvider);
      final atWelcome = state.matchedLocation == Routes.onboarding;
      if (!done && !atWelcome) return Routes.onboarding;
      if (done && atWelcome) return Routes.explore;
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (context, state) => const ExploreScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/trips', builder: (context, state) => const TripsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/saved', builder: (context, state) => const SavedScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
          ]),
        ],
      ),
      GoRoute(path: '/welcome', builder: (context, state) => const OnboardingScreen()),
      GoRoute(
        path: '/create',
        builder: (context, state) =>
            CreateTripScreen(initialDestinationId: state.uri.queryParameters['dest']),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => SearchScreen(
          initialInterest: Interest.values.asNameMap()[state.uri.queryParameters['interest']],
        ),
      ),
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
});
