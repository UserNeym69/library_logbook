// Run from the project folder:  dart patch6.dart
import 'dart:io';

void main() {
  final f = File('lib/main.dart');
  final d = File('lib/settings.dart');
  if (!f.existsSync() || !d.existsSync()) {
    print('lib/main.dart or lib/settings.dart not found. Run this from the project folder.');
    return;
  }
  File('lib/main.dart.bak6').writeAsStringSync(f.readAsStringSync());
  var s = f.readAsStringSync().replaceAll('\r\n', '\n');
  var t = d.readAsStringSync().replaceAll('\r\n', '\n');
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

  // settings.dart: the menu can hold extra items
  if (t.contains('const AppDrawer({super.key});')) {
    t = t
        .replaceFirst('class AppDrawer extends StatelessWidget {\n  const AppDrawer({super.key});',
            'class AppDrawer extends StatelessWidget {\n  final List<Widget> extra;\n  const AppDrawer({super.key, this.extra = const []});')
        .replaceFirst('            const Divider(),\n            ListTile(\n              leading: const Icon(Icons.settings_outlined),',
            '            const Divider(),\n            ...extra,\n            const Divider(),\n            ListTile(\n              leading: const Icon(Icons.settings_outlined),');
    d.writeAsStringSync(t);
    ok++;
  } else {
    failed.add('menu items');
  }

  edit('import pages', r"""import 'settings.dart';""", r"""import 'pages.dart';
import 'settings.dart';""");

  // Book gets a category
  edit('book field', r"""  final String id, title, author, bookNo;
  final int copies;""", r"""  final String id, title, author, bookNo, category;
  final int copies;""");
  edit('book ctor', r"""    this.bookNo = '',
    this.copies = 1,
  });""", r"""    this.bookNo = '',
    this.category = '',
    this.copies = 1,
  });""");
  edit('book toJson', r"""        'copies': copies,
      };""", r"""        'copies': copies,
        'category': category,
      };""");
  edit('book fromJson', r"""        copies: (j['copies'] as num?)?.toInt() ?? 1,
      );""", r"""        copies: (j['copies'] as num?)?.toInt() ?? 1,
        category: j['category'] as String? ?? '',
      );""");
  edit('import column', r"""      bookNo: cells.length > 3 ? cells[3] : '',
    ));""", r"""      bookNo: cells.length > 3 ? cells[3] : '',
      category: cells.length > 4 ? cells[4] : '',
    ));""");
  edit('import hint', r"""hintText: 'Title, Author, Copies, Book number',""",
      r"""hintText: 'Title, Author, Copies, Book number, Category',""");

  // Category picker in the Add / Edit book window
  edit('dialog var', r"""  String? error;

  return showDialog<Book>(""", r"""  String category = existing?.category ?? '';
  String? error;

  return showDialog<Book>(""");
  edit('dialog picker', r"""                TextField(
                  controller: copiesCtrl,""", r"""                DropdownMenu<String>(
                  expandedInsets: EdgeInsets.zero,
                  initialSelection: category.isEmpty ? null : category,
                  label: const Text('Category (subject or track)'),
                  dropdownMenuEntries: [
                    for (final c in bookCategories)
                      DropdownMenuEntry(value: c, label: c),
                  ],
                  onSelected: (v) => category = v ?? '',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: copiesCtrl,""");
  edit('dialog save', r"""                  copies: copies,
                ),""", r"""                  copies: copies,
                  category: category,
                ),""");

  // Burger menu items
  edit('menu items', r"""      drawer: const AppDrawer(),""", r"""      drawer: AppDrawer(extra: [
        ListTile(
          leading: const Icon(Icons.explore_outlined),
          title: const Text('Explore books'),
          onTap: () => _open(ExplorePage(books: books, logs: logs)),
        ),
        ListTile(
          leading: const Icon(Icons.history),
          title: const Text('Student history'),
          onTap: () => _open(StudentHistoryPage(students: students, logs: logs)),
        ),
        ListTile(
          leading: const Icon(Icons.insights_outlined),
          title: const Text('Reports'),
          onTap: () => _open(ReportsPage(books: books, logs: logs)),
        ),
      ]),""");
  edit('open helper', r"""  void _onSettings() {""", r"""  void _open(Widget page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _onSettings() {""");

  f.writeAsStringSync(s);
  print('Done. $ok edits applied.');
  if (failed.isNotEmpty) print('Could not apply: ${failed.join(', ')}');
}
