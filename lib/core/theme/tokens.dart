import 'package:flutter/material.dart';

/// Brand palette: Central Vietnam sea, Hoi An lanterns and warm sand.
class Palette {
  const Palette._();

  static const ink = Color(0xFF0B2A33);
  static const sea = Color(0xFF0E7C86);
  static const seaDeep = Color(0xFF07535C);
  static const lagoon = Color(0xFF5CC6C0);
  static const lantern = Color(0xFFE8833A);
  static const lanternRed = Color(0xFFD64B3B);
  static const silk = Color(0xFFF5C451);
  static const sand = Color(0xFFFBF6EE);
  static const sandDeep = Color(0xFFF1E7D8);
  static const night = Color(0xFF0E1A20);
  static const nightRaised = Color(0xFF16252C);
}

class Space {
  const Space._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Horizontal page gutter.
  static const page = 20.0;
}

class Radii {
  const Radii._();

  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const pill = 999.0;
}

extension AppText on TextStyle? {
  /// Sets a weight on the variable font. `fontWeight` alone does not move
  /// the `wght` axis on every platform, so both are set.
  TextStyle? w(int weight) => this?.copyWith(
        fontWeight: FontWeight.values[((weight ~/ 100) - 1).clamp(0, 8)],
        fontVariations: [FontVariation('wght', weight.toDouble())],
      );
}
