import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'extras.dart';
import 'theme.dart';

const logoAsset = 'assets/images/logo.jpg';

// Shows the picture, or nothing at all if the file is missing.
Widget safeImage(String path, {double? width, double? height, BoxFit? fit}) {
  return Image.asset(
    path,
    width: width,
    height: height,
    fit: fit,
    errorBuilder: (_, __, ___) => SizedBox(width: width, height: height),
  );
}

// The school logo "builds itself": a ring draws around it,
// then the logo rises from the bottom. Repeats while loading.
class LogoLoader extends StatefulWidget {
  final double size;
  const LogoLoader({super.key, this.size = 100});

  @override
  State<LogoLoader> createState() => _LogoLoaderState();
}

class _LogoLoaderState extends State<LogoLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600))
    ..repeat();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final accent = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: c,
      builder: (_, __) {
        final t = c.value;
        final ring = Curves.easeOut.transform((t / .5).clamp(0.0, 1.0));
        final rise = Curves.easeInOut.transform(((t - .2) / .6).clamp(0.0, 1.0));
        final fade = t > .9 ? 1 - (t - .9) / .1 : 1.0;
        return Opacity(
          opacity: fade,
          child: SizedBox(
            width: s,
            height: s,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(size: Size.square(s), painter: _Ring(ring, accent)),
                Transform.scale(
                  scale: .9 + .1 * rise,
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      heightFactor: rise,
                      child: ClipOval(
                        child: safeImage(logoAsset,
                            width: s * .78, height: s * .78),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Ring extends CustomPainter {
  final double p;
  final Color color;
  _Ring(this.p, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(4, 4, size.width - 8, size.height - 8);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = color.withAlpha(35);
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(r, 0, 2 * math.pi, false, base);
    canvas.drawArc(r, -math.pi / 2, 2 * math.pi * p, false, fg);
  }

  @override
  bool shouldRepaint(_Ring old) => old.p != p || old.color != color;
}

// LOADING state: gray placeholder rows (skeleton).
class FakeList extends StatelessWidget {
  const FakeList({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: List.generate(
          7,
          (_) => const Card(
            child: ListTile(
              leading: CircleAvatar(),
              title: Text('Loading student name'),
              subtitle: Text('HY202500000  •  Grade 11  •  STEM'),
            ),
          ),
        ),
      ),
    );
  }
}

// Full loading screen: skeleton rows + the animated logo on top.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const FakeList(),
          Positioned.fill(
            child: ColoredBox(
                color: Theme.of(context).colorScheme.surface.withAlpha(180)),
          ),
          const Center(child: LogoBar()),
        ],
      ),
    );
  }
}

// EMPTY state: tells the person what is missing and what to do next.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, message;
  const EmptyState(
      {super.key,
      required this.icon,
      required this.title,
      required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 200),
      builder: (_, v, child) => Opacity(opacity: v, child: child),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: scheme.outline),
              const SizedBox(height: 12),
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

// ERROR state: says what went wrong and gives a Try again button.
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: scheme.error),
            const SizedBox(height: 12),
            Text('Something went wrong',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

// Photo with a solid navy tint (no gradient).
class PhotoBackdrop extends StatelessWidget {
  final String asset;
  const PhotoBackdrop(this.asset, {super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        safeImage(asset, fit: BoxFit.cover),
        ColoredBox(color: deepNavy.withAlpha(200)),
      ],
    );
  }
}

class HeroBanner extends StatelessWidget {
  const HeroBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 140,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const PhotoBackdrop('assets/images/cainta.jpg'),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  ClipOval(child: safeImage(logoAsset, width: 76, height: 76)),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Library Logbook',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800)),
                        SizedBox(height: 2),
                        Text('ICCT Colleges Foundation Inc.\nTaytay Satellite Campus',
                            style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Small logo + title for the top bar.
class BrandTitle extends StatelessWidget {
  const BrandTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipOval(child: safeImage(logoAsset, width: 32, height: 32)),
        const SizedBox(width: 10),
        const Text('Library Logbook',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// Plain solid page color behind every screen (no gradient).
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF0E141C) : const Color(0xFFF4F6FA);
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: bg),
        Opacity(
          opacity: .14,
          child: safeImage('assets/images/cainta.jpg', fit: BoxFit.cover),
        ),
      ],
    );
  }
}
