import 'package:sqflite/sqflite.dart';

class SavedPlacesRepository {
  SavedPlacesRepository(this._db);

  final Database _db;

  /// Most recently saved first.
  Future<List<String>> savedIds() async {
    final rows = await _db.query('saved_places', orderBy: 'saved_at DESC');
    return rows.map((r) => r['place_id'] as String).toList();
  }

  Future<void> toggle(String placeId) async {
    final removed =
        await _db.delete('saved_places', where: 'place_id = ?', whereArgs: [placeId]);
    if (removed == 0) {
      await _db.insert('saved_places', {
        'place_id': placeId,
        'saved_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
  }

  Future<void> clear() => _db.delete('saved_places');
}
