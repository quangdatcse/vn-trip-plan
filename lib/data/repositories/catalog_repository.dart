import 'package:sqflite/sqflite.dart';

import '../../models/destination.dart';
import '../../models/place.dart';

class CatalogRepository {
  CatalogRepository(this._db);

  final Database _db;

  Future<List<Destination>> getDestinations() async {
    final rows = await _db.query('destinations', orderBy: 'sort_order, name');
    return rows.map(Destination.fromMap).toList();
  }

  Future<Destination?> getDestination(String id) async {
    final rows =
        await _db.query('destinations', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Destination.fromMap(rows.first);
  }

  Future<List<Place>> getPlaces({String? destinationId}) async {
    final rows = await _db.query(
      'places',
      where: destinationId == null ? null : 'destination_id = ?',
      whereArgs: destinationId == null ? null : [destinationId],
      orderBy: 'name_en',
    );
    return rows.map(Place.fromMap).toList();
  }

  Future<Place?> getPlace(String id) async {
    final rows = await _db.query('places', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Place.fromMap(rows.first);
  }
}
