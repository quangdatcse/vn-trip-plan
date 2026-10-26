import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vietnam_tripmate/data/local/app_database.dart';
import 'package:vietnam_tripmate/data/repositories/catalog_repository.dart';
import 'package:vietnam_tripmate/data/repositories/trip_repository.dart';
import 'package:vietnam_tripmate/data/sources/catalog_seeder.dart';
import 'package:vietnam_tripmate/models/enums.dart';
import 'package:vietnam_tripmate/models/itinerary.dart';
import 'package:vietnam_tripmate/services/itinerary/itinerary_planner.dart';

import 'helpers.dart';

void main() {
  sqfliteFfiInit();
  late Database db;

  setUp(() async {
    db = await AppDatabase.openWith(databaseFactoryFfiNoIsolate, inMemoryDatabasePath);
    await CatalogSeeder(db, (path) => File(path).readAsString()).seedIfNeeded();
  });
  tearDown(() => db.close());

  test('seeds the bundled catalog once', () async {
    final catalog = CatalogRepository(db);
    final count = (await catalog.getPlaces()).length;
    expect(count, greaterThan(10));
    expect((await catalog.getDestinations()).map((d) => d.id), ['da_nang', 'hoi_an']);

    await CatalogSeeder(db, (path) => File(path).readAsString()).seedIfNeeded();
    expect((await catalog.getPlaces()).length, count);
  });

  test('every catalog place has a source and a positive duration', () async {
    for (final p in await CatalogRepository(db).getPlaces()) {
      expect(p.source, isNotEmpty, reason: p.id);
      expect(p.suggestedDurationMinutes, greaterThan(0), reason: p.id);
    }
  });

  test('saves, reloads, edits and deletes a generated trip', () async {
    final repo = TripRepository(db);
    final catalog = await CatalogRepository(db).getPlaces();
    final t = trip(days: 3, destinations: ['da_nang', 'hoi_an'], interests: {Interest.culture});
    final plan = TripPlan(
      trip: t,
      days: ItineraryPlanner(newId: sequentialIds()).generate(t, catalog),
    );

    await repo.savePlan(plan);
    final loaded = (await repo.getPlan(t.id))!;
    expect(loaded.trip.destinationIds, ['da_nang', 'hoi_an']);
    expect(loaded.trip.interests, {Interest.culture});
    expect(loaded.days, hasLength(3));
    expect(loaded.placeIds, plan.placeIds);

    // Saving again replaces the itinerary rather than duplicating it.
    final firstDay = loaded.days.first;
    await repo.savePlan(loaded.replaceDay(firstDay.withItems(const [])));
    final edited = (await repo.getPlan(t.id))!;
    expect(edited.days.first.items, isEmpty);
    expect(edited.days, hasLength(3));

    await repo.deleteTrip(t.id);
    expect(await repo.getPlan(t.id), isNull);
    final orphans = await db.rawQuery('SELECT COUNT(*) AS n FROM itinerary_items');
    expect(orphans.first['n'], 0);
  });
}
