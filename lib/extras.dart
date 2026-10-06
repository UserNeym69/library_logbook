import 'package:flutter/material.dart';

import 'widgets.dart';

// Loading bar made from the school logo: the logo fills with color
// from left to right while a slim bar fills under it.
class LogoBar extends StatefulWidget {
  final double size;
  const LogoBar({super.key, this.size = 110});

  @override
  State<LogoBar> createState() => _LogoBarState();
}

class _LogoBarState extends State<LogoBar> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200))
    ..repeat();

  static const _gray = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final scheme = Theme.of(context).colorScheme;
    final logo = ClipOval(child: safeImage(logoAsset, width: s, height: s));
    return AnimatedBuilder(
      animation: c,
      builder: (_, __) {
        final p = Curves.easeInOut.transform((c.value / .85).clamp(0.0, 1.0));
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: s,
              height: s,
              child: Stack(
                children: [
                  Opacity(
                    opacity: .35,
                    child: ColorFiltered(colorFilter: _gray, child: logo),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: ClipRect(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        widthFactor: p,
                        child: SizedBox(width: s, height: s, child: logo),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: s * 1.7,
                height: 8,
                child: Stack(
                  children: [
                    Positioned.fill(
                        child: ColoredBox(color: scheme.primary.withAlpha(35))),
                    Positioned.fill(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: p,
                        child: ColoredBox(color: scheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text('Loading the library...',
                style: TextStyle(
                    fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
        );
      },
    );
  }
}

// A number that counts up smoothly.
class CountUp extends StatelessWidget {
  final int value;
  final TextStyle? style;
  const CountUp({super.key, required this.value, this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (_, v, __) => Text('$v', style: style),
    );
  }
}
