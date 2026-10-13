import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_store.dart';
import '../app_theme.dart';
import 'voice_engine.dart';
import 'voice_parser.dart';
import 'voice_session.dart';

Future<bool?> showVoiceEntry(BuildContext context, AppStore store, {VoiceEngine? engine}) =>
  showModalBottomSheet<bool>(context: context, isScrollControlled: true, enableDrag: true,
    backgroundColor: Colors.transparent, barrierColor: Colors.black45,
    builder: (_) => VoiceEntrySheet(store: store, engine: engine ?? ParaformerVoiceEngine()));

class VoiceEntrySheet extends StatefulWidget {
  const VoiceEntrySheet({super.key, required this.store, required this.engine});
  final AppStore store;
  final VoiceEngine engine;
  @override
  State<VoiceEntrySheet> createState() => _VoiceEntrySheetState();
}
class _VoiceEntrySheetState extends State<VoiceEntrySheet> with WidgetsBindingObserver {
  late final _session = VoiceSession(widget.engine);
  bool _saved = false;
  @override
  void initState() {
    super.initState(); WidgetsBinding.instance.addObserver(this);
    unawaited(_session.prepare());
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && [VoiceStage.starting, VoiceStage.recording].contains(_session.stage)) {
      unawaited(_session.cancelHold());
    }
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); _session.dispose(); super.dispose();
  }
  Future<void> _editText(String title, String value, void Function(String) apply, {bool money = false}) async {
    final controller = TextEditingController(text: value);
    final result = await showDialog<String>(context: context, builder: (dialogContext) => AlertDialog(
      title: Text(title), content: TextField(controller: controller, autofocus: true, maxLength: money ? 12 : 120,
        keyboardType: money ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        inputFormatters: money ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : null,
        decoration: const InputDecoration(hintText: '请输入')),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
        TextButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('确定'))]));
    // A closing dialog may still paint the TextField for one transition frame.
    if (result != null && mounted) apply(result);
    await Future<void>.delayed(const Duration(milliseconds: 250)); controller.dispose();
  }
  Future<void> _editAmount() async {
    final draft = _session.draft!;
    await _editText('修改金额', draft.amount?.toStringAsFixed(2) ?? '', (text) {
      final amount = double.tryParse(text);
      if (amount == null || amount <= 0 || amount > 999999999 || !RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(text)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入大于零、最多两位小数的金额'))); return;
      }
      _session.edit(draft.copyWith(amount: amount));
    }, money: true);
  }
  Future<void> _editType() async {
    final draft = _session.draft!;
    final income = await showModalBottomSheet<bool>(context: context, builder: (c) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min,
      children: [ListTile(title: const Text('支出'), leading: const Icon(Icons.remove_circle_outline), onTap: () => Navigator.pop(c, false)),
        ListTile(title: const Text('收入'), leading: const Icon(Icons.add_circle_outline), onTap: () => Navigator.pop(c, true))])));
    if (income != null && mounted) {
      _session.edit(draft.copyWith(isIncome: income, category: '其他'));
    }
  }
  Future<void> _editCategory() async {
    final draft = _session.draft!;
    final categories = draft.isIncome ? incomeCategories.where((x) => x != '设置').toList() : expenseCategories;
    final selected = await showModalBottomSheet<String>(
      context: context, isScrollControlled: true,
      builder: (c) => SafeArea(child: SizedBox(
        height: MediaQuery.sizeOf(c).height * .55,
        child: Column(children: [
          const Padding(padding: EdgeInsets.all(20), child: Text('选择分类',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
          Expanded(child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            itemCount: categories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisExtent: 70),
            itemBuilder: (_, i) => InkWell(
              onTap: () => Navigator.pop(c, categories[i]),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(emojiForCategory(categories[i]), style: const TextStyle(fontSize: 24)),
                Text(categories[i]),
              ]),
            ),
          )),
        ]),
      )),
    );
    if (selected != null && mounted) _session.edit(draft.copyWith(category: selected));
  }
  Future<void> _save() async {
    if (_saved || _session.stage != VoiceStage.review) return;
    final d = _session.draft!;
    if (d.amount == null || d.amount! <= 0 || d.amount! > 999999999) {
      await _editAmount(); return;
    }
    _saved = true;
    widget.store.addEntry(title: d.note.isEmpty ? d.category : d.note, category: d.category,
      amount: d.amount!, isIncome: d.isIncome, date: d.date, note: d.note);
    HapticFeedback.lightImpact();
    if (mounted) Navigator.pop(context, true);
  }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _session, builder: (_, _) {
    final stage = _session.stage;
    final review = stage == VoiceStage.review;
    final busy = [VoiceStage.preparing, VoiceStage.starting, VoiceStage.recognizing].contains(stage);
    final recording = stage == VoiceStage.recording;
    final draft = _session.draft;
    final theme = Theme.of(context);
    return SafeArea(top: false, child: Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .88),
      padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Spacer(), Column(children: [Container(width: 34, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(3))),
            const SizedBox(height: 5), Text('下拉关闭', style: theme.textTheme.bodySmall?.copyWith(fontSize: 11))]),
          const Spacer(), IconButton(tooltip: '关闭语音输入', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, size: 20))]),
        Text(review ? '确认这笔账' : '语音记账', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(review ? '已识别，请核对' : recording ? '● 正在聆听… ${_session.seconds}s' : stage == VoiceStage.recognizing ? '正在识别并拆分…' : stage == VoiceStage.preparing ? '首次准备离线语音，稍等片刻…' : stage == VoiceStage.starting ? '正在开启麦克风…' : '按住说话，松开识别',
          style: theme.textTheme.bodyMedium?.copyWith(color: recording ? AppPalette.mint : theme.textTheme.bodySmall?.color)),
        const SizedBox(height: 16),
        Flexible(child: SingleChildScrollView(child: review && draft != null ? _review(draft) : Column(children: [
          Container(width: 118, height: 118, decoration: BoxDecoration(shape: BoxShape.circle, color: AppPalette.primary.withValues(alpha: .1),
            border: Border.all(width: 12, color: AppPalette.primary.withValues(alpha: .06))),
            child: busy ? const Padding(padding: EdgeInsets.all(34), child: CircularProgressIndicator(strokeWidth: 3)) : const Icon(Icons.mic_rounded, color: AppPalette.primary, size: 58)),
          const SizedBox(height: 20),
          SizedBox(height: 42, width: double.infinity, child: CustomPaint(painter: _WavePainter(recording ? _session.level : .12, AppPalette.primary, AppPalette.mint))),
          const SizedBox(height: 16), const Text('说出金额、用途和备注'), const SizedBox(height: 14),
          if (_session.error != null) Padding(padding: const EdgeInsets.only(bottom: 14), child: Text(_session.error!, style: const TextStyle(color: AppPalette.danger))),
          Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppPalette.primary.withValues(alpha: .08), borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('试着说：', style: theme.textTheme.bodySmall),
              const SizedBox(height: 6), const Text('“午饭花了二十八块五，备注牛肉面”')])),
          const SizedBox(height: 20),
        ]))),
        if (review) Padding(padding: const EdgeInsets.only(top: 16), child: Row(children: [
          Expanded(child: OutlinedButton.icon(key: const ValueKey('voice-rerecord'), onPressed: _session.rerecord,
            icon: const Icon(Icons.mic_none_rounded), label: const Text('再次录音'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 54)))),
          const SizedBox(width: 12), Expanded(child: FilledButton.icon(key: const ValueKey('voice-confirm'), onPressed: _save,
            icon: const Icon(Icons.check_rounded), label: Text(draft?.amount == null ? '补充金额' : '确认记账'), style: FilledButton.styleFrom(minimumSize: const Size(0, 54))))]))
        else Semantics(button: true, label: '按住说话，松开识别', onTap: busy ? null : () async {
          // Accessible alternative to holding for screen-reader users.
          if (recording) { await _session.release(); } else { await _session.hold(); }
        }, child: Listener(key: const ValueKey('voice-record'),
          onPointerDown: busy ? null : (_) { HapticFeedback.selectionClick(); unawaited(_session.hold()); },
          onPointerUp: (_) { unawaited(_session.release()); }, onPointerCancel: (_) { unawaited(_session.cancelHold()); },
          child: Container(height: 58, width: double.infinity, alignment: Alignment.center,
            decoration: BoxDecoration(color: busy ? theme.dividerColor : AppPalette.primary, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.mic_none_rounded, color: AppPalette.ink), const SizedBox(width: 8),
              Text(recording ? '松开后识别' : '按住说话', style: const TextStyle(color: AppPalette.ink, fontSize: 17, fontWeight: FontWeight.w700))])))),
        const SizedBox(height: 10), Text(review ? '确认后才会入账' : '语音在本机处理 · 每次最长 30 秒', style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
        const SizedBox(height: 4), GestureDetector(onTap: () => showLicensePage(context: context, applicationName: '拾光账本'),
          child: Text('Paraformer-zh · FunASR / Alibaba · 模型许可', style: theme.textTheme.bodySmall?.copyWith(fontSize: 10))),
      ])));
  });

  Widget _review(VoiceDraft draft) {
    final theme = Theme.of(context);
    return Column(children: [
      Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(border: Border.all(color: theme.dividerColor), borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('识别原文', style: theme.textTheme.bodySmall), const SizedBox(height: 7), Text(draft.rawText)])),
      const SizedBox(height: 12),
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: theme.dividerColor), borderRadius: BorderRadius.circular(20)), child: Column(children: [
        InkWell(key: const ValueKey('voice-amount'), onTap: _editAmount, borderRadius: BorderRadius.circular(12), child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [
          Expanded(child: Text(widget.store.hideAmounts ? '••••' : draft.amount == null ? '填写金额' : '¥ ${draft.amount!.toStringAsFixed(2)}',
            style: theme.textTheme.headlineSmall?.copyWith(fontSize: 30, fontWeight: FontWeight.w900))),
          Chip(label: Text(draft.isIncome ? '收入' : '支出'), backgroundColor: (draft.isIncome ? AppPalette.mint : AppPalette.primary).withValues(alpha: .12)),
          const Icon(Icons.edit_outlined, size: 17)]))),
        _field('类型', draft.isIncome ? '收入' : '支出', Icons.account_balance_wallet_outlined, _editType),
        _field('分类', draft.category, Icons.category_outlined, _editCategory),
        _field('备注', draft.note, Icons.notes_rounded, () => _editText('修改备注', draft.note, (value) => _session.edit(draft.copyWith(note: value)))),
        _field('日期', '${draft.date.year}/${draft.date.month}/${draft.date.day}', Icons.calendar_today_outlined, () async {
          final date = await showDatePicker(context: context, initialDate: draft.date,
            firstDate: DateTime(2000), lastDate: DateTime(2100));
          if (date != null && mounted) _session.edit(draft.copyWith(date: DateTime(date.year,date.month,date.day,draft.date.hour,draft.date.minute)));
        }),
      ])),
      const SizedBox(height: 10), Text('点击字段可修改', style: theme.textTheme.bodySmall),
      for (final warning in draft.warnings) Padding(padding: const EdgeInsets.only(top: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline, size: 16, color: AppPalette.primaryDeep), const SizedBox(width: 6),
        Expanded(child: Text(warning, style: theme.textTheme.bodySmall))])),
    ]);
  }
  Widget _field(String label, String value, IconData icon, VoidCallback onTap) => InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(vertical: 13), child: Row(children: [
    Icon(icon, color: AppPalette.primaryDeep, size: 21), const SizedBox(width: 12), Text(label), const SizedBox(width: 12),
    Expanded(child: Text(value, textAlign: TextAlign.right, maxLines: 2, overflow: TextOverflow.ellipsis)), const SizedBox(width: 8), const Icon(Icons.chevron_right, size: 18)])));
}
class _WavePainter extends CustomPainter {
  const _WavePainter(this.level, this.amber, this.mint);
  final double level;
  final Color amber, mint;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeWidth = 4..strokeCap = StrokeCap.round;
    for (var i = 0; i < 31; i++) {
      final h = 5 + (math.sin(i * 1.7).abs() * .6 + .4) * level * (size.height - 8);
      final x = size.width * (i + 1) / 32;
      paint.color = i % 7 < 3 ? mint.withValues(alpha: .65) : amber.withValues(alpha: .85);
      canvas.drawLine(Offset(x, (size.height - h) / 2), Offset(x, (size.height + h) / 2), paint);
    }
  }
  @override
  bool shouldRepaint(_WavePainter old) => old.level != level || old.amber != amber || old.mint != mint;
}
