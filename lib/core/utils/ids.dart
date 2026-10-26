import 'dart:math';

final _random = Random();
int _counter = 0;

/// Locally unique ID such as `trip_m3k9x2a1_7f3c`. Not a security token.
String newId(String prefix) {
  _counter = (_counter + 1) & 0xffff;
  final time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final rand = _random.nextInt(1 << 20).toRadixString(36);
  return '${prefix}_${time}_${_counter.toRadixString(36)}$rand';
}
