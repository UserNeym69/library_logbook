import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const LibraryApp());

// ---------------------------------------------------------------------------
// Settings (change these if your school's rules change)
// ---------------------------------------------------------------------------

const String idPrefix = 'HY202500'; // ID = prefix + 3 digits, e.g. HY202500001
final int idLength = idPrefix.length + 3;
const int loanDays = 7; // a book is "overdue" after this many days
const String shs = 'Senior High';
const String collegeLevel = 'College';

// Senior High strands
const List<String> strands = ['STEM', 'ABM', 'HUMSS', 'ICT', 'HE'];

// Senior High shifts
const String shiftMorning = 'Morning shift (6:00 AM - 12:00 PM)';
const String shiftMidday = 'Mid-day shift (9:00 AM - 2:30 PM)';
const String shiftAfternoon = 'Afternoon shift (12:00 PM - 6:45 PM)';

// Which shift each grade + strand is allowed to have.
// An empty list means no shift has been set for that combination yet.
List<String> allowedShifts(String grade, String strand) {
  if (grade == '12') {
    if (['HUMSS', 'STEM', 'ABM'].contains(strand)) return [shiftMorning];
    if (['ICT', 'HE'].contains(strand)) return [shiftAfternoon];
  }
  if (grade == '11') {
    if (['ICT', 'STEM', 'ABM', 'HE', 'HUMSS'].contains(strand)) {
      return [shiftMidday];
    }
  }
  return [];
}

// If only one shift is allowed, pick it automatically.
String autoShift(String grade, String strand) {
  final a = allowedShifts(grade, strand);
  return a.length == 1 ? a.first : '';
}

// Colleges (for college students)
const List<String> colleges = [
  'College of Arts & Sciences',
  'College of Business & Accountancy',
  'College of Computer Studies',
  'College of Teacher Education',
  'College of Criminology & Administration',
  'College of Engineering',
  'College of Health Sciences',
  'International School of Hospitality and Tourism Management',
];

// Courses per college (from the official ICCT Colleges program list).
// Students can only pick from these, so nobody can type a made-up course.
const Map<String, List<String>> collegeCourses = {
  'College of Arts & Sciences': [
    'ABCom - Bachelor of Arts in Communication (Masscom)',
    'ABEng - Bachelor of Arts in English',
    'BSM - Bachelor of Science in Mathematics',
    'BSP - Bachelor of Science in Psychology',
  ],
  'College of Business & Accountancy': [
    'ABA - Associate in Business Administration',
    'BSAIS - Bachelor of Science in Accounting Information System',
    'BSA - Bachelor of Science in Accountancy',
    'BSMA - Bachelor of Science in Management Accounting',
    'BSREM - Bachelor of Science in Real Estate Management',
    'BSIA - Bachelor of Science in Internal Auditing',
    'BSLM - Bachelor of Science in Legal Management',
    'BSBA - Bachelor of Science in Business Administration, Major in Marketing Management',
    'BSBA - Bachelor of Science in Business Administration, Major in Financial Management',
    'BSBA - Bachelor of Science in Business Administration, Major in Operations Management',
    'BSBA - Bachelor of Science in Business Administration, Major in Human Resources Management',
    'BSBA - Bachelor of Science in Business Administration, Major in Business Economics',
  ],
  'College of Computer Studies': [
    'ACT - Associate in Computer Technology',
    'BSCS - Bachelor of Science in Computer Science',
    'BSIT - Bachelor of Science in Information Technology',
    'BSIS - Bachelor of Science in Information System',
  ],
  'College of Teacher Education': [
    'BECEd - Bachelor in Early Childhood Education',
    'BELEMEd - Bachelor in Elementary Education',
    'BSEd - Bachelor in Secondary Education, Major in Information Technology',
    'BSEd - Bachelor in Secondary Education, Major in English',
    'BSEd - Bachelor in Secondary Education, Major in Filipino',
    'BSEd - Bachelor in Secondary Education, Major in Mathematics',
    'BSEd - Bachelor in Secondary Education, Major in Science',
    'BTVTEd - Bachelor in Technical Vocational Teacher Education, Major in Home Economics and Livelihood Education (HELE)',
    'BTVTEd - Bachelor in Technical Vocational Teacher Education, Major in Computer Programming',
    'CTP - Certificate in Teaching Program',
  ],
  'College of Criminology & Administration': [
    'BSC - Bachelor of Science in Criminology',
    'BSISM - Bachelor of Science in Industrial Security Management',
    'BPA - Bachelor in Public Administration',
  ],
  'College of Engineering': [
    'BSCE - Bachelor of Science in Computer Engineering',
    'BSELE - Bachelor of Science in Electronics Engineering',
  ],
  'College of Health Sciences': [
    'BSMedTech - Bachelor of Science in Medical Technology',
    'BSN - Bachelor of Science in Nursing',
    'BSRadTech - Bachelor of Science in Radiologic Technology',
    'DHWA - Diploma in Health Care & Wellness Associate',
  ],
  'International School of Hospitality and Tourism Management': [
    'BSHM - Bachelor of Science in Hospitality Management',
    'BSTM - Bachelor of Science in Tourism Management',
    'DHRM1 - Diploma in Hotel & Restaurant Management-1',
    'DHRM2 - Diploma in Hotel & Restaurant Management-2',
  ],
};

bool isValidId(String id) => RegExp('^$idPrefix[0-9]{3}\$').hasMatch(id);

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class Student {
  final String id, name, level, section, grade, strand, shift, college, course;

  const Student({
    required this.id,
    required this.name,
    this.level = shs,
    this.section = '',
    this.grade = '',
    this.strand = '',
    this.shift = '',
    this.college = '',
    this.course = '',
  });

  bool get isCollege => level == collegeLevel;

  // Text shown under the student's name
  String get details {
    if (isCollege) {
      return course.isEmpty ? college : '$course  •  $college';
    }
    final base = 'Grade $grade  •  $strand  •  Section $section';
    return shift.isEmpty ? base : '$base  •  $shift';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'level': level,
        'section': section,
        'grade': grade,
        'strand': strand,
        'shift': shift,
        'college': college,
        'course': course,
      };

  factory Student.fromJson(Map<String, dynamic> j) => Student(
        id: j['id'] as String,
        name: j['name'] as String,
        level: j['level'] as String? ?? shs,
        section: j['section'] as String? ?? '',
        grade: j['grade'] as String? ?? '',
        strand: j['strand'] as String? ?? '',
        shift: j['shift'] as String? ?? '',
        college: j['college'] as String? ?? '',
        course: j['course'] as String? ?? '',
      );
}

class LogEntry {
  final Student student;
  final String book;
  final DateTime time;
  DateTime? returnedAt;

  LogEntry({
    required this.student,
    required this.book,
    required this.time,
    this.returnedAt,
  });

  bool get returned => returnedAt != null;
  DateTime get dueDate => time.add(const Duration(days: loanDays));
  bool get isOverdue => !returned && DateTime.now().isAfter(dueDate);

  Map<String, dynamic> toJson() => {
        'student': student.toJson(),
        'book': book,
        'time': time.toIso8601String(),
        'returnedAt': returnedAt?.toIso8601String(),
      };

  factory LogEntry.fromJson(Map<String, dynamic> j) => LogEntry(
        student: Student.fromJson(j['student'] as Map<String, dynamic>),
        book: j['book'] as String,
        time: DateTime.parse(j['time'] as String),
        returnedAt: j['returnedAt'] == null
            ? null
            : DateTime.parse(j['returnedAt'] as String),
      );
}

String formatDateTime(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  final ampm = d.hour >= 12 ? 'PM' : 'AM';
  return '${months[d.month - 1]} ${d.day}, ${d.year}  •  $hour:$minute $ampm';
}

// NOTE: no "const" on the list, so students can be added to it later.
List<Student> sampleStudents() => [
      Student(id: '${idPrefix}001', name: 'Juan Dela Cruz', section: 'A', grade: '11', strand: 'STEM'),
      Student(id: '${idPrefix}002', name: 'Maria Santos', section: 'B', grade: '12', strand: 'ABM'),
      Student(id: '${idPrefix}003', name: 'Pedro Reyes', section: 'A', grade: '11', strand: 'HUMSS'),
      Student(id: '${idPrefix}004', name: 'Ana Lopez', level: collegeLevel, college: 'College of Computer Studies', course: 'BSIT - Bachelor of Science in Information Technology'),
    ];

Future<bool> confirm(BuildContext context, String title, String message) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return r ?? false;
}

// Add / edit student dialog (Senior High or College, with ID format check)
Future<Student?> showStudentDialog(BuildContext context, {Student? existing}) {
  final idCtrl = TextEditingController(text: existing?.id ?? idPrefix);
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final sectionCtrl = TextEditingController(text: existing?.section ?? '');
  String level = existing?.level ?? shs;
  String grade =
      (existing != null && existing.grade.isNotEmpty) ? existing.grade : '11';
  String strand = (existing != null && existing.strand.isNotEmpty)
      ? existing.strand
      : strands.first;
  String shift = (existing != null && existing.shift.isNotEmpty)
      ? existing.shift
      : autoShift(grade, strand);
  String college = existing?.college ?? '';
  String course = existing?.course ?? '';
  String? error;

  return showDialog<Student>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: Text(existing == null ? 'Add student' : 'Edit student'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: shs, label: Text('Senior High')),
                    ButtonSegment(value: collegeLevel, label: Text('College')),
                  ],
                  selected: {level},
                  onSelectionChanged: (v) => setLocal(() => level = v.first),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: idCtrl,
                  enabled: existing == null,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [LengthLimitingTextInputFormatter(idLength)],
                  decoration: InputDecoration(
                    labelText: 'Student ID',
                    helperText: 'Format: $idPrefix + 3 digits',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                if (level == shs) ...[
                  TextField(
                    controller: sectionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Section',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Grade'),
                  const SizedBox(height: 4),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: '11', label: Text('Grade 11')),
                      ButtonSegment(value: '12', label: Text('Grade 12')),
                    ],
                    selected: {grade},
                    onSelectionChanged: (v) => setLocal(() {
                      grade = v.first;
                      shift = autoShift(grade, strand);
                    }),
                  ),
                  const SizedBox(height: 16),
                  const Text('Strand'),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final st in strands)
                        ChoiceChip(
                          label: Text(st),
                          selected: strand == st,
                          onSelected: (_) => setLocal(() {
                            strand = st;
                            shift = autoShift(grade, strand);
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Shift'),
                  const SizedBox(height: 4),
                  if (allowedShifts(grade, strand).isEmpty)
                    const Text(
                      'No shift has been set for this grade and strand yet.',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final sh in allowedShifts(grade, strand))
                          ChoiceChip(
                            label: Text(sh),
                            selected: shift == sh,
                            onSelected: (_) => setLocal(() => shift = sh),
                          ),
                      ],
                    ),
                ] else ...[
                  const Text('College'),
                  const SizedBox(height: 4),
                  if (college.isEmpty) ...[
                    for (final c in colleges)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.radio_button_unchecked),
                        title: Text(c),
                        onTap: () => setLocal(() {
                          college = c;
                          course = '';
                        }),
                      ),
                  ] else ...[
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      selected: true,
                      leading: const Icon(Icons.radio_button_checked),
                      title: Text(college),
                      trailing: TextButton(
                        onPressed: () => setLocal(() {
                          college = '';
                          course = '';
                        }),
                        child: const Text('Change'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Course / Program'),
                    const SizedBox(height: 4),
                    for (final c in (collegeCourses[college] ?? const <String>[]))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        selected: course == c,
                        leading: Icon(course == c
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked),
                        title: Text(c),
                        onTap: () => setLocal(() => course = c),
                      ),
                  ],
                ],
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error!,
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final id = idCtrl.text.trim().toUpperCase();
              final name = nameCtrl.text.trim();
              final section = sectionCtrl.text.trim();
              if (!isValidId(id)) {
                setLocal(() => error =
                    'ID must look like ${idPrefix}001 ($idPrefix + 3 digits).');
                return;
              }
              if (name.isEmpty) {
                setLocal(() => error = 'Please enter the full name.');
                return;
              }
              if (level == shs && section.isEmpty) {
                setLocal(() => error = 'Please enter the section.');
                return;
              }
              if (level == shs) {
                final allowed = allowedShifts(grade, strand);
                if (allowed.isNotEmpty && !allowed.contains(shift)) {
                  setLocal(() => error =
                      'Please choose a shift that matches Grade $grade $strand.');
                  return;
                }
              }
              if (level == collegeLevel && college.isEmpty) {
                setLocal(() => error = 'Please choose a college.');
                return;
              }
              if (level == collegeLevel && course.isEmpty) {
                setLocal(() => error = 'Please choose a course.');
                return;
              }
              Navigator.pop(
                ctx,
                level == shs
                    ? Student(
                        id: id,
                        name: name,
                        level: shs,
                        section: section,
                        grade: grade,
                        strand: strand,
                        shift: shift,
                      )
                    : Student(
                        id: id,
                        name: name,
                        level: collegeLevel,
                        college: college,
                        course: course,
                      ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// App
// ---------------------------------------------------------------------------

class LibraryApp extends StatelessWidget {
  const LibraryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Library Logbook',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Student> students = [];
  List<LogEntry> logs = [];
  int tab = 0;
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString('students_v2');
    final l = p.getString('logs_v2');
    setState(() {
      students = s == null
          ? sampleStudents()
          : (jsonDecode(s) as List)
              .map((e) => Student.fromJson(e as Map<String, dynamic>))
              .toList();
      logs = l == null
          ? []
          : (jsonDecode(l) as List)
              .map((e) => LogEntry.fromJson(e as Map<String, dynamic>))
              .toList();
      loaded = true;
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        'students_v2', jsonEncode(students.map((e) => e.toJson()).toList()));
    await p.setString(
        'logs_v2', jsonEncode(logs.map((e) => e.toJson()).toList()));
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---- logs ----

  void _addLog(Student s, String book) {
    setState(() {
      logs.insert(0, LogEntry(student: s, book: book, time: DateTime.now()));
    });
    _save();
    _snack('Logged: ${s.name} borrowed "$book"');
  }

  void _toggleReturned(LogEntry e, bool value) {
    setState(() => e.returnedAt = value ? DateTime.now() : null);
    _save();
  }

  Future<void> _deleteLog(LogEntry e) async {
    final ok = await confirm(
        context, 'Delete record?', '"${e.book}" borrowed by ${e.student.name}');
    if (!ok || !mounted) return;
    setState(() => logs.remove(e));
    _save();
  }

  // ---- students ----

  Future<void> _addStudent() async {
    final result = await showStudentDialog(context);
    if (result == null || !mounted) return;
    if (students.any((s) => s.id == result.id)) {
      _snack('That Student ID already exists.');
      return;
    }
    setState(() => students.add(result));
    _save();
    _snack('Added ${result.name}');
  }

  Future<void> _editStudent(Student old) async {
    final result = await showStudentDialog(context, existing: old);
    if (result == null || !mounted) return;
    setState(() {
      final i = students.indexWhere((s) => s.id == old.id);
      if (i != -1) students[i] = result;
    });
    _save();
  }

  Future<void> _deleteStudent(Student s) async {
    final ok = await confirm(context, 'Delete student?',
        '${s.name} (${s.id}) will be removed. Their past records stay in the logbook.');
    if (!ok || !mounted) return;
    setState(() => students.removeWhere((x) => x.id == s.id));
    _save();
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pages = [
      BorrowTab(students: students, logs: logs, onLog: _addLog),
      LogbookTab(
        logs: logs,
        onReturned: _toggleReturned,
        onDelete: _deleteLog,
        onMessage: _snack,
      ),
      StudentsTab(
        students: students,
        onEdit: _editStudent,
        onDelete: _deleteStudent,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library Logbook'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: pages[tab],
      floatingActionButton: tab == 2
          ? FloatingActionButton.extended(
              onPressed: _addStudent,
              icon: const Icon(Icons.person_add),
              label: const Text('Add student'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.edit_note), label: 'Borrow'),
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'Logbook'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Students'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 1: Borrow
// ---------------------------------------------------------------------------

Widget statCard(BuildContext context, String label, int value, {Color? color}) {
  return Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(
              '$value',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: color),
            ),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    ),
  );
}

class BorrowTab extends StatefulWidget {
  final List<Student> students;
  final List<LogEntry> logs;
  final void Function(Student, String) onLog;

  const BorrowTab({
    super.key,
    required this.students,
    required this.logs,
    required this.onLog,
  });

  @override
  State<BorrowTab> createState() => _BorrowTabState();
}

class _BorrowTabState extends State<BorrowTab> {
  final idCtrl = TextEditingController();
  final bookCtrl = TextEditingController();
  final idFocus = FocusNode();
  final bookFocus = FocusNode();

  String get typedId => idCtrl.text.trim().toUpperCase();

  Student? get found {
    final id = typedId;
    if (!isValidId(id)) return null;
    for (final s in widget.students) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  void dispose() {
    idCtrl.dispose();
    bookCtrl.dispose();
    idFocus.dispose();
    bookFocus.dispose();
    super.dispose();
  }

  void _submit() {
    final s = found;
    final book = bookCtrl.text.trim();
    if (s == null || book.isEmpty) return;
    widget.onLog(s, book);
    idCtrl.clear();
    bookCtrl.clear();
    setState(() {});
    idFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final s = found;
    final id = typedId;
    final scheme = Theme.of(context).colorScheme;
    final canLog = s != null && bookCtrl.text.trim().isNotEmpty;

    final borrowedNow = widget.logs.where((e) => !e.returned).length;
    final overdue = widget.logs.where((e) => e.isOverdue).length;

    String? problem;
    if (id.length >= idLength && !isValidId(id)) {
      problem = 'Invalid ID. It must look like ${idPrefix}001.';
    } else if (isValidId(id) && s == null) {
      problem = 'No student found with this ID. Add them in the Students tab.';
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            statCard(context, 'Borrowed now', borrowedNow),
            statCard(context, 'Overdue', overdue,
                color: overdue > 0 ? scheme.error : null),
            statCard(context, 'Total records', widget.logs.length),
          ],
        ),
        const SizedBox(height: 8),
        Text('Log a borrowed book',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text(
            'Scan the library ID (or type the ID number), then enter the book.'),
        const SizedBox(height: 16),
        TextField(
          controller: idCtrl,
          focusNode: idFocus,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [LengthLimitingTextInputFormatter(idLength)],
          decoration: InputDecoration(
            labelText: 'Student ID',
            helperText: 'Format: $idPrefix + 3 digits',
            prefixIcon: const Icon(Icons.qr_code_scanner),
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) {
            if (found != null) {
              bookFocus.requestFocus();
            } else {
              idFocus.requestFocus();
            }
          },
        ),
        const SizedBox(height: 12),
        if (problem != null)
          Card(
            color: scheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(problem),
            ),
          ),
        if (s != null)
          Card(
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                      s.details),
                  const SizedBox(height: 4),
                  Text(
                    'Currently borrowing: '
                    '${widget.logs.where((e) => e.student.id == s.id && !e.returned).length} book(s)',
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: bookCtrl,
          focusNode: bookFocus,
          decoration: const InputDecoration(
            labelText: 'Book title',
            prefixIcon: Icon(Icons.book),
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: canLog ? _submit : null,
          icon: const Icon(Icons.check),
          label: const Text('Log it'),
        ),
        const SizedBox(height: 8),
        Text(
          'Date and time are saved automatically. Books are due after $loanDays days.',
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2: Logbook
// ---------------------------------------------------------------------------

class LogbookTab extends StatefulWidget {
  final List<LogEntry> logs;
  final void Function(LogEntry, bool) onReturned;
  final void Function(LogEntry) onDelete;
  final void Function(String) onMessage;

  const LogbookTab({
    super.key,
    required this.logs,
    required this.onReturned,
    required this.onDelete,
    required this.onMessage,
  });

  @override
  State<LogbookTab> createState() => _LogbookTabState();
}

class _LogbookTabState extends State<LogbookTab> {
  String query = '';
  String status = 'All';

  bool _matchStatus(LogEntry e) {
    switch (status) {
      case 'Borrowed':
        return !e.returned;
      case 'Overdue':
        return e.isOverdue;
      case 'Returned':
        return e.returned;
      default:
        return true;
    }
  }

  Future<void> _copyCsv(List<LogEntry> items) async {
    String q(String s) => '"${s.replaceAll('"', '""')}"';
    final rows = <String>[
      'Student ID,Name,Level,Grade,Strand,Section,Shift,College,Course,Book,Borrowed,Returned,Status'
    ];
    for (final e in items) {
      rows.add([
        q(e.student.id),
        q(e.student.name),
        q(e.student.level),
        q(e.student.grade),
        q(e.student.strand),
        q(e.student.section),
        q(e.student.shift),
        q(e.student.college),
        q(e.student.course),
        q(e.book),
        q(formatDateTime(e.time)),
        q(e.returnedAt == null ? '' : formatDateTime(e.returnedAt!)),
        q(e.returned ? 'Returned' : (e.isOverdue ? 'Overdue' : 'Borrowed')),
      ].join(','));
    }
    await Clipboard.setData(ClipboardData(text: rows.join('\n')));
    widget.onMessage(
        'Copied ${items.length} record(s). Paste them into Excel or Google Sheets.');
  }

  @override
  Widget build(BuildContext context) {
    final q = query.toLowerCase();
    final shown = widget.logs.where((e) {
      final matchText = e.book.toLowerCase().contains(q) ||
          e.student.name.toLowerCase().contains(q) ||
          e.student.id.toLowerCase().contains(q);
      return matchText && _matchStatus(e);
    }).toList();
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search by book, name, or ID',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => query = v),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Copy shown records as CSV (for Excel)',
                onPressed: shown.isEmpty ? null : () => _copyCsv(shown),
                icon: const Icon(Icons.copy_all),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final s in ['All', 'Borrowed', 'Overdue', 'Returned'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(s),
                    selected: status == s,
                    onSelected: (_) => setState(() => status = s),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? const Center(child: Text('No records found.'))
              : ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (context, i) {
                    final e = shown[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: ListTile(
                        onLongPress: () => widget.onDelete(e),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.book,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (e.isOverdue)
                              Text(
                                'OVERDUE',
                                style: TextStyle(
                                  color: scheme.error,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.student.name),
                            Text(
                                '${e.student.id}  •  ${e.student.details}'),
                            Text('Borrowed: ${formatDateTime(e.time)}'),
                            Text(
                              e.returned
                                  ? 'Returned: ${formatDateTime(e.returnedAt!)}'
                                  : 'Due: ${formatDateTime(e.dueDate)}',
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: e.returned,
                              onChanged: (v) =>
                                  widget.onReturned(e, v ?? false),
                            ),
                            const Text('Returned',
                                style: TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            'Tip: press and hold a record to delete it.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 3: Students
// ---------------------------------------------------------------------------

class StudentsTab extends StatefulWidget {
  final List<Student> students;
  final void Function(Student) onEdit;
  final void Function(Student) onDelete;

  const StudentsTab({
    super.key,
    required this.students,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> {
  String query = '';
  String levelFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final q = query.toLowerCase();
    final shown = widget.students.where((s) {
      final matchText = s.name.toLowerCase().contains(q) ||
          s.id.toLowerCase().contains(q) ||
          s.section.toLowerCase().contains(q) ||
          s.strand.toLowerCase().contains(q) ||
          s.college.toLowerCase().contains(q) ||
          s.course.toLowerCase().contains(q);
      return matchText && (levelFilter == 'All' || s.level == levelFilter);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search ${widget.students.length} student(s)',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => query = v),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final l in ['All', shs, collegeLevel])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(l),
                    selected: levelFilter == l,
                    onSelected: (_) => setState(() => levelFilter = l),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? const Center(child: Text('No students found.'))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: shown.length,
                  itemBuilder: (context, i) {
                    final s = shown[i];
                    return ListTile(
                      leading: CircleAvatar(
                          child: Text(s.name.isEmpty ? '?' : s.name[0])),
                      title: Text(s.name),
                      subtitle: Text(
                          '${s.id}  •  ${s.details}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit),
                            onPressed: () => widget.onEdit(s),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => widget.onDelete(s),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}