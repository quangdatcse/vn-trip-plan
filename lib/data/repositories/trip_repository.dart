import 'package:sqflite/sqflite.dart';

import '../../models/itinerary.dart';
import '../../models/trip.dart';

class TripRepository {
  TripRepository(this._db);

  final Database _db;

  Future<List<Trip>> listTrips() async {
    final rows = await _db.query('trips', orderBy: 'start_date DESC, created_at DESC');
    final trips = <Trip>[];
    for (final row in rows) {
      trips.add(Trip.fromMap(row, await _destinationIds(_db, row['id'] as String)));
    }
    return trips;
  }

  Future<TripPlan?> getPlan(String tripId) async {
    final tripRows =
        await _db.query('trips', where: 'id = ?', whereArgs: [tripId], limit: 1);
    if (tripRows.isEmpty) return null;
    final trip = Trip.fromMap(tripRows.first, await _destinationIds(_db, tripId));

    final dayRows = await _db.query('itinerary_days',
        where: 'trip_id = ?', whereArgs: [tripId], orderBy: 'day_index');
    final itemRows = await _db.rawQuery('''
      SELECT i.* FROM itinerary_items i
      JOIN itinerary_days d ON d.id = i.day_id
      WHERE d.trip_id = ?
      ORDER BY i.position''', [tripId]);

    final itemsByDay = <String, List<ItineraryItem>>{};
    for (final row in itemRows) {
      final item = ItineraryItem.fromMap(row);
      itemsByDay.putIfAbsent(item.dayId, () => []).add(item);
    }
    final days = [
      for (final row in dayRows)
        ItineraryDay.fromMap(row, itemsByDay[row['id']] ?? const []),
    ];
    return TripPlan(trip: trip, days: days);
  }

  /// Saves the trip and replaces its whole itinerary in one transaction.
  Future<void> savePlan(TripPlan plan) async {
    final trip = plan.trip;
    await _db.transaction((txn) async {
      final updated = await txn
          .update('trips', trip.toMap(), where: 'id = ?', whereArgs: [trip.id]);
      if (updated == 0) await txn.insert('trips', trip.toMap());

      await txn.delete('trip_destinations', where: 'trip_id = ?', whereArgs: [trip.id]);
      for (var i = 0; i < trip.destinationIds.length; i++) {
        await txn.insert('trip_destinations', {
          'trip_id': trip.id,
          'destination_id': trip.destinationIds[i],
          'position': i,
        });
      }

      // Items are removed by ON DELETE CASCADE.
      await txn.delete('itinerary_days', where: 'trip_id = ?', whereArgs: [trip.id]);
      for (final day in plan.days) {
        await txn.insert('itinerary_days', day.toMap());
        for (final item in day.items) {
          await txn.insert('itinerary_items', item.toMap());
        }
      }
    });
  }

  Future<void> deleteTrip(String tripId) =>
      _db.delete('trips', where: 'id = ?', whereArgs: [tripId]);

  Future<void> deleteAllTrips() => _db.delete('trips');

  static Future<List<String>> _destinationIds(DatabaseExecutor db, String tripId) async {
    final rows = await db.query('trip_destinations',
        columns: ['destination_id'],
        where: 'trip_id = ?',
        whereArgs: [tripId],
        orderBy: 'position');
    return rows.map((r) => r['destination_id'] as String).toList();
  }
}
