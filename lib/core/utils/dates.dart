/// Date-only helpers. Dates are kept at UTC midnight so arithmetic in days
/// is not affected by daylight saving.
library;

DateTime dateOnly(DateTime value) => DateTime.utc(value.year, value.month, value.day);

String formatIsoDate(DateTime value) {
  final d = dateOnly(value);
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

DateTime parseDate(String value) => dateOnly(DateTime.parse(value));

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// e.g. "Mon 3 Nov".
String formatShortDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';

/// e.g. "3 Nov 2026".
String formatMediumDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// e.g. "1h 30m", "45m".
String formatMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}
