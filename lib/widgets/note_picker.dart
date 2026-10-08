import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models.dart';
import '../notes/note_catalog.dart';
export '../notes/note_catalog.dart' show NoteChoice, collectNotes;
import 'common.dart';

Future<String?> showNotePicker(BuildContext context, {
  required List<LedgerEntry> entries, required bool income,
  required String category, required String initial, NoteCatalog? catalog,
}) {
  final notes = catalog?.forMode(income) ?? collectNotes(entries, income);
  return showModalBottomSheet<String>(context: context, isScrollControlled: true,
  useSafeArea: true, showDragHandle: true,
  builder: (_) => NotePicker(notes: notes, category: category, initial: initial));
}

class NotePicker extends StatefulWidget {
  const NotePicker({super.key, required this.notes, required this.category, required this.initial});
  final List<NoteChoice> notes;
  final String category, initial;
  @override
  State<NotePicker> createState() => _NotePickerState();
}
class _NotePickerState extends State<NotePicker> {
  late final TextEditingController _draft = TextEditingController(text: widget.initial);
  final _search = TextEditingController();
  int _tab = 0;
  bool _categoryOnly = true;
  Object? _visibleKey;
  List<NoteChoice> _visible = const [];

  List<NoteChoice> _visibleNotes() {
    final query = _search.text.trim().toLowerCase();
    final key = (widget.notes, query, _tab, _categoryOnly, widget.category);
    if (key == _visibleKey) return _visible;
    _visibleKey = key;
    final notes = widget.notes.where((n) => (!_categoryOnly || n.categories.contains(widget.category)) && n.text.toLowerCase().contains(query)).toList();
    notes.sort((a,b) {
      final value = _tab == 0 ? b.count.compareTo(a.count) : _tab == 1 ? b.latest.compareTo(a.latest) : a.text.compareTo(b.text);
      return value != 0 ? value : a.text.compareTo(b.text);
    });
    return _visible = notes;
  }
  @override
  void dispose() { _draft.dispose(); _search.dispose(); super.dispose(); }
  void _select(String text) {
    HapticFeedback.selectionClick();
    _draft.text = text;
  }
  @override
  Widget build(BuildContext context) {
    final notes = _visibleNotes();
    final theme = Theme.of(context);
    return Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(height: MediaQuery.sizeOf(context).height * .78,
        child: Padding(padding: const EdgeInsets.fromLTRB(20,0,20,12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('选个备注', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: '搜索历史备注')),
          const SizedBox(height: 10),
          PillTabs(labels: const ['常用','最近','全部'], index: _tab, onChanged: (i) => setState(() { _tab = i; if (i == 2) _categoryOnly = false; })),
          Row(children: [FilterChip(label: Text('仅${widget.category}'), selected: _categoryOnly, onSelected: (v) => setState(() => _categoryOnly = v)), const SizedBox(width: 10), Text('${notes.length} 个备注', style: theme.textTheme.bodySmall)]),
          Expanded(child: ValueListenableBuilder<TextEditingValue>(valueListenable: _draft,
            builder: (context, value, _) => notes.isEmpty ? const Center(child: Text('没有匹配的备注，可在下方填写新备注')) : _tab == 2
            ? ListView.builder(itemCount: notes.length, itemBuilder: (_, i) {
              final n = notes[i];
              return ListTile(contentPadding: EdgeInsets.zero, title: Text(n.text), subtitle: Text(n.categories.join(' · ')), trailing: _draft.text == n.text ? const Icon(Icons.check_circle) : Text('${n.count} 次'), onTap: () => _select(n.text));
            })
            : SingleChildScrollView(child: Wrap(spacing: 8, runSpacing: 8, children: [for (final n in notes.take(40)) ChoiceChip(
              selected: _draft.text == n.text, showCheckmark: true,
              label: Text(n.text, style: TextStyle(fontSize: _tab == 0 ? 13 + (n.count.clamp(1, 6) - 1).toDouble() : 14)),
              onSelected: (_) => _select(n.text),
              selectedColor: theme.colorScheme.primaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            )])))),
          if (_tab != 2 && notes.length > 40) TextButton(onPressed: () => setState(() { _tab = 2; }), child: Text('查看全部 ${notes.length} 个匹配备注')),
          const SizedBox(height: 8),
          TextField(controller: _draft, maxLength: 80, decoration: InputDecoration(labelText: '已选备注 / 自己填写', suffixIcon: IconButton(tooltip: '清空备注', icon: const Icon(Icons.close), onPressed: () => _select('')))),
          ValueListenableBuilder<TextEditingValue>(valueListenable: _draft, builder: (context, value, _) => SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context, _draft.text.trim()), child: Text(value.text.trim().isEmpty ? '保存空备注' : '使用此备注')))),
        ]))));
  }
}

