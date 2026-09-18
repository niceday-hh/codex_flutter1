import 'package:flutter/material.dart';
import '../app_store.dart';
import '../models.dart';
import 'common.dart';

enum EntryOrder { newest, oldest, highest, lowest }
List<LedgerEntry> sortEntries(List<LedgerEntry> entries, EntryOrder order) {
  return List<LedgerEntry>.of(entries)..sort((a,b) {
    final value = switch (order) {
      EntryOrder.newest => b.date.compareTo(a.date),
      EntryOrder.oldest => a.date.compareTo(b.date),
      EntryOrder.highest => b.amount.compareTo(a.amount),
      EntryOrder.lowest => a.amount.compareTo(b.amount),
    };
    if (value != 0) return value;
    final time = b.date.compareTo(a.date);
    return time != 0 ? time : a.id.compareTo(b.id);
  });
}
class SortedEntries extends StatefulWidget {
  const SortedEntries({super.key, required this.entries, required this.store, required this.title, this.categoryTotal});
  final List<LedgerEntry> entries;
  final AppStore store;
  final String title;
  final double? categoryTotal;
  @override
  State<SortedEntries> createState() => _SortedEntriesState();
}
class _SortedEntriesState extends State<SortedEntries> {
  EntryOrder _order = EntryOrder.newest;
  final _scroll = ScrollController();
  @override
  void dispose() { _scroll.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final entries = sortEntries(widget.entries, _order), store = widget.store;
    return Padding(padding: const EdgeInsets.fromLTRB(20,0,20,24), child: Column(children: [
      Row(children: [Expanded(child: Text(widget.title, style: Theme.of(context).textTheme.titleLarge)), Text('${entries.length} 笔')]),
      Align(alignment: Alignment.centerRight, child: DropdownButton<EntryOrder>(value: _order,
        items: [for (final o in EntryOrder.values) DropdownMenuItem(value: o, child: Text(const ['时间：最新优先','时间：最早优先','金额：从高到低','金额：从低到高'][o.index]))],
        onChanged: (o) { if (o == null) return; setState(() => _order = o); if (_scroll.hasClients) _scroll.jumpTo(0); })),
      Expanded(child: entries.isEmpty ? const Center(child: Text('当前节点暂无明细')) : ListView.separated(controller: _scroll, itemCount: entries.length,
        separatorBuilder: (_, __) => const Divider(indent: 60), itemBuilder: (_, i) {
          final e = entries[i];
          return EntryRow(key: ValueKey(e.id), entry: e,
            noteSuffix: widget.categoryTotal == null || store.hideAmounts ? null : categoryShare(e.amount, widget.categoryTotal!),
            amountText: e.isIncome ? store.displayMoney(e.amount, signed: true) : store.hideAmounts ? '••••' : '-${store.displayMoney(e.amount)}');
        })),
    ]));
  }
}
