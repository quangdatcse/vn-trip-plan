import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// SQLite schema and migrations.
///
/// To change the schema: bump [schemaVersion] and add a new entry to
/// [_migrations]. Never edit a migration that has already shipped.
class AppDatabase {
  static const fileName = 'vietnam_tripmate.db';
  static const schemaVersion = 1;

  static const Map<int, List<String>> _migrations = {
    1: [
      '''
      CREATE TABLE app_settings (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )''',
      '''
      CREATE TABLE destinations (
        id          TEXT PRIMARY KEY,
        name        TEXT NOT NULL,
        local_name  TEXT,
        region      TEXT NOT NULL,
        description TEXT NOT NULL,
        latitude    REAL NOT NULL,
        longitude   REAL NOT NULL,
        sort_order  INTEGER NOT NULL DEFAULT 0
      )''',
      '''
      CREATE TABLE places (
        id                     TEXT PRIMARY KEY,
        destination_id         TEXT NOT NULL
                               REFERENCES destinations(id) ON UPDATE CASCADE ON DELETE RESTRICT,
        name_en                TEXT NOT NULL,
        name_local             TEXT,
        area                   TEXT NOT NULL,
        latitude               REAL NOT NULL,
        longitude              REAL NOT NULL,
        category               TEXT NOT NULL,
        interests              TEXT NOT NULL DEFAULT '',
        description            TEXT NOT NULL,
        suggested_duration_min INTEGER NOT NULL CHECK (suggested_duration_min > 0),
        best_slots             TEXT NOT NULL DEFAULT '',
        source                 TEXT NOT NULL,
        verified_on            TEXT,
        verification_status    TEXT NOT NULL,
        image_url              TEXT,
        image_credit           TEXT
      )''',
      'CREATE INDEX idx_places_destination ON places(destination_id)',
      '''
      CREATE TABLE trips (
        id          TEXT PRIMARY KEY,
        title       TEXT NOT NULL,
        origin      TEXT NOT NULL,
        start_date  TEXT NOT NULL,
        end_date    TEXT NOT NULL,
        travelers   INTEGER NOT NULL CHECK (travelers >= 1),
        budget      REAL CHECK (budget IS NULL OR budget >= 0),
        currency    TEXT NOT NULL,
        interests   TEXT NOT NULL DEFAULT '',
        pace        TEXT NOT NULL,
        transport   TEXT NOT NULL,
        created_at  TEXT NOT NULL,
        updated_at  TEXT NOT NULL
      )''',
      '''
      CREATE TABLE trip_destinations (
        trip_id        TEXT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
        destination_id TEXT NOT NULL REFERENCES destinations(id) ON DELETE RESTRICT,
        position       INTEGER NOT NULL,
        PRIMARY KEY (trip_id, destination_id)
      )''',
      '''
      CREATE TABLE itinerary_days (
        id             TEXT PRIMARY KEY,
        trip_id        TEXT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
        day_index      INTEGER NOT NULL,
        date           TEXT NOT NULL,
        destination_id TEXT NOT NULL REFERENCES destinations(id) ON DELETE RESTRICT,
        UNIQUE (trip_id, day_index)
      )''',
      '''
      CREATE TABLE itinerary_items (
        id                   TEXT PRIMARY KEY,
        day_id               TEXT NOT NULL REFERENCES itinerary_days(id) ON DELETE CASCADE,
        place_id             TEXT NOT NULL REFERENCES places(id) ON DELETE RESTRICT,
        slot                 TEXT NOT NULL CHECK (slot IN ('morning', 'afternoon', 'evening')),
        position             INTEGER NOT NULL,
        duration_min         INTEGER NOT NULL CHECK (duration_min > 0),
        travel_min_from_prev INTEGER,
        travel_km_from_prev  REAL,
        note                 TEXT
      )''',
      'CREATE INDEX idx_items_day ON itinerary_items(day_id)',
      '''
      CREATE TABLE affiliate_offers (
        provider_id    TEXT NOT NULL,
        id             TEXT NOT NULL,
        provider_name  TEXT NOT NULL,
        destination_id TEXT NOT NULL REFERENCES destinations(id) ON DELETE CASCADE,
        place_id       TEXT REFERENCES places(id) ON DELETE SET NULL,
        title          TEXT NOT NULL,
        image_url      TEXT,
        price_amount   REAL,
        price_currency TEXT,
        booking_url    TEXT NOT NULL,
        is_mock        INTEGER NOT NULL DEFAULT 0,
        fetched_at     TEXT NOT NULL,
        expires_at     TEXT NOT NULL,
        PRIMARY KEY (provider_id, id)
      )''',
      'CREATE INDEX idx_offers_destination ON affiliate_offers(destination_id)',
    ],
  };

  /// Opens the on-device database. On web (development preview only) it is
  /// stored in IndexedDB.
  static Future<Database> open() async {
    if (kIsWeb) {
      return openWith(databaseFactoryFfiWeb, fileName);
    }
    final dir = await getDatabasesPath();
    return openWith(databaseFactory, p.join(dir, fileName));
  }

  /// Used directly by tests with an in-memory FFI factory.
  static Future<Database> openWith(DatabaseFactory factory, String path) {
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) => _migrate(db, 0, version),
        onUpgrade: _migrate,
      ),
    );
  }

  static Future<void> _migrate(Database db, int from, int to) async {
    final batch = db.batch();
    for (var v = from + 1; v <= to; v++) {
      for (final sql in _migrations[v] ?? const <String>[]) {
        batch.execute(sql);
      }
    }
    await batch.commit(noResult: true);
  }
}
