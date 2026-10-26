import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../models/destination.dart';
import '../../models/place.dart';

/// Copies the curated catalog (`assets/data/catalog.json`) into SQLite.
///
/// Runs only when the asset's `version` is newer than the stored one, so
/// editors bump `version` whenever they change the JSON.
class CatalogSeeder {
  CatalogSeeder(this._db, this._loadAsset);

  static const assetPath = 'assets/data/catalog.json';
  static const _versionKey = 'catalog_version';

  final Database _db;
  final Future<String> Function(String path) _loadAsset;

  Future<void> seedIfNeeded() async {
    final json = jsonDecode(await _loadAsset(assetPath)) as Map<String, dynamic>;
    final version = (json['version'] as num).toInt();

    final rows = await _db.query('app_settings',
        where: 'key = ?', whereArgs: [_versionKey], limit: 1);
    final stored = rows.isEmpty ? 0 : int.tryParse(rows.first['value'] as String) ?? 0;
    if (stored >= version) return;

    final destinations = (json['destinations'] as List)
        .map((e) => Destination.fromMap((e as Map).cast<String, Object?>()))
        .toList();
    final places = (json['places'] as List)
        .map((e) => Place.fromJson(e as Map<String, dynamic>))
        .toList();

    await _db.transaction((txn) async {
      for (final d in destinations) {
        await _upsert(txn, 'destinations', d.toMap());
      }
      for (final place in places) {
        await _upsert(txn, 'places', place.toMap());
      }
      await txn.insert('app_settings', {'key': _versionKey, 'value': '$version'},
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  /// UPDATE then INSERT. `INSERT OR REPLACE` would delete the row first and
  /// trip the foreign keys of saved itineraries.
  Future<void> _upsert(Transaction txn, String table, Map<String, Object?> row) async {
    final updated =
        await txn.update(table, row, where: 'id = ?', whereArgs: [row['id']]);
    if (updated == 0) await txn.insert(table, row);
  }
}
