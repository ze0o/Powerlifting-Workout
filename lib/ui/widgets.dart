// Shared widgets: scoreboard header, lift tag, plate loading, referee light,
// stat tile, panel, line chart, and small dialog helpers.
import 'package:flutter/material.dart';

import '../core/calc.dart';
import '../core/store.dart';
import 'theme.dart';
import '../l10n/l10n.dart';

/// Navy header band with a red competition stripe. Pads for the status bar.
class ScreenHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final List<Widget> actions;
  final Widget? bottom;
  const ScreenHeader({super.key, required this.eyebrow, required this.title, this.actions = const [], this.bottom});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final top = MediaQuery.of(context).padding.top;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: p.navy,
          padding: EdgeInsets.fromLTRB(16, top + 14, 8, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr(context, eyebrow), style: eyebrowStyle(context, color: p.navyMuted)),
                        const SizedBox(height: 4),
                        Text(tr(context, title), style: headingStyle(context, size: 26, color: p.onNavy)),
                      ],
                    ),
                  ),
                  ...actions,
                ],
              ),
              if (bottom != null) ...[
                const SizedBox(height: 14),
                Padding(padding: const EdgeInsets.only(right: 8), child: bottom!),
              ],
            ],
          ),
        ),
        Container(height: 3, color: p.red),
      ],
    );
  }
}

class LiftTag extends StatelessWidget {
  final String lift;
  const LiftTag(this.lift, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: p.lift(lift), borderRadius: BorderRadius.circular(3)),
      child: Text(
        tr(context, (kLiftNames[lift] ?? lift).toUpperCase()),
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: spacing(context, 1.2), color: p.bg),
      ),
    );
  }
}

class LevelChip extends StatelessWidget {
  final String level;
  const LevelChip(this.level, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final c = switch (level) {
      'Beginner' => p.ok,
      'Intermediate' => p.blue,
      'Advanced' => p.red,
      _ => p.muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(border: Border.all(color: c), borderRadius: BorderRadius.circular(3)),
      child: Text(tr(context, level.toUpperCase()),
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: spacing(context, 1.2), color: c)),
    );
  }
}

/// "112.5 = bar + 25 · 20 · 1.25 per side" with the plates drawn to scale.
/// Uses the bar, plates and collars from the gym setup.
class PlateLoad extends StatelessWidget {
  final double weight;
  const PlateLoad(this.weight, {super.key});

  static double _height(double kg) => kg >= 25
      ? 34
      : kg >= 20
          ? 31
          : kg >= 15
              ? 27
              : kg >= 10
                  ? 23
                  : kg >= 5
                      ? 17
                      : kg >= 2.5
                          ? 13
                          : kg >= 1.25
                              ? 10
                              : 8;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final g = StoreScope.of(context).gym;
    final plan = platePlan(weight, bar: g.bar, plates: g.plates, collars: g.collarKg);
    if (plan == null) {
      return Text(tr(context, '{w} = empty bar', {'w': fmt(weight)}), style: TextStyle(fontSize: 12.5, color: p.muted));
    }
    final extra = [
      if (g.collars) 'collars',
      if (plan.leftover > 0) '${fmt(plan.leftover * 2)} kg short with your plates',
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 4, color: p.plates.last),
        const SizedBox(width: 2),
        for (final pl in plan.plates)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Container(
              width: 7,
              height: _height(pl),
              decoration: BoxDecoration(
                color: p.plate(pl),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: Colors.black.withAlpha(45)),
              ),
            ),
          ),
        const SizedBox(width: 6),
        Flexible(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: fmt(weight), style: TextStyle(fontWeight: FontWeight.w800, color: p.ink)),
              TextSpan(text: tr(context, ' = bar + {p} per side', {'p': plan.plates.map(fmt).join(' · ')})),
              if (extra.isNotEmpty)
                TextSpan(
                    text: ' (${extra.join(', ')})',
                    style: TextStyle(color: plan.leftover > 0 ? p.warn : p.muted)),
            ]),
            style: TextStyle(fontSize: 12.5, color: p.muted, fontFeatures: kTabular),
          ),
        ),
      ],
    );
  }
}

/// Referee light for a set. 0 = not marked, 1 = good lift (white), 2 = no lift (red).
class RefLight extends StatelessWidget {
  final int status;
  final VoidCallback onTap;
  const RefLight({super.key, required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final tip = status == 1 ? 'Good lift. Tap to mark as missed' : (status == 2 ? 'Missed. Tap to clear' : 'Tap when the set is done');
    return Tooltip(
      message: tip,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: status == 1 ? Colors.white : (status == 2 ? p.red : Colors.transparent),
              border: Border.all(
                color: status == 0 ? p.line : (status == 1 ? const Color(0xFF8E99AA) : p.red),
                width: 2,
              ),
              boxShadow: status == 1 ? [BoxShadow(color: Colors.white.withAlpha(120), blurRadius: 6)] : null,
            ),
            child: status == 1
                ? const Icon(Icons.check, size: 16, color: Color(0xFF0C2340))
                : (status == 2 ? const Icon(Icons.close, size: 16, color: Colors.white) : null),
          ),
        ),
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final String? delta;
  final Color? deltaColor;
  const StatTile({super.key, required this.label, required this.value, this.unit = '', this.delta, this.deltaColor});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(tr(context, label).toUpperCase(), style: eyebrowStyle(context), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              if (unit.isNotEmpty)
                TextSpan(text: ' $unit', style: TextStyle(fontSize: 12, color: p.muted, fontWeight: FontWeight.w600)),
            ]),
            style: const TextStyle(fontFeatures: kTabular),
          ),
        ),
        if (delta != null)
          Text(delta!,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: deltaColor ?? p.muted, fontFeatures: kTabular)),
      ],
    );
  }
}

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}

class NoteBox extends StatelessWidget {
  final String text;
  const NoteBox(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: p.sunk,
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: p.red, width: 3)),
      ),
      child: Text(tr(context, text), style: const TextStyle(fontSize: 13.5)),
    );
  }
}

// ---------- chart ----------

class ChartPoint {
  final double x, y;
  const ChartPoint(this.x, this.y);
}

class GuideLine {
  final double y;
  final String label;
  final Color color;
  const GuideLine(this.y, this.label, this.color);
}

class LineChart extends StatelessWidget {
  final List<ChartPoint> points;
  final double xMin, xMax, yMin, yMax, yStep;
  final List<String> xLabels; // evenly spaced from xMin to xMax
  final List<GuideLine> guides;
  final (double, double, String)? band; // low, high, label
  final Color color;
  final String emptyText;

  const LineChart({
    super.key,
    required this.points,
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
    required this.yStep,
    required this.xLabels,
    required this.color,
    this.guides = const [],
    this.band,
    this.emptyText = '',
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 340 / 160,
      child: CustomPaint(painter: _ChartPainter(this, Palette.of(context))),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final LineChart c;
  final Palette p;
  _ChartPainter(this.c, this.p);

  void _text(Canvas canvas, String s, Offset at, {TextAlign align = TextAlign.left}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: 10, color: p.muted)),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = at.dx;
    if (align == TextAlign.right) dx -= tp.width;
    if (align == TextAlign.center) dx -= tp.width / 2;
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint paint) {
    final len = (b - a).distance;
    if (len <= 0) return;
    final dir = (b - a) / len;
    var t = 0.0;
    while (t < len) {
      final e = (t + 5).clamp(0.0, len).toDouble();
      canvas.drawLine(a + dir * t, a + dir * e, paint);
      t += 9;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    const l = 34.0, r = 42.0, top = 10.0, bottom = 22.0;
    final w = size.width, h = size.height;
    final xSpan = (c.xMax - c.xMin) == 0 ? 1.0 : (c.xMax - c.xMin);
    final ySpan = (c.yMax - c.yMin) == 0 ? 1.0 : (c.yMax - c.yMin);
    double x(double v) => l + (v - c.xMin) * (w - l - r) / xSpan;
    double y(double v) => top + (c.yMax - v) * (h - top - bottom) / ySpan;

    final grid = Paint()
      ..color = p.line
      ..strokeWidth = 1;

    if (c.band != null) {
      final (lo, hi, label) = c.band!;
      final y1 = y(hi.clamp(c.yMin, c.yMax).toDouble()), y2 = y(lo.clamp(c.yMin, c.yMax).toDouble());
      canvas.drawRect(Rect.fromLTRB(l, y1, w - r, y2), Paint()..color = p.ok.withAlpha(32));
      _text(canvas, label, Offset(l + 4, y1 + 8));
    }
    for (var v = c.yMin; v <= c.yMax + 1e-9; v += c.yStep) {
      canvas.drawLine(Offset(l, y(v)), Offset(w - r, y(v)), grid);
      _text(canvas, fmt(v), Offset(l - 6, y(v)), align: TextAlign.right);
    }
    for (var i = 0; i < c.xLabels.length; i++) {
      final v = c.xLabels.length == 1 ? c.xMin : c.xMin + i * (c.xMax - c.xMin) / (c.xLabels.length - 1);
      _text(canvas, c.xLabels[i], Offset(x(v), h - 8), align: TextAlign.center);
    }
    for (final g in c.guides) {
      if (g.y < c.yMin || g.y > c.yMax) continue;
      _dashed(canvas, Offset(l, y(g.y)), Offset(w - r, y(g.y)),
          Paint()
            ..color = g.color
            ..strokeWidth = 1.2);
      _text(canvas, g.label, Offset(w - r + 4, y(g.y)));
    }

    if (c.points.isEmpty) {
      _text(canvas, c.emptyText, Offset((l + w - r) / 2, h / 2), align: TextAlign.center);
      return;
    }
    final path = Path()..moveTo(x(c.points.first.x), y(c.points.first.y));
    for (final pt in c.points.skip(1)) {
      path.lineTo(x(pt.x), y(pt.y));
    }
    if (c.points.length > 1) {
      final fill = Path.from(path)
        ..lineTo(x(c.points.last.x), h - bottom)
        ..lineTo(x(c.points.first.x), h - bottom)
        ..close();
      canvas.drawPath(fill, Paint()..color = c.color.withAlpha(28));
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = c.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeJoin = StrokeJoin.round);
    for (var i = 0; i < c.points.length; i++) {
      final last = i == c.points.length - 1;
      final o = Offset(x(c.points[i].x), y(c.points[i].y));
      canvas.drawCircle(o, last ? 4.5 : 3, Paint()..color = last ? c.color : p.surface);
      canvas.drawCircle(
          o,
          last ? 4.5 : 3,
          Paint()
            ..color = c.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) => true;
}

/// Rounds a y-range out to whole steps, at least [minSpan] wide.
(double, double, double) niceRange(List<double> vals, double pad, {double unit = 10, double minSpan = 20}) {
  var lo = vals.reduce((a, b) => a < b ? a : b);
  var hi = vals.reduce((a, b) => a > b ? a : b);
  lo = ((lo - pad) / unit).floorToDouble() * unit;
  hi = ((hi + pad) / unit).ceilToDouble() * unit;
  if (hi - lo < minSpan) hi = lo + minSpan;
  var step = unit;
  while ((hi - lo) / step > 6) {
    step *= 2;
  }
  return (lo, hi, step);
}

// ---------- dialogs ----------

Future<String?> pickIsoDate(BuildContext context, String current, {String? help}) async {
  final c = parseIso(current);
  final d = await showDatePicker(
    context: context,
    initialDate: DateTime(c.year, c.month, c.day),
    firstDate: DateTime(2020),
    lastDate: DateTime(2035, 12, 31),
    helpText: help,
  );
  return d == null ? null : isoDate(d);
}

Future<bool> confirmDialog(BuildContext context,
    {required String title, required String body, required String action, bool danger = false}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr(context, title)),
      content: Text(tr(context, body)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const T('Cancel')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: Palette.of(ctx).red, foregroundColor: Colors.white) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(tr(ctx, action)),
        ),
      ],
    ),
  );
  return ok == true;
}

Future<String?> promptText(BuildContext context,
    {required String title, required String label, String initial = '', String action = 'Save'}) async {
  final ctl = TextEditingController(text: initial);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr(ctx, title)),
      content: TextField(
        controller: ctl,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: tr(ctx, label)),
        onSubmitted: (_) => Navigator.pop(ctx, true),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const T('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr(ctx, action))),
      ],
    ),
  );
  return ok == true ? ctl.text : null;
}

void toast(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, message))));
