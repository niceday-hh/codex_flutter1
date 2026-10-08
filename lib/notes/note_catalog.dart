import '../models.dart';

class NoteChoice {
  NoteChoice(this.text, this.latest);
  final String text;
  DateTime latest;
  int count = 0;
  final Set<String> categories = {};
}

List<NoteChoice> collectNotes(List<LedgerEntry> entries, bool income) {
  final notes = <String, NoteChoice>{};
  for (final entry in entries) {
    final text = entry.note.trim();
    if (entry.isIncome != income || text.isEmpty) continue;
    final note = notes.putIfAbsent(text, () => NoteChoice(text, entry.date));
    note.count++;
    note.categories.add(entry.category);
    if (entry.date.isAfter(note.latest)) note.latest = entry.date;
  }
  return notes.values.toList();
}

// Retain complete note histories; reuse them across openings and edits.
class NoteCatalog {
  NoteCatalog(List<LedgerEntry> entries)
      : expense = List.unmodifiable(collectNotes(entries, false)),
        income = List.unmodifiable(collectNotes(entries, true));
  final List<NoteChoice> expense, income;
  List<NoteChoice> forMode(bool isIncome) => isIncome ? income : expense;
}
