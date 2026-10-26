import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'data/local/app_database.dart';
import 'data/sources/catalog_seeder.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final db = await AppDatabase.open();
    await CatalogSeeder(db, rootBundle.loadString).seedIfNeeded();
    runApp(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const TripMateApp(),
    ));
  } catch (e, st) {
    debugPrint('Startup failed: $e\n$st');
    runApp(StartupErrorApp(error: e));
  }
}
