import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/entities/item.dart';
import '../../domain/repositories/item_repository.dart';
import '../../sync/sync_engine.dart';
import '../widgets/sync_status_banner.dart';
import 'item_form_page.dart';

class ItemListPage extends StatefulWidget {
  const ItemListPage({
    super.key,
    required this.repository,
    required this.syncEngine,
  });

  final ItemRepository repository;
  final SyncEngine syncEngine;

  @override
  State<ItemListPage> createState() => _ItemListPageState();
}

class _ItemListPageState extends State<ItemListPage> {
  List<Item> _items = [];
  bool _loading = true;
  StreamSubscription<void>? _changesSub;

  @override
  void initState() {
    super.initState();
    _changesSub = widget.repository.changes.listen((_) => _load());
    _load();
  }

  @override
  void dispose() {
    _changesSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final items = await widget.repository.getItems();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _openForm({Item? existing}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ItemFormPage(repository: widget.repository, existing: existing),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Sync'),
        actions: [
          IconButton(
            tooltip: 'Sync now',
            icon: const Icon(Icons.sync),
            onPressed: widget.syncEngine.sync,
          ),
        ],
      ),
      body: Column(
        children: [
          SyncStatusBanner(state: widget.syncEngine.state),
          Expanded(
            child: RefreshIndicator(
              onRefresh: widget.syncEngine.sync,
              child: _buildList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: Text('No items yet. Tap + to add one, even offline.')),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final item = _items[i];
        return Dismissible(
          key: ValueKey(item.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) {
            setState(() => _items.removeWhere((x) => x.id == item.id));
            widget.repository.deleteItem(item.id);
          },
          child: ListTile(
            title: Text(item.title),
            subtitle: item.notes.isEmpty
                ? null
                : Text(
                    item.notes,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            trailing: Icon(
              item.isPending
                  ? Icons.cloud_upload_outlined
                  : Icons.cloud_done_outlined,
              color: item.isPending ? Colors.orange : Colors.green,
            ),
            onTap: () => _openForm(existing: item),
          ),
        );
      },
    );
  }
}
