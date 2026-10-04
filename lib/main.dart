import 'dart:async';
import 'dart:convert';
import 'dart:math' show Random;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show Supabase, SupabaseClient, AuthState, AuthException;

// ---------------------------------------------------------------------------
// ONLINE MODE (shared database so everyone sees the same logbook)
// Paste your Supabase project URL and anon/publishable key between the quotes.
// Leave them empty to keep everything on this computer only.
// ---------------------------------------------------------------------------
const String supabaseUrl = 'https://ulkztzzfmafslxjdxyle.supabase.co';
const String supabaseAnonKey = 'sb_publishable_UhSSaY0YaWBk-wTT_07ebw_B1AIarJD';
const bool useCloud = supabaseUrl != '' && supabaseAnonKey != '';

SupabaseClient get cloud => Supabase.instance.client;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (useCloud) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }
  runApp(const LibraryApp());
}

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

// A short unique id for books and log records.
String newId(String prefix) =>
    '$prefix${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
    '${Random().nextInt(1 << 20).toRadixString(36)}';

class Book {
  final String id, title, author, bookNo;
  final int copies;

  const Book({
    required this.id,
    required this.title,
    this.author = '',
    this.bookNo = '',
    this.copies = 1,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'bookNo': bookNo,
        'copies': copies,
      };

  factory Book.fromJson(Map<String, dynamic> j) => Book(
        id: j['id'] as String,
        title: j['title'] as String,
        author: j['author'] as String? ?? '',
        bookNo: j['bookNo'] as String? ?? '',
        copies: (j['copies'] as num?)?.toInt() ?? 1,
      );
}

class LogEntry {
  final String id;
  final Student student;
  final String book; // title at the time of borrowing
  final String bookId; // '' for old records made before the catalog existed
  final String bookNo;
  final DateTime time;
  DateTime? returnedAt;

  LogEntry({
    required this.id,
    required this.student,
    required this.book,
    this.bookId = '',
    this.bookNo = '',
    required this.time,
    this.returnedAt,
  });

  bool get returned => returnedAt != null;
  DateTime get dueDate => time.add(const Duration(days: loanDays));
  bool get isOverdue => !returned && DateTime.now().isAfter(dueDate);

  Map<String, dynamic> toJson() => {
        'id': id,
        'student': student.toJson(),
        'book': book,
        'bookId': bookId,
        'bookNo': bookNo,
        'time': time.toIso8601String(),
        'returnedAt': returnedAt?.toIso8601String(),
      };

  factory LogEntry.fromJson(Map<String, dynamic> j) {
    final t = DateTime.parse(j['time'] as String);
    return LogEntry(
      id: j['id'] as String? ?? 'l${t.microsecondsSinceEpoch}',
      student: Student.fromJson(j['student'] as Map<String, dynamic>),
      book: j['book'] as String,
      bookId: j['bookId'] as String? ?? '',
      bookNo: j['bookNo'] as String? ?? '',
      time: t,
      returnedAt: j['returnedAt'] == null
          ? null
          : DateTime.parse(j['returnedAt'] as String),
    );
  }
}

// How many copies of a book are out right now.
int borrowedCopies(List<LogEntry> logs, Book b) =>
    logs.where((e) => e.bookId == b.id && !e.returned).length;

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

// Sample books for offline mode only. In online mode the catalog starts empty.
List<Book> sampleBooks() => [
      Book(id: 'sample-1', title: 'Noli Me Tangere', author: 'Jose Rizal', bookNo: 'BK-0001', copies: 3),
      Book(id: 'sample-2', title: 'El Filibusterismo', author: 'Jose Rizal', bookNo: 'BK-0002', copies: 2),
      Book(id: 'sample-3', title: 'Sample Programming Book', author: 'Sample Author', bookNo: 'BK-0003', copies: 1),
    ];

// Turns pasted Excel rows (or comma-separated lines) into books.
// Columns: Title, Author, Copies, Book number. Only the title is required.
List<Book> parseBooks(String text) {
  final out = <Book>[];
  for (final line in text.split(RegExp(r'\r?\n'))) {
    if (line.trim().isEmpty) continue;
    final cells = (line.contains('\t') ? line.split('\t') : line.split(','))
        .map((c) => c.trim())
        .toList();
    if (cells.isEmpty || cells[0].isEmpty) continue;
    if (cells[0].toLowerCase() == 'title') continue; // header row
    var copies = cells.length > 2 ? (int.tryParse(cells[2]) ?? 1) : 1;
    if (copies < 1) copies = 1;
    out.add(Book(
      id: newId('b'),
      title: cells[0],
      author: cells.length > 1 ? cells[1] : '',
      copies: copies,
      bookNo: cells.length > 3 ? cells[3] : '',
    ));
  }
  return out;
}

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

// ---------------------------------------------------------------------------
// Reading the library ID code (barcode / QR)
// ---------------------------------------------------------------------------

// Lower-case, no symbols, "&" treated as "and" (for matching names safely).
String _norm(String s) => s
    .toLowerCase()
    .replaceAll('&', 'and')
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .trim();

class ScanInfo {
  final String raw;
  String? id;
  String name = '';
  String level = ''; // shs, collegeLevel, or '' if the code does not say
  String grade = '', section = '', strand = '', college = '', course = '';

  ScanInfo(this.raw);

  // The shift is never read from the code. It always follows the grade + strand rules.
  String get shift => autoShift(grade, strand);

  // A complete student, only if EVERYTHING the Add Student form needs was found
  // and every value matches the allowed options.
  Student? toStudent() {
    final i = id;
    if (i == null || name.isEmpty) return null;
    if (level == collegeLevel) {
      if (college.isEmpty || course.isEmpty) return null;
      return Student(
        id: i,
        name: name,
        level: collegeLevel,
        college: college,
        course: course,
      );
    }
    if (level == shs) {
      if (grade.isEmpty || strand.isEmpty || section.isEmpty || shift.isEmpty) {
        return null;
      }
      return Student(
        id: i,
        name: name,
        level: shs,
        section: section,
        grade: grade,
        strand: strand,
        shift: shift,
      );
    }
    return null;
  }

  // Whatever was found, used to pre-fill the form when something is missing.
  Student partial() => Student(
        id: id ?? idPrefix,
        name: name,
        level: level.isEmpty ? shs : level,
        section: section,
        grade: grade,
        strand: strand,
        shift: shift,
        college: college,
        course: course,
      );
}

// Reads the text of a scanned code. Works with:
//  - a plain ID (HY202500001)
//  - a web link that contains the ID, or has ?name=...&grade=... in it
//  - JSON text such as {"id":"HY202500001","name":"..."}
// It only keeps the details the Add Student form asks for, and only if they
// match the allowed options. Anything else in the code is ignored.
ScanInfo parseScan(String raw) {
  final info = ScanInfo(raw);
  final text = raw.trim();
  final fields = <String, String>{};

  void put(String k, dynamic v) {
    if (v == null) return;
    final key = k.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final val = v.toString().trim();
    if (key.isNotEmpty && val.isNotEmpty) fields[key] = val;
  }

  // 1) JSON
  if (text.startsWith('{')) {
    try {
      final j = jsonDecode(text);
      if (j is Map) {
        j.forEach((k, v) => put(k.toString(), v));
      }
    } catch (_) {}
  }

  // 2) Web link with ?name=value&name=value
  try {
    final uri = Uri.tryParse(text);
    if (uri != null) {
      uri.queryParameters.forEach((k, v) => put(k, v));
    }
  } catch (_) {}

  // 3) Plain "key=value" or "key: value" text
  if (fields.isEmpty && !text.contains('://')) {
    for (final part in text.split(RegExp(r'[\n;|&]'))) {
      final m = RegExp(r'^\s*([A-Za-z_ ]+?)\s*[=:]\s*(.+)$').firstMatch(part);
      if (m != null) put(m.group(1)!, m.group(2)!);
    }
  }

  String? pick(List<String> keys) {
    for (final k in keys) {
      final v = fields[k];
      if (v != null) return v;
    }
    return null;
  }

  // ---- ID (must match HY202500 + 3 digits) ----
  String? id;
  final fromField =
      pick(['id', 'studentid', 'idnumber', 'idno', 'studentno', 'studentnumber']);
  if (fromField != null) {
    final u = fromField.trim().toUpperCase();
    if (isValidId(u)) id = u;
  }
  final idRegex = RegExp('(?<![A-Za-z0-9])$idPrefix[0-9]{3}(?![0-9])',
      caseSensitive: false);
  id ??= idRegex.firstMatch(text)?.group(0)?.toUpperCase();
  info.id = id;
  if (id == null) return info;

  // ---- name ----
  final nm = pick(['name', 'fullname', 'studentname', 'learnername']);
  if (nm != null) {
    final clean = nm.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isNotEmpty && clean.length <= 80) info.name = clean;
  }

  // ---- Senior High details ----
  final g = pick(['grade', 'gradelevel', 'yearlevel']);
  if (g != null) {
    final m = RegExp(r'(11|12)').firstMatch(g);
    if (m != null) info.grade = m.group(1)!;
  }
  final sec = pick(['section', 'sec']);
  if (sec != null && sec.length <= 30) info.section = sec.trim();
  final st = pick(['strand', 'track']);
  if (st != null) {
    final words = _norm(st).split(' ');
    for (final x in strands) {
      if (words.contains(_norm(x))) info.strand = x;
    }
  }

  // ---- College details ----
  final cl = pick(['college', 'department', 'dept', 'school']);
  if (cl != null) {
    for (final c in colleges) {
      if (_norm(cl) == _norm(c)) info.college = c;
    }
  }
  final cr = pick(['course', 'program', 'degree']);
  if (cr != null) {
    final matches = <MapEntry<String, String>>[];
    collegeCourses.forEach((col, list) {
      for (final c in list) {
        final abbr = c.split(' - ').first;
        if (_norm(cr) == _norm(c) || _norm(cr) == _norm(abbr)) {
          matches.add(MapEntry(col, c));
        }
      }
    });
    final pool = info.college.isEmpty
        ? matches
        : matches.where((m) => m.key == info.college).toList();
    // only accept it if it points to exactly one real course
    if (pool.length == 1) {
      info.college = pool.first.key;
      info.course = pool.first.value;
    }
  }

  // ---- level ----
  final lv = pick(['level', 'type', 'studentlevel']);
  if (lv != null) {
    final n = _norm(lv);
    if (n.contains('college')) {
      info.level = collegeLevel;
    } else if (n.contains('senior') || n == 'shs') {
      info.level = shs;
    }
  }
  if (info.level.isEmpty) {
    if (info.college.isNotEmpty || info.course.isNotEmpty) {
      info.level = collegeLevel;
    } else if (info.grade.isNotEmpty ||
        info.strand.isNotEmpty ||
        info.section.isNotEmpty) {
      info.level = shs;
    }
  }
  // keep only the fields that belong to that level
  if (info.level == shs) {
    info.college = '';
    info.course = '';
  } else if (info.level == collegeLevel) {
    info.grade = '';
    info.strand = '';
    info.section = '';
  }
  return info;
}

// Add / edit student dialog (Senior High or College, with ID format check)
Future<Student?> showStudentDialog(BuildContext context,
    {Student? existing, Student? prefill}) {
  final base = existing ?? prefill; // starting values for the form
  final idLocked = existing != null || prefill != null;
  final idCtrl = TextEditingController(text: base?.id ?? idPrefix);
  final nameCtrl = TextEditingController(text: base?.name ?? '');
  final sectionCtrl = TextEditingController(text: base?.section ?? '');
  String level = base?.level ?? shs;
  String grade = base?.grade ?? '';
  String strand = base?.strand ?? '';
  String shift = (base != null && base.shift.isNotEmpty)
      ? base.shift
      : autoShift(grade, strand);
  String college = base?.college ?? '';
  String course = base?.course ?? '';
  String? error;

  return showDialog<Student>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: Text(existing != null
            ? 'Edit student'
            : (prefill != null ? 'Complete student info' : 'Add student')),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (prefill != null)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'The ID code did not contain all the details. Please complete the rest.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
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
                  enabled: !idLocked,
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
                    emptySelectionAllowed: true,
                    selected: grade.isEmpty ? <String>{} : {grade},
                    onSelectionChanged: (v) => setLocal(() {
                      grade = v.isEmpty ? '' : v.first;
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
                      'Choose a grade and strand to see the shift.',
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
              if (level == shs && (grade.isEmpty || strand.isEmpty)) {
                setLocal(() => error = 'Please choose the grade and strand.');
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

// Add / edit a book in the catalog
Future<Book?> showBookDialog(BuildContext context, {Book? existing}) {
  final titleCtrl = TextEditingController(text: existing?.title ?? '');
  final authorCtrl = TextEditingController(text: existing?.author ?? '');
  final noCtrl = TextEditingController(text: existing?.bookNo ?? '');
  final copiesCtrl = TextEditingController(text: '${existing?.copies ?? 1}');
  String? error;

  return showDialog<Book>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: Text(existing == null ? 'Add book' : 'Edit book'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: authorCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Author',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Book number / barcode (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: copiesCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Number of copies',
                    border: OutlineInputBorder(),
                  ),
                ),
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
              final title = titleCtrl.text.trim();
              final copies = int.tryParse(copiesCtrl.text.trim());
              if (title.isEmpty) {
                setLocal(() => error = 'Please enter the book title.');
                return;
              }
              if (copies == null || copies < 1) {
                setLocal(() => error = 'Copies must be 1 or more.');
                return;
              }
              Navigator.pop(
                ctx,
                Book(
                  id: existing?.id ?? newId('b'),
                  title: title,
                  author: authorCtrl.text.trim(),
                  bookNo: noCtrl.text.trim(),
                  copies: copies,
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

// Paste many books from Excel at once
Future<String?> showImportDialog(BuildContext context) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Import books from Excel'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'In Excel, select the columns Title, Author, Copies, Book number '
              '(one book per row), copy them, and paste below. Only the title is required.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 10,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Title, Author, Copies, Book number',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text),
          child: const Text('Import'),
        ),
      ],
    ),
  );
}

// Who borrowed this book, and when
void showBookHistory(BuildContext context, Book b, List<LogEntry> logs) {
  final items = logs.where((e) => e.bookId == b.id).toList();
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(b.title),
      content: SizedBox(
        width: 420,
        child: items.isEmpty
            ? const Text('Nobody has borrowed this book yet.')
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final e in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${e.student.name} (${e.student.id})',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text('Borrowed: ${formatDateTime(e.time)}'),
                            Text(
                              e.returned
                                  ? 'Returned: ${formatDateTime(e.returnedAt!)}'
                                  : 'Not yet returned (due ${formatDateTime(e.dueDate)})',
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
      ],
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
      home: useCloud ? const AuthGate() : const HomePage(),
    );
  }
}

// Shows the login screen until a staff member signs in (online mode only).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: cloud.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = cloud.auth.currentSession;
        return session == null ? const LoginPage() : const HomePage();
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await cloud.auth.signInWithPassword(
        email: emailCtrl.text.trim(),
        password: passCtrl.text,
      );
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (e) {
      if (mounted) setState(() => error = 'Could not sign in: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.menu_book,
                      size: 48, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 8),
                  Text(
                    'Library Logbook',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Text('Staff sign in', textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => loading ? null : _signIn(),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: loading ? null : _signIn,
                    child: Text(loading ? 'Signing in...' : 'Sign in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
  List<Book> books = [];
  List<LogEntry> logs = [];
  int tab = 0;
  bool loaded = false;
  final List<StreamSubscription<dynamic>> _subs = [];
  final Set<String> _got = {};

  @override
  void initState() {
    super.initState();
    if (useCloud) {
      _startCloud();
    } else {
      _loadLocal();
    }
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }

  // ---- storage: this computer only ----

  Future<void> _loadLocal() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString('students_v2');
    final l = p.getString('logs_v2');
    final b = p.getString('books_v1');
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
      books = b == null
          ? sampleBooks()
          : (jsonDecode(b) as List)
              .map((e) => Book.fromJson(e as Map<String, dynamic>))
              .toList();
      loaded = true;
    });
  }

  Future<void> _saveLocal() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        'students_v2', jsonEncode(students.map((e) => e.toJson()).toList()));
    await p.setString(
        'logs_v2', jsonEncode(logs.map((e) => e.toJson()).toList()));
    await p.setString(
        'books_v1', jsonEncode(books.map((e) => e.toJson()).toList()));
  }

  // ---- storage: online (shared database, updates live for everyone) ----

  void _startCloud() {
    void gotFirst(String table) {
      _got.add(table);
      if (_got.length == 3 && !loaded && mounted) {
        setState(() => loaded = true);
      }
    }

    void failed(Object e, [StackTrace? st]) {
      if (!mounted) return;
      setState(() => loaded = true);
      _snack('Online connection problem: $e');
    }

    Map<String, dynamic> dataOf(Map<String, dynamic> row) =>
        Map<String, dynamic>.from(row['data'] as Map);

    _subs.add(cloud.from('students').stream(primaryKey: ['id']).listen((rows) {
      if (!mounted) return;
      setState(() {
        students = rows.map((r) => Student.fromJson(dataOf(r))).toList()
          ..sort((a, b) => a.id.compareTo(b.id));
      });
      gotFirst('students');
    }, onError: failed));

    _subs.add(cloud.from('books').stream(primaryKey: ['id']).listen((rows) {
      if (!mounted) return;
      setState(() {
        books = rows.map((r) => Book.fromJson(dataOf(r))).toList()
          ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      });
      gotFirst('books');
    }, onError: failed));

    _subs.add(cloud.from('logs').stream(primaryKey: ['id']).listen((rows) {
      if (!mounted) return;
      setState(() {
        logs = rows.map((r) => LogEntry.fromJson(dataOf(r))).toList()
          ..sort((a, b) => b.time.compareTo(a.time));
      });
      gotFirst('logs');
    }, onError: failed));
  }

  // Saves one record (or deletes it when data is null).
  Future<void> _persist(
      String table, String id, Map<String, dynamic>? data) async {
    if (!useCloud) {
      await _saveLocal();
      return;
    }
    try {
      if (data == null) {
        await cloud.from(table).delete().eq('id', id);
      } else {
        await cloud.from(table).upsert({'id': id, 'data': data});
      }
    } catch (e) {
      if (mounted) _snack('Could not save online: $e');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---- logs ----

  void _addLog(Student s, Book b) {
    final entry = LogEntry(
      id: newId('l'),
      student: s,
      book: b.title,
      bookId: b.id,
      bookNo: b.bookNo,
      time: DateTime.now(),
    );
    setState(() => logs.insert(0, entry));
    _persist('logs', entry.id, entry.toJson());
    _snack('Logged: ${s.name} borrowed "${b.title}"');
  }

  void _toggleReturned(LogEntry e, bool value) {
    setState(() => e.returnedAt = value ? DateTime.now() : null);
    _persist('logs', e.id, e.toJson());
  }

  Future<void> _deleteLog(LogEntry e) async {
    final ok = await confirm(
        context, 'Delete record?', '"${e.book}" borrowed by ${e.student.name}');
    if (!ok || !mounted) return;
    setState(() => logs.remove(e));
    _persist('logs', e.id, null);
  }

  // ---- students ----

  bool _registerStudent(Student s) {
    if (students.any((x) => x.id == s.id)) return false;
    setState(() => students.add(s));
    _persist('students', s.id, s.toJson());
    return true;
  }

  Future<void> _addStudent() async {
    final result = await showStudentDialog(context);
    if (result == null || !mounted) return;
    if (!_registerStudent(result)) {
      _snack('That Student ID already exists.');
      return;
    }
    _snack('Added ${result.name}');
  }

  Future<void> _editStudent(Student old) async {
    final result = await showStudentDialog(context, existing: old);
    if (result == null || !mounted) return;
    setState(() {
      final i = students.indexWhere((s) => s.id == old.id);
      if (i != -1) students[i] = result;
    });
    _persist('students', result.id, result.toJson());
  }

  Future<void> _deleteStudent(Student s) async {
    final ok = await confirm(context, 'Delete student?',
        '${s.name} (${s.id}) will be removed. Their past records stay in the logbook.');
    if (!ok || !mounted) return;
    setState(() => students.removeWhere((x) => x.id == s.id));
    _persist('students', s.id, null);
  }

  // ---- books ----

  Future<void> _addBook() async {
    final result = await showBookDialog(context);
    if (result == null || !mounted) return;
    setState(() => books.add(result));
    _persist('books', result.id, result.toJson());
    _snack('Added "${result.title}"');
  }

  Future<void> _editBook(Book old) async {
    final result = await showBookDialog(context, existing: old);
    if (result == null || !mounted) return;
    setState(() {
      final i = books.indexWhere((b) => b.id == old.id);
      if (i != -1) books[i] = result;
    });
    _persist('books', result.id, result.toJson());
  }

  Future<void> _deleteBook(Book b) async {
    final ok = await confirm(context, 'Delete book?',
        '"${b.title}" will be removed from the catalog. Past records stay in the logbook.');
    if (!ok || !mounted) return;
    setState(() => books.removeWhere((x) => x.id == b.id));
    _persist('books', b.id, null);
  }

  Future<void> _importBooks() async {
    final text = await showImportDialog(context);
    if (text == null || !mounted) return;
    final parsed = parseBooks(text);
    final fresh = <Book>[];
    var skipped = 0;
    for (final b in parsed) {
      final dup = [...books, ...fresh].any((x) =>
          x.title.toLowerCase() == b.title.toLowerCase() &&
          x.author.toLowerCase() == b.author.toLowerCase());
      if (dup) {
        skipped++;
      } else {
        fresh.add(b);
      }
    }
    if (fresh.isNotEmpty) {
      setState(() => books.addAll(fresh));
      if (useCloud) {
        try {
          await cloud.from('books').upsert(
              fresh.map((b) => {'id': b.id, 'data': b.toJson()}).toList());
        } catch (e) {
          if (mounted) _snack('Could not save online: $e');
        }
      } else {
        await _saveLocal();
      }
    }
    if (!mounted) return;
    _snack(
        'Imported ${fresh.length} book(s)${skipped > 0 ? ', skipped $skipped duplicate(s)' : ''}.');
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pages = [
      BorrowTab(
        students: students,
        books: books,
        logs: logs,
        onLog: _addLog,
        onRegister: _registerStudent,
      ),
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
      BooksTab(
        books: books,
        logs: logs,
        onEdit: _editBook,
        onDelete: _deleteBook,
        onImport: _importBooks,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library Logbook'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Text(
                useCloud ? 'Online' : 'This computer only',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          if (useCloud)
            IconButton(
              tooltip: 'Sign out (${cloud.auth.currentUser?.email ?? ''})',
              icon: const Icon(Icons.logout),
              onPressed: () => cloud.auth.signOut(),
            ),
        ],
      ),
      body: pages[tab],
      floatingActionButton: tab == 2
          ? FloatingActionButton.extended(
              onPressed: _addStudent,
              icon: const Icon(Icons.person_add),
              label: const Text('Add student'),
            )
          : tab == 3
              ? FloatingActionButton.extended(
                  onPressed: _addBook,
                  icon: const Icon(Icons.library_add),
                  label: const Text('Add book'),
                )
              : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.edit_note), label: 'Borrow'),
          NavigationDestination(icon: Icon(Icons.menu_book), label: 'Logbook'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Students'),
          NavigationDestination(icon: Icon(Icons.library_books), label: 'Books'),
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
  final List<Book> books;
  final List<LogEntry> logs;
  final void Function(Student, Book) onLog;
  final bool Function(Student) onRegister;

  const BorrowTab({
    super.key,
    required this.students,
    required this.books,
    required this.logs,
    required this.onLog,
    required this.onRegister,
  });

  @override
  State<BorrowTab> createState() => _BorrowTabState();
}

class _BorrowTabState extends State<BorrowTab> {
  final idCtrl = TextEditingController();
  final bookCtrl = TextEditingController();
  final idFocus = FocusNode();
  final bookFocus = FocusNode();

  String? scanMessage; // result of the last scan or the last action
  bool scanWarning = false;
  String? lastRaw; // text of the last scanned code (for troubleshooting)
  Book? selectedBook;
  String? visitId; // the student whose books are listed below
  List<String> visitBooks = [];

  String get typedText => idCtrl.text.trim();
  String? get typedId => parseScan(typedText).id;

  Student? get found {
    final id = typedId;
    if (id == null) return null;
    for (final s in widget.students) {
      if (s.id == id) return s;
    }
    return null;
  }

  // The catalog book matching what was picked, typed, or scanned
  // (by exact title or book number).
  Book? get chosenBook {
    final t = bookCtrl.text.trim().toLowerCase();
    if (t.isEmpty) return null;
    final sel = selectedBook;
    if (sel != null && sel.title.toLowerCase() == t) return sel;
    for (final b in widget.books) {
      if (b.title.toLowerCase() == t ||
          (b.bookNo.isNotEmpty && b.bookNo.toLowerCase() == t)) {
        return b;
      }
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

  // Called when a code is scanned (camera or USB scanner) or Enter is pressed.
  Future<void> _processRaw(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return;
    final scan = parseScan(text);
    lastRaw = text;

    // 1) not a valid library ID code
    if (scan.id == null) {
      setState(() {
        scanWarning = true;
        scanMessage =
            'This code does not contain a valid student ID ($idPrefix + 3 digits).';
      });
      idFocus.requestFocus();
      return;
    }

    final id = scan.id!;
    idCtrl.text = id;

    // 2) already registered: just use the saved info
    if (widget.students.any((s) => s.id == id)) {
      setState(() {
        scanWarning = false;
        scanMessage = null;
      });
      bookFocus.requestFocus();
      return;
    }

    // 3) new student and the code had everything: register automatically
    final complete = scan.toStudent();
    if (complete != null) {
      widget.onRegister(complete);
      setState(() {
        scanWarning = false;
        scanMessage =
            'New student registered from the ID code: ${complete.name}.';
      });
      bookFocus.requestFocus();
      return;
    }

    // 4) new student but details are missing: ask only for the rest
    setState(() {
      scanWarning = true;
      scanMessage =
          'This ID is not registered yet, and the code did not have all the details.';
    });
    final result = await showStudentDialog(context, prefill: scan.partial());
    if (result != null && mounted) {
      widget.onRegister(result);
      setState(() {
        scanWarning = false;
        scanMessage = 'Student registered: ${result.name}.';
      });
      bookFocus.requestFocus();
    }
  }

  Future<void> _scanCamera() async {
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScanPage()),
    );
    if (raw != null && mounted) {
      await _processRaw(raw);
    }
  }

  // Logs one book. The student stays selected so more books can be added.
  void _submit() {
    final s = found;
    final b = chosenBook;
    if (s == null) return;
    if (b == null) {
      if (bookCtrl.text.trim().isNotEmpty) {
        setState(() {
          scanWarning = true;
          scanMessage =
              'Pick the book from the list, or scan its barcode / book number.';
        });
      }
      return;
    }
    if (borrowedCopies(widget.logs, b) >= b.copies) {
      setState(() {
        scanWarning = true;
        scanMessage = 'No copies of "${b.title}" are available right now.';
      });
      return;
    }
    if (widget.logs.any(
        (e) => !e.returned && e.student.id == s.id && e.bookId == b.id)) {
      setState(() {
        scanWarning = true;
        scanMessage = '${s.name} is already borrowing "${b.title}".';
      });
      return;
    }
    widget.onLog(s, b);
    setState(() {
      if (visitId != s.id) {
        visitId = s.id;
        visitBooks = [];
      }
      visitBooks.add(b.title);
      bookCtrl.clear();
      selectedBook = null;
      scanMessage = null;
      scanWarning = false;
      lastRaw = null;
    });
    bookFocus.requestFocus();
  }

  void _nextStudent() {
    setState(() {
      idCtrl.clear();
      bookCtrl.clear();
      selectedBook = null;
      visitId = null;
      visitBooks = [];
      scanMessage = null;
      scanWarning = false;
      lastRaw = null;
    });
    idFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final s = found;
    final text = typedText;
    final parsedId = typedId;
    final scheme = Theme.of(context).colorScheme;
    final book = chosenBook;
    final canLog = s != null && book != null;

    final borrowedNow = widget.logs.where((e) => !e.returned).length;
    final overdue = widget.logs.where((e) => e.isOverdue).length;

    String? problem;
    if (parsedId == null && text.length >= idLength) {
      problem = 'Invalid ID. It must look like ${idPrefix}001.';
    } else if (parsedId != null && s == null && scanMessage == null) {
      problem = 'This ID is not registered yet. Press Enter to register it.';
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
        Text('Log borrowed books',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        const Text(
            'Scan the library ID with the camera or a barcode scanner. Then add as many books as needed.'),
        const SizedBox(height: 16),
        TextField(
          controller: idCtrl,
          focusNode: idFocus,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Student ID',
            helperText: 'Scan the ID, or type $idPrefix + 3 digits and press Enter',
            prefixIcon: const Icon(Icons.qr_code_scanner),
            suffixIcon: IconButton(
              tooltip: 'Scan with camera',
              icon: const Icon(Icons.photo_camera),
              onPressed: _scanCamera,
            ),
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (v) => _processRaw(v),
        ),
        const SizedBox(height: 12),
        if (scanMessage != null)
          Card(
            color: scanWarning
                ? scheme.errorContainer
                : scheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(scanMessage!),
            ),
          ),
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
                  Text(s.details),
                  const SizedBox(height: 4),
                  Text(
                    'Currently borrowing: '
                    '${widget.logs.where((e) => e.student.id == s.id && !e.returned).length} book(s)',
                  ),
                ],
              ),
            ),
          ),
        if (s != null && visitId == s.id && visitBooks.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Logged just now for ${s.name} (${visitBooks.length})',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  for (final t in visitBooks) Text('•  $t'),
                ],
              ),
            ),
          ),
        if (lastRaw != null)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Show what the last scanned code says'),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SelectableText(lastRaw!),
              ),
              const SizedBox(height: 8),
            ],
          ),
        const SizedBox(height: 12),
        if (widget.books.isEmpty)
          Card(
            color: scheme.errorContainer,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                  'The book catalog is empty. Add books in the Books tab first.'),
            ),
          ),
        RawAutocomplete<Book>(
          textEditingController: bookCtrl,
          focusNode: bookFocus,
          displayStringForOption: (b) => b.title,
          optionsBuilder: (TextEditingValue v) {
            final q = v.text.trim().toLowerCase();
            final list = q.isEmpty
                ? widget.books
                : widget.books.where((b) =>
                    b.title.toLowerCase().contains(q) ||
                    b.author.toLowerCase().contains(q) ||
                    b.bookNo.toLowerCase().contains(q));
            return list.take(8);
          },
          onSelected: (b) => setState(() => selectedBook = b),
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(
                labelText: 'Book (search by title, author, or scan the book number)',
                prefixIcon: Icon(Icons.book),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() => selectedBook = null),
              onSubmitted: (_) => _submit(),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxHeight: 260, maxWidth: 600),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, i) {
                      final b = options.elementAt(i);
                      final avail = b.copies - borrowedCopies(widget.logs, b);
                      return ListTile(
                        dense: true,
                        title: Text(b.title),
                        subtitle: Text(
                            '${b.author.isEmpty ? 'Unknown author' : b.author}  •  Available: $avail of ${b.copies}'),
                        onTap: () => onSelected(b),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
        if (book != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Available: ${book.copies - borrowedCopies(widget.logs, book)} of ${book.copies}'
              '${book.bookNo.isEmpty ? '' : '  •  Book no. ${book.bookNo}'}',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: canLog ? _submit : null,
                icon: const Icon(Icons.check),
                label: const Text('Log this book'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _nextStudent,
                icon: const Icon(Icons.navigate_next),
                label: const Text('Next student'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'The student stays selected after each book, so you can log several books in a row. '
          'Press "Next student" when done. Date and time are saved automatically. '
          'Books are due after $loanDays days.',
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}

// Full-screen camera that reads one barcode / QR code and returns its text.
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final MobileScannerController controller = MobileScannerController();
  bool done = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan library ID')),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (done) return;
              for (final b in capture.barcodes) {
                final v = b.rawValue;
                if (v != null && v.isNotEmpty) {
                  done = true;
                  Navigator.of(context).pop(v);
                  return;
                }
              }
            },
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Point the camera at the barcode or QR code on the ID',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ),
        ],
      ),
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
      'Student ID,Name,Level,Grade,Strand,Section,Shift,College,Course,Book,Book No.,Borrowed,Returned,Status'
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
        q(e.bookNo),
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
          e.bookNo.toLowerCase().contains(q) ||
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
                            if (e.bookNo.isNotEmpty) Text('Book no. ${e.bookNo}'),
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

// ---------------------------------------------------------------------------
// Tab 4: Books (the catalog)
// ---------------------------------------------------------------------------

class BooksTab extends StatefulWidget {
  final List<Book> books;
  final List<LogEntry> logs;
  final void Function(Book) onEdit;
  final void Function(Book) onDelete;
  final VoidCallback onImport;

  const BooksTab({
    super.key,
    required this.books,
    required this.logs,
    required this.onEdit,
    required this.onDelete,
    required this.onImport,
  });

  @override
  State<BooksTab> createState() => _BooksTabState();
}

class _BooksTabState extends State<BooksTab> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final q = query.toLowerCase();
    final shown = widget.books.where((b) {
      return b.title.toLowerCase().contains(q) ||
          b.author.toLowerCase().contains(q) ||
          b.bookNo.toLowerCase().contains(q);
    }).toList();
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search ${widget.books.length} book(s)',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => query = v),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Import books from Excel (paste)',
                onPressed: widget.onImport,
                icon: const Icon(Icons.upload_file),
              ),
            ],
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? const Center(child: Text('No books yet. Add one or import from Excel.'))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
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
                        '${b.bookNo.isEmpty ? '' : '  •  ${b.bookNo}'}\n'
                        'Available: $avail of ${b.copies}  •  tap to see who borrowed it',
                        style: TextStyle(color: avail <= 0 ? scheme.error : null),
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit),
                            onPressed: () => widget.onEdit(b),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => widget.onDelete(b),
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