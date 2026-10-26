import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vietnam_tripmate/app/app.dart';
import 'package:vietnam_tripmate/app/providers.dart';
import 'package:vietnam_tripmate/data/local/app_database.dart';
import 'package:vietnam_tripmate/data/sources/catalog_seeder.dart';

void main() {
  sqfliteFfiInit();

  Future<Database> openSeeded(WidgetTester tester) async {
    // Database work uses real I/O, so it runs outside the fake-async zone.
    final db = (await tester.runAsync(() async {
      final db = await AppDatabase.openWith(databaseFactoryFfiNoIsolate, inMemoryDatabasePath);
      await CatalogSeeder(db, (path) => File(path).readAsString()).seedIfNeeded();
      return db;
    }))!;
    addTearDown(() => tester.runAsync(db.close));
    return db;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  void phoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('first launch shows onboarding', (tester) async {
    phoneViewport(tester);
    final db = await openSeeded(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        startupPreferencesProvider.overrideWithValue(
            const StartupPreferences(onboardingDone: false, themeMode: ThemeMode.light)),
      ],
      child: const TripMateApp(),
    ));
    await settle(tester);

    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('Explore shows destinations and tabs', (tester) async {
    phoneViewport(tester);
    final db = await openSeeded(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const TripMateApp(),
    ));
    await settle(tester);

    expect(find.text('Where in Vietnam\nare you heading?'), findsOneWidget);
    expect(find.text('Da Nang'), findsWidgets);
    expect(find.text('Plan a trip in a minute'), findsOneWidget);
    for (final tab in ['Explore', 'Trips', 'Saved', 'Settings']) {
      expect(find.text(tab), findsOneWidget);
    }

    await tester.tap(find.text('Trips'));
    await settle(tester);
    expect(find.text('No trips yet'), findsOneWidget);
  });
}
