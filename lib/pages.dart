import 'package:flutter/material.dart';

import 'main.dart';
import 'search.dart';
import 'widgets.dart';

// Categories, subjects, and academic tracks a book can belong to.
const List<String> bookCategories = [
  'Fiction',
  'Filipino Literature',
  'Science',
  'Mathematics',
  'Technology',
  'Business',
  'Health',
  'History & Social Studies',
  'Reference',
  'Academic - STEM',
  'Academic - ABM',
  'Academic - HUMSS',
  'Academic - ICT',
  'Academic - HE',
  'General',
];

Widget _section(BuildContext context, String title, Widget child) => Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );

// ---------------------------------------------------------------------------
// Explore books: browse the catalog by category / subject / track
// ---------------------------------------------------------------------------
class ExplorePage extends StatefulWidget {
  final List<Book> books;
  final List<LogEntry> logs;
  const ExplorePage({super.key, required this.books, required this.logs});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  String cat = 'All';
  String query = '';

  @override
  Widget build(BuildContext context) {
    final books = widget.books;
    final cats = [
      'All',
      for (final c in bookCategories)
        if (books.any((b) => b.category == c)) c,
      if (books.any((b) => b.category.isEmpty)) 'Uncategorized',
    ];
    int count(String c) => c == 'All'
        ? books.length
        : books
            .where((b) => c == 'Uncategorized' ? b.category.isEmpty : b.category == c)
            .length;
    final inCat = books.where((b) =>
        cat == 'All' ||
        (cat == 'Uncategorized' ? b.category.isEmpty : b.category == cat));
    final shown = fuzzyFilter(query, inCat, (b) => '${b.title} ${b.author} ${b.category}');

    return Scaffold(
      appBar: AppBar(title: const Text('Explore books')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SmartSearch(
              hint: 'Search by title, author, or subject',
              suggestions: [for (final b in books) b.title],
              onChanged: (v) => setState(() => query = v),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final c in cats)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('$c (${count(c)})'),
                      selected: cat == c,
                      onSelected: (_) => setState(() => cat = c),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? const EmptyState(
                    icon: Icons.explore_outlined,
                    title: 'No books here',
                    message:
                        'Add a category when you add or edit a book, then it will show up in this list.')
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    itemCount: shown.length,
                    itemBuilder: (context, i) {
                      final b = shown[i];
                      final avail = b.copies - borrowedCopies(widget.logs, b);
                      return ListTile(
                        onTap: () => showBookHistory(context, b, widget.logs),
                        leading: const CircleAvatar(child: Icon(Icons.book)),
                        title: Text(b.title),
                        subtitle: Text(
                            '${b.author.isEmpty ? 'Unknown author' : b.author}'
                            '  •  ${b.category.isEmpty ? 'Uncategorized' : b.category}\n'
                            'Available: $avail of ${b.copies}'),
                        isThreeLine: true,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Student history: borrowing now + past borrowing
// ---------------------------------------------------------------------------
class StudentHistoryPage extends StatefulWidget {
  final List<Student> students;
  final List<LogEntry> logs;
  const StudentHistoryPage(
      {super.key, required this.students, required this.logs});

  @override
  State<StudentHistoryPage> createState() => _StudentHistoryPageState();
}

class _StudentHistoryPageState extends State<StudentHistoryPage> {
  String query = '';
  Student? picked;

  Widget _record(LogEntry e) => Card(
        child: ListTile(
          title: Text(e.book, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('Borrowed: ${formatDateTime(e.time)}\n'
              '${e.returned ? 'Returned: ${formatDateTime(e.returnedAt!)}' : 'Due: ${formatDateTime(e.dueDate)}'}'),
          isThreeLine: true,
          trailing: e.isOverdue
              ? Text('OVERDUE',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w800,
                      fontSize: 12))
              : null,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = picked;
    final mine = s == null
        ? <LogEntry>[]
        : (widget.logs.where((e) => e.student.id == s.id).toList()
          ..sort((a, b) => b.time.compareTo(a.time)));
    final active = mine.where((e) => !e.returned).toList();
    final past = mine.where((e) => e.returned).toList();
    final results = query.trim().isEmpty
        ? <Student>[]
        : fuzzyFilter(query, widget.students, (x) => '${x.name} ${x.id}').take(6).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Student history')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search a student by name or ID',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() {
              query = v;
              picked = null;
            }),
          ),
          const SizedBox(height: 4),
          const Text('Only signed-in library staff can see this page.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          if (s == null)
            for (final r in results)
              ListTile(
                leading: CircleAvatar(child: Text(r.name.isEmpty ? '?' : r.name[0])),
                title: Text(r.name),
                subtitle: Text('${r.id}  •  ${r.details}'),
                onTap: () => setState(() => picked = r),
              ),
          if (s == null && results.isEmpty)
            const EmptyState(
                icon: Icons.person_search_outlined,
                title: 'Find a student',
                message: 'Type a name or ID to see what they borrowed.'),
          if (s != null) ...[
            Card(
              child: ListTile(
                title: Text(s.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${s.id}\n${s.details}'),
                isThreeLine: true,
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              statCard(context, 'Borrowing now', active.length),
              statCard(context, 'Returned', past.length),
              statCard(context, 'Total', mine.length),
            ]),
            const SizedBox(height: 8),
            Text('Borrowing now', style: Theme.of(context).textTheme.titleMedium),
            if (active.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Nothing right now.')),
            for (final e in active) _record(e),
            const SizedBox(height: 12),
            Text('Past borrowing', style: Theme.of(context).textTheme.titleMedium),
            if (past.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('No returned books yet.')),
            for (final e in past) _record(e),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reports: borrowing trends, most / least borrowed, categories
// ---------------------------------------------------------------------------
class _Bars extends StatelessWidget {
  final List<MapEntry<String, int>> items;
  const _Bars(this.items);

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const Text('Not enough data yet.');
    final scheme = Theme.of(context).colorScheme;
    final top = items.map((e) => e.value).fold<int>(1, (a, b) => a > b ? a : b);
    return Column(
      children: [
        for (final e in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(e.key, overflow: TextOverflow.ellipsis)),
                  Text('${e.value}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: e.value / top),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                    builder: (_, v, __) => LinearProgressIndicator(
                      value: v,
                      minHeight: 8,
                      color: scheme.primary,
                      backgroundColor: scheme.primary.withAlpha(30),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class ReportsPage extends StatelessWidget {
  final List<Book> books;
  final List<LogEntry> logs;
  const ReportsPage({super.key, required this.books, required this.logs});

  List<MapEntry<String, int>> _sorted(Map<String, int> m, {bool desc = true, int take = 5}) {
    final l = m.entries.toList()
      ..sort((a, b) => desc ? b.value.compareTo(a.value) : a.value.compareTo(b.value));
    return l.take(take).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final active = logs.where((e) => !e.returned).length;
    final overdue = logs.where((e) => e.isOverdue).length;
    final returned = logs.where((e) => e.returned).toList();
    final avgDays = returned.isEmpty
        ? 0.0
        : returned.map((e) => e.returnedAt!.difference(e.time).inHours / 24).reduce((a, b) => a + b) /
            returned.length;

    final perTitle = <String, int>{};
    for (final e in logs) {
      perTitle[e.book] = (perTitle[e.book] ?? 0) + 1;
    }
    final perBookId = <String, int>{for (final b in books) b.id: 0};
    for (final e in logs) {
      if (perBookId.containsKey(e.bookId)) perBookId[e.bookId] = perBookId[e.bookId]! + 1;
    }
    final least = <String, int>{for (final b in books) b.title: perBookId[b.id] ?? 0};
    final catOf = {for (final b in books) b.id: b.category};
    final perCat = <String, int>{};
    for (final e in logs) {
      final c = (catOf[e.bookId] ?? '').isEmpty ? 'Uncategorized' : catOf[e.bookId]!;
      perCat[c] = (perCat[c] ?? 0) + 1;
    }
    final perGroup = <String, int>{};
    for (final e in logs) {
      final g = e.student.isCollege ? e.student.college : 'Senior High - ${e.student.strand}';
      perGroup[g] = (perGroup[g] ?? 0) + 1;
    }
    final days = [
      for (var i = 6; i >= 0; i--) DateTime(now.year, now.month, now.day - i)
    ];
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final perDay = [
      for (final d in days)
        logs.where((e) => e.time.year == d.year && e.time.month == d.month && e.time.day == d.day).length
    ];
    final maxDay = perDay.fold<int>(1, (a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: logs.isEmpty
          ? const EmptyState(
              icon: Icons.insights_outlined,
              title: 'No data yet',
              message: 'Reports will appear after books are logged on the Borrow tab.')
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(children: [
                  statCard(context, 'Total borrowed', logs.length),
                  statCard(context, 'Borrowed now', active),
                  statCard(context, 'Overdue', overdue,
                      color: overdue > 0 ? scheme.error : null),
                ]),
                const SizedBox(height: 4),
                Text(
                    'Average time before return: ${avgDays.toStringAsFixed(1)} day(s)  •  '
                    'Return rate: ${(returned.length * 100 / logs.length).round()}%',
                    style: TextStyle(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 12),
                _section(
                  context,
                  'Borrowed in the last 7 days',
                  SizedBox(
                    height: 130,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < 7; i++)
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text('${perDay[i]}', style: const TextStyle(fontSize: 12)),
                                const SizedBox(height: 4),
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: perDay[i] / maxDay),
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeOut,
                                  builder: (_, v, __) => Container(
                                    height: 80 * v + 2,
                                    margin: const EdgeInsets.symmetric(horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: scheme.primary,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(names[days[i].weekday - 1], style: const TextStyle(fontSize: 11)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                _section(context, 'Most borrowed books', _Bars(_sorted(perTitle))),
                _section(context, 'Least borrowed books', _Bars(_sorted(least, desc: false))),
                _section(context, 'Popular categories', _Bars(_sorted(perCat))),
                _section(context, 'Who borrows the most', _Bars(_sorted(perGroup))),
              ],
            ),
    );
  }
}
