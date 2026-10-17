import 'dart:math' as math;
import '../notes/note_catalog.dart';

class VoiceCategorySuggestion {
  const VoiceCategorySuggestion(this.category, this.note, this.score);
  final String category, note;
  final double score;
}

class VoiceNoteMatches {
  const VoiceNoteMatches(this.suggestions, this.terms);
  final List<VoiceCategorySuggestion> suggestions;
  final Set<String> terms;
  bool get certain => suggestions.length == 1 ||
      (suggestions.length > 1 && suggestions.first.score >= suggestions[1].score * 1.5);
  String removeFrom(String text) {
    for (final term in terms) {
      text = text.replaceAll(RegExp(RegExp.escape(term), caseSensitive: false), ' ');
    }
    return text;
  }
}

String _compact(String text) => text.toLowerCase().replaceAll(
    RegExp(r'[\s，。,.、:：;；()（）\[\]【】!！?？\-—]'), '');

// Search the complete history for this income/expense mode, not the picker limit.
// Longer literal names win. We do not silently correct homophones or learn from
// unconfirmed recognition drafts.
VoiceNoteMatches matchVoiceNotes(String text, bool income, NoteCatalog? catalog, DateTime now) {
  if (catalog == null) return const VoiceNoteMatches([], {});
  final haystack = _compact(text);
  var longest = 0;
  final matches = <(NoteChoice, String)>[];
  for (final note in catalog.forMode(income)) {
    final forms = {note.text.trim(), note.text.split(RegExp(r'[（(]')).first.trim()};
    for (final term in forms) {
      final key = _compact(term);
      if (key.length < 2 || !haystack.contains(key)) continue;
      if (key.length > longest) { longest = key.length; matches.clear(); }
      if (key.length == longest && !matches.any((m) => identical(m.$1, note))) matches.add((note, term));
    }
  }
  final scores = <String, double>{}, names = <String, String>{};
  for (final (note, _) in matches) {
    for (final entry in note.categoryUsage.entries) {
      if (entry.key == '其他') continue;
      final age = now.difference(entry.value.latest).inDays.clamp(0, 3650);
      final score = math.log(1 + entry.value.count) * (1 + 30 / (30 + age));
      scores.update(entry.key, (v) => v + score, ifAbsent: () => score);
      names.putIfAbsent(entry.key, () => note.text);
    }
  }
  final suggestions = [for (final entry in scores.entries)
    VoiceCategorySuggestion(entry.key, names[entry.key]!, entry.value)]
    ..sort((a, b) { final score = b.score.compareTo(a.score); return score != 0 ? score : a.category.compareTo(b.category); });
  return VoiceNoteMatches(List.unmodifiable(suggestions.take(3)), Set.unmodifiable(matches.map((m) => m.$2)));
}
