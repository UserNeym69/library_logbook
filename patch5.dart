// Run from the project folder:  dart patch5.dart
import 'dart:io';

void main() {
  final f = File('lib/main.dart');
  final w = File('lib/widgets.dart');
  if (!f.existsSync() || !w.existsSync()) {
    print('lib/main.dart or lib/widgets.dart not found. Run this from the project folder.');
    return;
  }
  File('lib/main.dart.bak5').writeAsStringSync(f.readAsStringSync());
  var s = f.readAsStringSync().replaceAll('\r\n', '\n');
  var t = w.readAsStringSync().replaceAll('\r\n', '\n');
  var ok = 0;
  final failed = <String>[];

  void editMain(String name, String from, String to) {
    if (s.contains(from)) {
      s = s.replaceFirst(from, to);
      ok++;
    } else {
      failed.add(name);
    }
  }

  void editWidgets(String name, String from, String to) {
    if (t.contains(from)) {
      t = t.replaceFirst(from, to);
      ok++;
    } else {
      failed.add(name);
    }
  }

  // ---- widgets.dart: logo loading bar + campus photo background ----
  editWidgets('widgets import', r"""import 'theme.dart';""", r"""import 'extras.dart';
import 'theme.dart';""");
  editWidgets('loading bar', r"""const Center(child: LogoLoader(size: 110)),""",
      r"""const Center(child: LogoBar()),""");
  editWidgets('background photo', r"""    return ColoredBox(
        color: dark ? const Color(0xFF0E141C) : const Color(0xFFF4F6FA));""",
      r"""    final bg = dark ? const Color(0xFF0E141C) : const Color(0xFFF4F6FA);
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: bg),
        Opacity(
          opacity: .14,
          child: safeImage('assets/images/cainta.jpg', fit: BoxFit.cover),
        ),
      ],
    );""");
  w.writeAsStringSync(t);

  // ---- main.dart ----
  editMain('import extras', r"""import 'settings.dart';""", r"""import 'extras.dart';
import 'settings.dart';""");

  // Skeleton while searching (Logbook, Students, Books)
  const searchCode = r"""
  bool searching = false;
  Timer? _timer;

  void _onSearch(String v) {
    setState(() {
      query = v;
      searching = v.trim().isNotEmpty;
    });
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => searching = false);
    });
  }
""";
  editMain('search state logbook', r"""  String query = '';
  String status = 'All';""", "  String query = '';\n  String status = 'All';\n$searchCode");
  editMain('search state students', r"""  String query = '';
  String levelFilter = 'All';""", "  String query = '';\n  String levelFilter = 'All';\n$searchCode");
  editMain('search state books', r"""  String query = '';

  @override""", "  String query = '';\n$searchCode\n  @override");

  for (var i = 0; i < 3; i++) {
    editMain('search input ${i + 1}', r"""onChanged: (v) => setState(() => query = v),""",
        r"""onChanged: _onSearch,""");
    editMain('search skeleton ${i + 1}', r"""          child: shown.isEmpty
""", r"""          child: searching
              ? const FakeList()
              : shown.isEmpty
""");
  }

  // More life: soft staggered fade-in for list rows
  for (var i = 0; i < 2; i++) {
    editMain('list fade ${i + 1}', r""").animate().fadeIn(duration: 200.ms);""",
        r""").animate(delay: (30 * (i % 10)).ms).fadeIn(duration: 220.ms).slideY(begin: .04, end: 0, duration: 220.ms, curve: Curves.easeOut);""");
  }

  editMain('hero fade', r"""        const HeroBanner(),""",
      r"""        const HeroBanner().animate().fadeIn(duration: 300.ms).slideY(begin: .05, end: 0, duration: 300.ms, curve: Curves.easeOut),""");

  editMain('count up', r"""            Text(
              '$value',
              style:""", r"""            CountUp(
              value: value,
              style:""");

  f.writeAsStringSync(s);
  print('Done. $ok edits applied.');
  if (failed.isNotEmpty) print('Could not apply: ${failed.join(', ')}');
}
