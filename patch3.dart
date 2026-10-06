// Run from the project folder:  dart patch3.dart
import 'dart:io';

void main() {
  final f = File('lib/main.dart');
  final w = File('lib/widgets.dart');
  if (!f.existsSync() || !w.existsSync()) {
    print('lib/main.dart or lib/widgets.dart not found. Run this from the project folder.');
    return;
  }
  File('lib/main.dart.bak3').writeAsStringSync(f.readAsStringSync());
  var s = f.readAsStringSync().replaceAll('\r\n', '\n');
  var ok = 0;
  final failed = <String>[];

  void edit(String name, String from, String to) {
    if (s.contains(from)) {
      s = s.replaceFirst(from, to);
      ok++;
    } else {
      failed.add(name);
    }
  }

  // 1) No skeleton when pressing the bottom tabs
  edit('tab skeleton off', r"""        child: tabLoading
            ? const Stack(
                key: ValueKey('skeleton'),
                fit: StackFit.expand,
                children: [FakeList(), Center(child: LogoLoader(size: 70))],
              )
            : KeyedSubtree(key: ValueKey(tab), child: pages[tab]),""",
      r"""        child: KeyedSubtree(key: ValueKey(tab), child: pages[tab]),""");

  edit('tab change back', r"""        onDestinationSelected: (i) {
          if (i == tab) return;
          setState(() {
            tab = i;
            tabLoading = true;
          });
          Future.delayed(const Duration(milliseconds: 450), () {
            if (mounted) setState(() => tabLoading = false);
          });
        },""", r"""        onDestinationSelected: (i) => setState(() => tab = i),""");

  // 2) Shorter start-up loading screen
  edit('splash time', r"""Duration(milliseconds: 1800)""", r"""Duration(milliseconds: 1200)""");

  // 3) Login logo: no red error text if an image is missing
  edit('login logo safe', r"""Image.asset(logoAsset, height: 72)""", r"""safeImage(logoAsset, height: 72)""");

  f.writeAsStringSync(s);

  // 4) widgets.dart: a missing picture shows nothing instead of red text
  var t = w.readAsStringSync().replaceAll('\r\n', '\n');
  if (!t.contains('Widget safeImage(')) {
    t = t.replaceAll('Image.asset(', 'safeImage(');
    t += r"""

// Shows the picture, or nothing at all if the file is missing.
Widget safeImage(String path,
    {double? width, double? height, BoxFit? fit}) {
  return Image.asset(
    path,
    width: width,
    height: height,
    fit: fit,
    errorBuilder: (_, __, ___) => SizedBox(width: width, height: height),
  );
}
""";
    w.writeAsStringSync(t);
    ok++;
  }

  print('Done. $ok edits applied.');
  if (failed.isNotEmpty) print('Could not apply: ${failed.join(', ')}');
}
