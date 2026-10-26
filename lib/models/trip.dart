import '../core/utils/dates.dart';
import 'enums.dart';

class Trip {
  const Trip({
    required this.id,
    required this.title,
    required this.origin,
    required this.destinationIds,
    required this.startDate,
    required this.endDate,
    required this.travelers,
    this.budget,
    required this.currency,
    required this.interests,
    required this.pace,
    required this.transport,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String origin;

  /// Visit order of destinations.
  final List<String> destinationIds;

  /// Date-only values (UTC midnight) so day counts ignore daylight saving.
  final DateTime startDate;
  final DateTime endDate;
  final int travelers;
  final double? budget;
  final String currency;
  final Set<Interest> interests;
  final Pace pace;
  final TransportMode transport;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get dayCount => endDate.difference(startDate).inDays + 1;

  Trip copyWith({DateTime? updatedAt}) => Trip(
        id: id,
        title: title,
        origin: origin,
        destinationIds: destinationIds,
        startDate: startDate,
        endDate: endDate,
        travelers: travelers,
        budget: budget,
        currency: currency,
        interests: interests,
        pace: pace,
        transport: transport,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// [destinationIds] come from the `trip_destinations` table.
  factory Trip.fromMap(Map<String, Object?> map, List<String> destinationIds) =>
      Trip(
        id: map['id'] as String,
        title: map['title'] as String,
        origin: map['origin'] as String,
        destinationIds: destinationIds,
        startDate: parseDate(map['start_date'] as String),
        endDate: parseDate(map['end_date'] as String),
        travelers: (map['travelers'] as num).toInt(),
        budget: (map['budget'] as num?)?.toDouble(),
        currency: map['currency'] as String,
        interests: enumSetFromCsv(Interest.values, map['interests'] as String?),
        pace: enumFromName(Pace.values, map['pace'] as String?, Pace.balanced),
        transport: enumFromName(
            TransportMode.values, map['transport'] as String?, TransportMode.taxi),
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'origin': origin,
        'start_date': formatIsoDate(startDate),
        'end_date': formatIsoDate(endDate),
        'travelers': travelers,
        'budget': budget,
        'currency': currency,
        'interests': enumSetToCsv(interests),
        'pace': pace.name,
        'transport': transport.name,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };
}

/// Mutable form state for Create Trip. [validate] returns user-facing errors.
class TripDraft {
  static const maxDays = 30;
  static const maxTravelers = 20;
  static const currencies = ['USD', 'EUR', 'GBP', 'AUD', 'SGD', 'KRW', 'JPY', 'VND'];

  String title = '';
  String origin = '';
  List<String> destinationIds = [];
  DateTime? startDate;
  DateTime? endDate;
  int travelers = 2;
  String budgetText = '';
  String currency = 'USD';
  Set<Interest> interests = {};
  Pace pace = Pace.balanced;
  TransportMode transport = TransportMode.taxi;

  double? get budget {
    final text = budgetText.trim().replaceAll(',', '');
    return text.isEmpty ? null : double.tryParse(text);
  }

  List<String> validate() => [...validateWhere(), ...validateWhen(), ...validateDetails()];

  /// Wizard step 1.
  List<String> validateWhere() => [
        if (origin.trim().isEmpty) 'Enter where you are starting from.',
        if (origin.trim().length > 100) 'Starting point is too long.',
        if (destinationIds.isEmpty) 'Choose at least one destination.',
      ];

  /// Final step.
  List<String> validateDetails() => [
        if (title.trim().length > 80) 'Trip name is too long.',
      ];

  /// Wizard step 2.
  List<String> validateWhen() {
    final errors = <String>[];
    final start = startDate;
    final end = endDate;
    if (start == null || end == null) {
      errors.add('Choose your travel dates.');
    } else if (end.isBefore(start)) {
      errors.add('End date must be on or after the start date.');
    } else if (end.difference(start).inDays + 1 > maxDays) {
      errors.add('Trips can be at most $maxDays days.');
    }
    if (travelers < 1 || travelers > maxTravelers) {
      errors.add('Travelers must be between 1 and $maxTravelers.');
    }
    if (budgetText.trim().isNotEmpty) {
      final value = budget;
      if (value == null || value < 0 || value.isNaN || value.isInfinite) {
        errors.add('Budget must be a positive number.');
      }
    }
    if (!currencies.contains(currency)) errors.add('Choose a currency.');
    return errors;
  }

  /// Call only after [validate] returns no errors.
  Trip toTrip({required String id, required DateTime now, required String fallbackTitle}) {
    final cleanTitle = title.trim();
    return Trip(
      id: id,
      title: cleanTitle.isEmpty ? fallbackTitle : cleanTitle,
      origin: origin.trim(),
      destinationIds: List.unmodifiable(destinationIds),
      startDate: dateOnly(startDate!),
      endDate: dateOnly(endDate!),
      travelers: travelers,
      budget: budget,
      currency: currency,
      interests: Set.unmodifiable(interests),
      pace: pace,
      transport: transport,
      createdAt: now,
      updatedAt: now,
    );
  }
}
