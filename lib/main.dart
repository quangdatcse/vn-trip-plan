import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'data/local/app_database.dart';
import 'data/repositories/settings_repository.dart';
import 'data/sources/catalog_seeder.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final db = await AppDatabase.open();
    await CatalogSeeder(db, rootBundle.loadString).seedIfNeeded();
    final prefs = await StartupPreferences.load(SettingsRepository(db));
    runApp(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        startupPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const TripMateApp(),
    ));
  } catch (e, st) {
    debugPrint('Startup failed: $e\n$st');
    runApp(StartupErrorApp(error: e));
  }
}
