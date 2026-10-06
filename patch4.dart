// Run from the project folder:  dart patch4.dart
import 'dart:io';

void main() {
  final f = File('lib/main.dart');
  if (!f.existsSync()) {
    print('lib/main.dart not found. Run this from the project folder.');
    return;
  }
  File('lib/main.dart.bak4').writeAsStringSync(f.readAsStringSync());
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

  // ---- settings + dark mode ----
  edit('import settings', r"""import 'search.dart';""", r"""import 'search.dart';
import 'settings.dart';""");

  edit('load settings', r"""  runApp(const LibraryApp());""", r"""  await appSettings.load();
  runApp(const LibraryApp());""");

  edit('app start', r"""    return MaterialApp(
      title: 'Library Logbook',""", r"""    return ListenableBuilder(
      listenable: appSettings,
      builder: (context, _) => MaterialApp(
      title: 'Library Logbook',""");

  edit('app theme', r"""      theme: icctTheme(),""", r"""      theme: icctTheme(),
      darkTheme: icctDarkTheme(),
      themeMode: appSettings.themeMode,""");

  edit('app end', r"""      home: useCloud ? const AuthGate() : const HomePage(),
    );""", r"""      home: useCloud ? const AuthGate() : const HomePage(),
      ),
    );""");

  // ---- burger menu (the drawer adds the 3-line icon by itself) ----
  edit('drawer', r"""      appBar: AppBar(""", r"""      drawer: const AppDrawer(),
      appBar: AppBar(""");

  // ---- no gradient / no gold in the top bar ----
  edit('plain top bar', r"""        title: const BrandTitle(),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [deepNavy, navy]),
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(3),
          child: SizedBox(height: 3, width: double.infinity, child: ColoredBox(color: gold)),
        ),""", r"""        title: const BrandTitle(),""");

  edit('stat color', r"""color ?? navy""", r"""color ?? Theme.of(context).colorScheme.primary""");

  // ---- risky action = red, safe action = blue ----
  edit('delete message', r"""      content: Text(message),""",
      r"""      content: Text('$message\n\nThis cannot be undone.'),""");

  edit('delete button', r"""        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),""", r"""        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: danger,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Yes, delete'),
        ),""");

  // ---- search hints ----
  edit('hint logbook', r"""hint: 'Search by book, name, or ID',""",
      r"""hint: 'Search a book title or student name',""");
  edit('hint students', r"""hint: 'Search ${widget.students.length} student(s)',""",
      r"""hint: 'Search by name or student ID',""");
  edit('hint books', r"""hint: 'Search ${widget.books.length} book(s)',""",
      r"""hint: 'Search by title, author, or book number',""");
  edit('hint borrow book', r"""labelText: 'Book (search by title, author, or scan the book number)',""",
      r"""labelText: 'Book',
                hintText: 'Type a title, or scan the book number',""");

  // ---- empty states ----
  edit('empty logbook', r"""const Center(child: Text('No records found.'))""",
      r"""EmptyState(
                  icon: Icons.menu_book_outlined,
                  title: query.isEmpty ? 'No records yet' : 'No matches found',
                  message: query.isEmpty
                      ? 'Books you log on the Borrow tab will show up here.'
                      : 'Check the spelling, or try fewer words.',
                )""");
  edit('empty students', r"""const Center(child: Text('No students found.'))""",
      r"""EmptyState(
                  icon: Icons.people_outline,
                  title: query.isEmpty ? 'No students yet' : 'No matches found',
                  message: query.isEmpty
                      ? 'Tap Add student, or scan a new ID on the Borrow tab.'
                      : 'Check the spelling, or try a student ID.',
                )""");
  edit('empty books', r"""const Center(child: Text('No books yet. Add one or import from Excel.'))""",
      r"""EmptyState(
                  icon: Icons.library_books_outlined,
                  title: query.isEmpty ? 'No books yet' : 'No matches found',
                  message: query.isEmpty
                      ? 'Tap Add book, or import a list from Excel.'
                      : 'Check the spelling, or try the author name.',
                )""");

  // ---- error state with Try again ----
  edit('error flag', r"""  bool tabLoading = false;""", r"""  bool tabLoading = false;
  String? loadError;""");

  edit('listen to settings', r"""    super.initState();
    Future.delayed(""", r"""    super.initState();
    appSettings.addListener(_onSettings);
    Future.delayed(""");

  edit('retry + dispose', r"""  @override
  void dispose() {
    for (final sub in _subs) {""", r"""  void _onSettings() {
    if (mounted) setState(() {});
  }

  void _retry() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    _got.clear();
    setState(() {
      loadError = null;
      loaded = false;
    });
    if (useCloud) {
      _startCloud();
    } else {
      _loadLocal();
    }
  }

  @override
  void dispose() {
    appSettings.removeListener(_onSettings);
    for (final sub in _subs) {""");

  edit('error handler', r"""      setState(() => loaded = true);
      _snack('Online connection problem: $e');""", r"""      final empty = students.isEmpty && books.isEmpty && logs.isEmpty;
      setState(() {
        loaded = true;
        if (empty) {
          loadError =
              'We could not reach the online logbook. Check your internet and try again.';
        }
      });
      if (!empty) _snack('Online connection problem. Showing the last saved data.');""");

  edit('error screen', r"""    if (!loaded || !splashDone) return const LoadingScreen();""",
      r"""    if (!loaded || !splashDone) return const LoadingScreen();
    if (loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const BrandTitle()),
        body: ErrorState(message: loadError!, onRetry: _retry),
      );
    }""");

  // ---- students list: organize by the Settings choice ----
  edit('students sort', r"""      return matchText && (levelFilter == 'All' || s.level == levelFilter);
    }).toList();""", r"""      return matchText && (levelFilter == 'All' || s.level == levelFilter);
    }).toList();
    final order = appSettings.studentOrder;
    String groupOf(Student s) => order == StudentOrder.level
        ? s.level
        : order == StudentOrder.program
            ? (s.isCollege ? s.college : 'Senior High - ${s.strand}')
            : '';
    shown.sort((a, b) {
      final c = groupOf(a).compareTo(groupOf(b));
      return c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });""");

  edit('students tile start', r"""                    final s = shown[i];
                    return ListTile(
                      leading: CircleAvatar(""", r"""                    final s = shown[i];
                    final g = groupOf(s);
                    final showHeader = i == 0 || groupOf(shown[i - 1]) != g;
                    final tile = ListTile(
                      leading: CircleAvatar(""");

  edit('students tile end', r"""                            onPressed: () => widget.onDelete(s),
                          ),
                        ],
                      ),
                    );""", r"""                            onPressed: () => widget.onDelete(s),
                          ),
                        ],
                      ),
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showHeader && g.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                            child: Text(
                              g,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        tile,
                      ],
                    ).animate().fadeIn(duration: 200.ms);""");

  // ---- tiny motion: soft fades only ----
  edit('logbook fade', r""".animate().fadeIn(duration: 300.ms).slideY(begin: .05);""",
      r""".animate().fadeIn(duration: 200.ms);""");
  edit('tab fade', r"""        duration: const Duration(milliseconds: 300),
        child: KeyedSubtree""", r"""        duration: const Duration(milliseconds: 200),
        child: KeyedSubtree""");

  f.writeAsStringSync(s);

  // search.dart: the fill color now comes from the theme (works in dark mode)
  final sf = File('lib/search.dart');
  if (sf.existsSync()) {
    final t = sf.readAsStringSync().replaceAll('\r\n', '\n');
    final n = t.replaceFirst(
        '          filled: true,\n          fillColor: Colors.white,\n', '');
    if (n != t) {
      sf.writeAsStringSync(n);
      ok++;
    } else {
      failed.add('search box color');
    }
  }

  print('Done. $ok edits applied.');
  if (failed.isNotEmpty) print('Could not apply: ${failed.join(', ')}');
}
