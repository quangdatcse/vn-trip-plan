import 'dart:io';

import 'package:flutter/widgets.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vietnam_tripmate/app/app.dart';
import 'package:vietnam_tripmate/app/providers.dart';
import 'package:vietnam_tripmate/data/local/app_database.dart';
import 'package:vietnam_tripmate/data/sources/catalog_seeder.dart';

void main() {
  sqfliteFfiInit();

  testWidgets('Home screen shows the app name and Create a Trip', (tester) async {
    // Tall phone-sized viewport so the "Your trips" section is built.
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Database work uses real I/O, so it runs outside the fake-async zone.
    final db = (await tester.runAsync(() async {
      final db = await AppDatabase.openWith(databaseFactoryFfiNoIsolate, inMemoryDatabasePath);
      await CatalogSeeder(db, (path) => File(path).readAsString()).seedIfNeeded();
      return db;
    }))!;
    addTearDown(() => tester.runAsync(db.close));

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const TripMateApp(),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }

    expect(find.text('Vietnam TripMate'), findsWidgets);
    expect(find.text('Create a Trip'), findsOneWidget);
    expect(find.text('Da Nang'), findsOneWidget);
    expect(find.text('No trips yet'), findsOneWidget);
  });
}
