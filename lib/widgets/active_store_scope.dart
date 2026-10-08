import 'package:flutter/widgets.dart';
import '../app_store.dart';

// Keep page state and scroll positions while deferring hidden-page data rebuilds.
class ActiveStoreScope extends StatefulWidget {
  const ActiveStoreScope({super.key, required this.store, required this.active, required this.child});
  final AppStore store;
  final bool active;
  final Widget child;
  @override
  State<ActiveStoreScope> createState() => _ActiveStoreScopeState();
}
class _ActiveStoreScopeState extends State<ActiveStoreScope> {
  final _updates = ChangeNotifier();
  bool _dirty = false;
  @override
  void initState() { super.initState(); widget.store.addListener(_changed); }
  void _changed() {
    if (widget.active) _updates.notifyListeners();
    else _dirty = true;
  }
  @override
  void didUpdateWidget(covariant ActiveStoreScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_changed);
      widget.store.addListener(_changed);
      _dirty = true;
    }
    if (widget.active && _dirty) { _dirty = false; _updates.notifyListeners(); }
  }
  @override
  void dispose() { widget.store.removeListener(_changed); _updates.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AppStoreScope(store: widget.store, updates: _updates, child: widget.child);
}
