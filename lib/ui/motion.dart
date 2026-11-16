// Motion: page transitions, tab cross-fades, popup dialogs and counting numbers.
// Everything respects the phone's "remove animations" accessibility setting.
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import '../core/calc.dart';

const kMotionFast = Duration(milliseconds: 180);
const kMotion = Duration(milliseconds: 280);
const kMotionSlow = Duration(milliseconds: 600);

/// True when the user turned animations off in the phone's accessibility settings.
bool reduceMotion(BuildContext context) => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

// ---------- screens ----------

/// Opening a screen: the new one slides in a little from the reading side and
/// fades in; the old one drifts the other way. Mirrors for Arabic (right to left).
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (reduceMotion(context)) return child;
    final dir = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
    final inCurve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    final outCurve =
        CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return SlideTransition(
      position: Tween(begin: Offset(0.08 * dir, 0), end: Offset.zero).animate(inCurve),
      child: FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: const Interval(0, 0.7, curve: Curves.easeOut)),
        child: SlideTransition(
          position: Tween(begin: Offset.zero, end: Offset(-0.04 * dir, 0)).animate(outCurve),
          child: child,
        ),
      ),
    );
  }
}

/// Page transitions for the theme: ours everywhere, the native swipe-back on iOS.
const kPageTransitions = PageTransitionsTheme(builders: {
  TargetPlatform.android: AppPageTransitionsBuilder(),
  TargetPlatform.fuchsia: AppPageTransitionsBuilder(),
  TargetPlatform.linux: AppPageTransitionsBuilder(),
  TargetPlatform.windows: AppPageTransitionsBuilder(),
  TargetPlatform.macOS: AppPageTransitionsBuilder(),
  TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
});

// ---------- tabs ----------

/// An IndexedStack (every tab keeps its scroll position and typing) that fades
/// and lifts the newly selected tab into view.
class FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  const FadeIndexedStack({super.key, required this.index, required this.children});

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack> with SingleTickerProviderStateMixin {
  late final AnimationController ctl = AnimationController(vsync: this, duration: kMotion, value: 1);
  late final Animation<double> fade = CurvedAnimation(parent: ctl, curve: Curves.easeOut);
  late final Animation<Offset> lift =
      Tween(begin: const Offset(0, 0.015), end: Offset.zero).animate(CurvedAnimation(parent: ctl, curve: Curves.easeOutCubic));

  @override
  void didUpdateWidget(FadeIndexedStack old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      if (reduceMotion(context)) {
        ctl.value = 1;
      } else {
        ctl.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          // Same wrapper for every tab, so switching never rebuilds a tab from scratch.
          FadeTransition(
            key: widget.children[i].key,
            opacity: i == widget.index ? fade : kAlwaysCompleteAnimation,
            child: SlideTransition(
              position: i == widget.index ? lift : const AlwaysStoppedAnimation(Offset.zero),
              child: widget.children[i],
            ),
          ),
      ],
    );
  }
}

// ---------- popups ----------

/// Like showDialog, but the dialog grows in slightly and fades, and shrinks away.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final still = reduceMotion(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: still ? Duration.zero : const Duration(milliseconds: 240),
    pageBuilder: (ctx, _, __) => SafeArea(child: Builder(builder: builder)),
    transitionBuilder: (ctx, animation, _, child) {
      final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeInCubic);
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(curve), child: child),
      );
    },
  );
}

// ---------- numbers ----------

/// A number that counts to its new value instead of jumping.
class CountUpText extends StatelessWidget {
  final double? value;
  final String Function(double v) format;
  final TextStyle? style;
  const CountUpText(this.value, {super.key, this.format = fmt, this.style});

  @override
  Widget build(BuildContext context) {
    final v = value;
    if (v == null) return Text('—', style: style);
    if (reduceMotion(context)) return Text(format(v), style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: v * 0.9, end: v),
      duration: kMotionSlow,
      curve: Curves.easeOutCubic,
      builder: (_, x, __) => Text(format(x), style: style),
    );
  }
}

/// Fades and slides its child in when it first appears (for list items).
class FadeInUp extends StatelessWidget {
  final Widget child;
  final int index;
  const FadeInUp({super.key, required this.child, this.index = 0});

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    final delay = (index.clamp(0, 6)) * 0.08;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + (delay * 1000).round()),
      curve: Interval(delay / (0.32 + delay), 1, curve: Curves.easeOutCubic),
      builder: (_, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: c),
      ),
      child: child,
    );
  }
}
