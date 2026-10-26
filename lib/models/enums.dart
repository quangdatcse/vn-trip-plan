/// Shared enums. Each enum is stored in SQLite by its [Enum.name], so
/// renaming a value requires a database migration.
library;

T enumFromName<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

Set<T> enumSetFromCsv<T extends Enum>(List<T> values, String? csv) {
  if (csv == null || csv.isEmpty) return <T>{};
  final names = csv.split(',').map((s) => s.trim()).toSet();
  return values.where((v) => names.contains(v.name)).toSet();
}

String enumSetToCsv(Iterable<Enum> values) =>
    values.map((v) => v.name).join(',');

enum Interest {
  food('Food'),
  culture('Culture'),
  nature('Nature'),
  beaches('Beaches'),
  adventure('Adventure'),
  shopping('Shopping'),
  family('Family');

  const Interest(this.label);
  final String label;
}

enum Pace {
  relaxed('Relaxed', 'Fewer stops, plenty of downtime'),
  balanced('Balanced', 'A comfortable mix'),
  packed('Packed', 'See as much as possible');

  const Pace(this.label, this.description);
  final String label;
  final String description;
}

enum TransportMode {
  walking('Walking'),
  bicycle('Bicycle'),
  motorbike('Motorbike'),
  taxi('Taxi / ride-hailing'),
  privateCar('Private car');

  const TransportMode(this.label);
  final String label;
}

enum DaySlot {
  morning('Morning', '~8:00–12:00', 240),
  afternoon('Afternoon', '~13:30–17:30', 240),
  evening('Evening', '~18:30–21:30', 180);

  const DaySlot(this.label, this.window, this.lengthMinutes);
  final String label;

  /// Suggested time window shown to the user. Not tied to opening hours.
  final String window;
  final int lengthMinutes;
}

enum PlaceCategory {
  landmark('Landmark'),
  museum('Museum'),
  religiousSite('Religious site'),
  heritageSite('Heritage site'),
  market('Market'),
  beach('Beach'),
  nature('Nature'),
  village('Village'),
  entertainment('Entertainment');

  const PlaceCategory(this.label);
  final String label;
}

enum VerificationStatus {
  verified('Verified'),
  unverified('Not yet verified'),
  needsReview('Needs review');

  const VerificationStatus(this.label);
  final String label;
}
