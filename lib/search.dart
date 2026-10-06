import 'dart:math' as math;

import 'package:flutter/material.dart';

// How different two words are (number of letter changes).
int _lev(String a, String b) {
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      cur[j] = math.min(
        math.min(cur[j - 1] + 1, prev[j] + 1),
        prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
      );
    }
    prev = cur;
  }
  return prev[b.length];
}

List<String> _words(String s) => s
    .toLowerCase()
    .split(RegExp(r'[^a-z0-9]+'))
    .where((w) => w.isNotEmpty)
    .toList();

// 0 = no match. Higher = better match. Allows small typos
// ("hary poter" still finds "Harry Potter").
double fuzzyScore(String query, String text) {
  final tokens = _words(query);
  if (tokens.isEmpty) return 1;
  final full = text.toLowerCase();
  final words = _words(text);
  var total = 0.0;
  for (final t in tokens) {
    var best = full.contains(t) ? 2.0 : 0.0;
    if (best == 0) {
      final allowed = t.length <= 3 ? 0 : (t.length <= 6 ? 1 : 2);
      for (final w in words) {
        final head = w.length > t.length ? w.substring(0, t.length) : w;
        final d = math.min(_lev(t, w), _lev(t, head));
        if (d <= allowed) best = math.max(best, 1 - d / (t.length + 1));
      }
    }
    if (best == 0) return 0;
    total += best;
  }
  return total / tokens.length;
}

// Best matches first. An empty search returns everything.
List<T> fuzzyFilter<T>(String q, Iterable<T> items, String Function(T) text) {
  if (q.trim().isEmpty) return items.toList();
  final scored = <MapEntry<T, double>>[];
  for (final i in items) {
    final s = fuzzyScore(q, text(i));
    if (s > 0) scored.add(MapEntry(i, s));
  }
  scored.sort((a, b) => b.value.compareTo(a.value));
  return scored.map((e) => e.key).toList();
}

// "Did you mean ...?" - the closest real word, or null.
String? didYouMean(String q, Iterable<String> texts) {
  final tokens = _words(q);
  if (tokens.isEmpty || tokens.last.length < 3) return null;
  final t = tokens.last;
  String? best;
  var bestD = 99;
  for (final text in texts) {
    for (final w in _words(text)) {
      final d = _lev(t, w);
      if (d < bestD && d <= (t.length <= 6 ? 1 : 2)) {
        bestD = d;
        best = w;
      }
    }
  }
  return bestD == 0 ? null : best;
}

// Search bar with suggestions that appear as you type (autofill).
class SmartSearch extends StatelessWidget {
  final String hint;
  final List<String> suggestions;
  final ValueChanged<String> onChanged;

  const SmartSearch({
    super.key,
    required this.hint,
    required this.suggestions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (v) => v.text.trim().length < 2
          ? const <String>[]
          : fuzzyFilter(v.text, suggestions.toSet(), (s) => s).take(6),
      onSelected: onChanged,
      fieldViewBuilder: (context, ctrl, focus, _) => TextField(
        controller: ctrl,
        focusNode: focus,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
