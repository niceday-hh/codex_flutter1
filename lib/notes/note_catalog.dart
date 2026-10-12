import 'package:flutter/foundation.dart';
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
  final _prepared = <(bool, String), Future<PreparedNotes>>{};
  Future<PreparedNotes> prepare(bool isIncome, String category) =>
      _prepared.putIfAbsent((isIncome, category), () {
        final notes = forMode(isIncome);
        return notes.length >= 200
            ? compute(prepareNotes, (notes, category), debugLabel: 'prepare-note-picker')
            : Future.value(prepareNotes((notes, category)));
      });
  List<NoteChoice> forMode(bool isIncome) => isIncome ? income : expense;
}

class PreparedNotes {
  const PreparedNotes(this.all, this.category);
  final List<List<NoteChoice>> all, category;
  List<NoteChoice> view(int order, bool categoryOnly) => (categoryOnly ? category : all)[order];
}

PreparedNotes prepareNotes((List<NoteChoice>, String) input) {
  final all = <List<NoteChoice>>[], category = <List<NoteChoice>>[];
  for (var order = 0; order < 3; order++) {
    final notes = List<NoteChoice>.of(input.$1)..sort((a, b) {
      final value = order == 0 ? b.count.compareTo(a.count)
          : order == 1 ? b.latest.compareTo(a.latest) : a.text.compareTo(b.text);
      return value != 0 ? value : a.text.compareTo(b.text);
    });
    all.add(List.unmodifiable(notes));
    category.add(List.unmodifiable(notes.where((n) => n.categories.contains(input.$2))));
  }
  return PreparedNotes(List.unmodifiable(all), List.unmodifiable(category));
}

NoteCatalog buildNoteCatalog(List<LedgerEntry> entries) => NoteCatalog(entries);
