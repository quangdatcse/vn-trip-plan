import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/enums.dart';
import 'place_widgets.dart';

/// Stable hash so artwork looks the same on every run and platform.
int _stableHash(String s) => s.codeUnits.fold(17, (h, c) => (h * 31 + c) & 0x7fffffff);

class _ScenePalette {
  const _ScenePalette({
    required this.sky,
    required this.sun,
    required this.far,
    required this.near,
    required this.water,
    required this.accent,
  });

  final List<Color> sky;
  final Color sun;
  final Color far;
  final Color near;
  final List<Color> water;
  final List<Color> accent;
}

const _daNang = _ScenePalette(
  sky: [Color(0xFF0B4F6C), Color(0xFF1E8C93), Color(0xFFF2B880)],
  sun: Color(0xFFFFD98E),
  far: Color(0xFF2B7A84),
  near: Color(0xFF0A3D4D),
  water: [Color(0xFF0E6E78), Color(0xFF073B44)],
  accent: [Color(0xFFF5C451)],
);

const _hoiAn = _ScenePalette(
  sky: [Color(0xFF2A1B3D), Color(0xFF7A3E48), Color(0xFFE8833A)],
  sun: Color(0xFFFFE3A3),
  far: Color(0xFF8C4A4F),
  near: Color(0xFF3A1F2B),
  water: [Color(0xFF4A2E4A), Color(0xFF1F1426)],
  accent: [Color(0xFFD64B3B), Color(0xFFF5C451), Color(0xFFE8833A)],
);

const _generic = _ScenePalette(
  sky: [Color(0xFF0E7C86), Color(0xFF5CC6C0), Color(0xFFFBE3BE)],
  sun: Color(0xFFFFF1C9),
  far: Color(0xFF3FA39F),
  near: Color(0xFF0B5560),
  water: [Color(0xFF0E7C86), Color(0xFF07535C)],
  accent: [Color(0xFFF5C451)],
);

/// Illustrated scene for a destination. Used instead of photos until
/// licensed images are available.
class SceneArtwork extends StatelessWidget {
  const SceneArtwork({super.key, required this.destinationId});

  final String destinationId;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          painter: _ScenePainter(destinationId),
          child: const SizedBox.expand(),
        ),
      );
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.id);

  final String id;

  _ScenePalette get _palette => switch (id) {
        'da_nang' => _daNang,
        'hoi_an' => _hoiAn,
        _ => _generic,
      };

  @override
  void paint(Canvas canvas, Size size) {
    final p = _palette;
    final w = size.width;
    final h = size.height;
    final rnd = math.Random(_stableHash(id));
    final rect = Offset.zero & size;

    // Sky
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: p.sky,
          stops: const [0, 0.55, 0.82],
        ).createShader(rect),
    );

    // Sun with glow
    final sun = Offset(w * 0.7, h * 0.46);
    final r = math.min(w, h) * 0.12;
    canvas.drawCircle(
      sun,
      r * 3.2,
      Paint()
        ..shader = RadialGradient(
          colors: [p.sun.withValues(alpha: 0.45), p.sun.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: sun, radius: r * 3.2)),
    );
    canvas.drawCircle(sun, r, Paint()..color = p.sun);

    final horizon = h * 0.68;

    // Far ridge
    canvas.drawPath(
      _ridge(w, horizon, h * 0.16, rnd, peaks: 3),
      Paint()..color = p.far.withValues(alpha: 0.75),
    );

    if (id == 'hoi_an') {
      _rooftops(canvas, w, horizon, h, p, rnd);
    } else {
      canvas.drawPath(
        _ridge(w, horizon, h * 0.1, rnd, peaks: 2),
        Paint()..color = p.near,
      );
    }

    // Water
    final water = Rect.fromLTRB(0, horizon, w, h);
    canvas.drawRect(
      water,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: p.water,
        ).createShader(water),
    );
    // Sun reflection and shimmer
    final shimmer = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1.5, h * 0.008);
    for (var i = 0; i < 14; i++) {
      final y = horizon + (h - horizon) * (0.12 + rnd.nextDouble() * 0.8);
      final near = (y - horizon) / (h - horizon);
      final cx = sun.dx + (rnd.nextDouble() - 0.5) * w * (0.15 + near * 0.3);
      final len = w * (0.03 + rnd.nextDouble() * 0.08) * (1 - near * 0.4);
      shimmer.color = p.sun.withValues(alpha: 0.25 + rnd.nextDouble() * 0.35);
      canvas.drawLine(Offset(cx - len / 2, y), Offset(cx + len / 2, y), shimmer);
    }

    if (id == 'da_nang') _dragonBridge(canvas, w, horizon, h, p);
    if (id == 'hoi_an') _lanterns(canvas, w, h, p);
  }

  Path _ridge(double w, double base, double amp, math.Random rnd,
      {required int peaks}) {
    final phase = rnd.nextDouble() * math.pi * 2;
    final path = Path()..moveTo(0, base);
    for (var x = 0.0; x <= w; x += w / 60) {
      final t = x / w;
      final y = base -
          amp *
              (0.55 +
                  0.35 * math.sin(t * math.pi * peaks + phase) +
                  0.1 * math.sin(t * math.pi * peaks * 3.3 + phase * 2));
      path.lineTo(x, y);
    }
    return path
      ..lineTo(w, base)
      ..close();
  }

  void _rooftops(Canvas canvas, double w, double horizon, double h, _ScenePalette p,
      math.Random rnd) {
    final paint = Paint()..color = p.near;
    final glow = Paint()..color = p.accent[1].withValues(alpha: 0.85);
    var x = -w * 0.02;
    while (x < w) {
      final bw = w * (0.12 + rnd.nextDouble() * 0.08);
      final bh = h * (0.08 + rnd.nextDouble() * 0.07);
      final top = horizon - bh;
      // Wall
      canvas.drawRect(Rect.fromLTRB(x + bw * 0.08, top, x + bw * 0.92, horizon), paint);
      // Curved tiled roof with upturned eaves
      final roof = Path()
        ..moveTo(x - bw * 0.04, top + bh * 0.06)
        ..quadraticBezierTo(x + bw * 0.1, top - bh * 0.02, x + bw * 0.2, top - bh * 0.28)
        ..lineTo(x + bw * 0.8, top - bh * 0.28)
        ..quadraticBezierTo(x + bw * 0.9, top - bh * 0.02, x + bw * 1.04, top + bh * 0.06)
        ..close();
      canvas.drawPath(roof, paint);
      // Lit windows
      if (rnd.nextBool()) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x + bw * 0.38, top + bh * 0.35, bw * 0.24, bh * 0.3),
            const Radius.circular(2),
          ),
          glow,
        );
      }
      x += bw * 0.98;
    }
  }

  void _dragonBridge(Canvas canvas, double w, double horizon, double h, _ScenePalette p) {
    final deck = horizon + (h - horizon) * 0.22;
    final gold = p.accent.first;
    canvas.drawLine(
      Offset(0, deck),
      Offset(w, deck),
      Paint()
        ..color = p.near
        ..strokeWidth = h * 0.018,
    );
    // Undulating dragon body above the deck
    final body = Path()..moveTo(-w * 0.05, deck);
    for (var x = -w * 0.05; x <= w * 1.05; x += w / 80) {
      final t = x / w;
      body.lineTo(x, deck - h * 0.09 * math.max(0, math.sin(t * math.pi * 3.2)).toDouble());
    }
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.012
        ..strokeCap = StrokeCap.round
        ..color = gold,
    );
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.05
        ..color = gold.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  void _lanterns(Canvas canvas, double w, double h, _ScenePalette p) {
    final string = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.black.withValues(alpha: 0.35);
    final sag = h * 0.1;
    double yAt(double x) => h * 0.06 + sag * math.sin(math.pi * x / w);
    final path = Path()..moveTo(0, yAt(0));
    for (var x = 0.0; x <= w; x += w / 40) {
      path.lineTo(x, yAt(x));
    }
    canvas.drawPath(path, string);

    const count = 7;
    for (var i = 0; i < count; i++) {
      final x = w * (i + 0.5) / count;
      final drop = h * (0.05 + (i % 3) * 0.035);
      final top = yAt(x);
      final cy = top + drop + h * 0.045;
      final rx = math.min(w, h) * 0.04;
      final ry = rx * 1.25;
      final color = p.accent[i % p.accent.length];
      canvas.drawLine(Offset(x, top), Offset(x, cy - ry), string);
      canvas.drawCircle(
        Offset(x, cy),
        rx * 3,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: 0.5), color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: Offset(x, cy), radius: rx * 3)),
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, cy), width: rx * 2, height: ry * 2),
        Paint()..color = color,
      );
      final cap = Paint()..color = const Color(0xFF2A1B1B);
      canvas.drawRect(Rect.fromCenter(center: Offset(x, cy - ry), width: rx, height: ry * 0.18), cap);
      canvas.drawRect(Rect.fromCenter(center: Offset(x, cy + ry), width: rx, height: ry * 0.18), cap);
    }
  }

  @override
  bool shouldRepaint(_ScenePainter old) => old.id != id;
}

/// Gradient cover for a place, tinted by category.
class CategoryCover extends StatelessWidget {
  const CategoryCover({
    super.key,
    required this.category,
    required this.seed,
    this.iconSize = 28,
  });

  final PlaceCategory category;
  final String seed;
  final double iconSize;

  static List<Color> colorsFor(PlaceCategory c) => switch (c) {
        PlaceCategory.beach => const [Color(0xFF5CC6C0), Color(0xFF0E7C86)],
        PlaceCategory.nature => const [Color(0xFF7DBE8C), Color(0xFF2F6E4F)],
        PlaceCategory.market => const [Color(0xFFF5B462), Color(0xFFD9653B)],
        PlaceCategory.museum => const [Color(0xFF9DA8D8), Color(0xFF4B4F8C)],
        PlaceCategory.religiousSite => const [Color(0xFFF2C46B), Color(0xFFB8742A)],
        PlaceCategory.heritageSite => const [Color(0xFFE8915A), Color(0xFF9C3D2E)],
        PlaceCategory.village => const [Color(0xFFB9CF7A), Color(0xFF5E7D2F)],
        PlaceCategory.entertainment => const [Color(0xFFE38BB5), Color(0xFF7D3C8C)],
        PlaceCategory.landmark => const [Color(0xFF6FB3D9), Color(0xFF1F5E8C)],
      };

  @override
  Widget build(BuildContext context) {
    final colors = colorsFor(category);
    return RepaintBoundary(
      child: CustomPaint(
        painter: _CoverPainter(colors, _stableHash(seed)),
        child: Center(
          child: Container(
            padding: EdgeInsets.all(iconSize * 0.45),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            ),
            child: Icon(categoryIcon(category), color: Colors.white, size: iconSize),
          ),
        ),
      ),
    );
  }
}

class _CoverPainter extends CustomPainter {
  _CoverPainter(this.colors, this.seed);

  final List<Color> colors;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rnd = math.Random(seed);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(-1 + rnd.nextDouble(), -1),
          end: const Alignment(1, 1),
          colors: colors,
        ).createShader(rect),
    );
    for (var i = 0; i < 3; i++) {
      final c = Offset(size.width * rnd.nextDouble(), size.height * rnd.nextDouble());
      final r = size.shortestSide * (0.35 + rnd.nextDouble() * 0.45);
      canvas.drawCircle(
        c,
        r,
        Paint()..color = Colors.white.withValues(alpha: 0.06 + rnd.nextDouble() * 0.06),
      );
    }
  }

  @override
  bool shouldRepaint(_CoverPainter old) => old.seed != seed || old.colors != colors;
}
