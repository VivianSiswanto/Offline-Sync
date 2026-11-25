import 'package:flutter/material.dart';
import 'package:offline_sync/core/config.dart';
import 'package:offline_sync/data/local/sqflite_item_local_store.dart';
import 'package:offline_sync/data/remote/http_sync_api.dart';
import 'package:offline_sync/data/repositories/item_repository_impl.dart';
import 'package:offline_sync/domain/repositories/item_repository.dart';
import 'package:offline_sync/presentation/pages/item_list_page.dart';
import 'package:offline_sync/sync/sync_engine.dart';
import 'package:offline_sync/sync/sync_scheduler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final local = await SqfliteItemLocalStore.open();
  final api = HttpSyncApi(baseUrl: AppConfig.apiBaseUrl);
  final repository = ItemRepositoryImpl(local);

  final engine = SyncEngine(
    local: local,
    api: api,
    batchSize: AppConfig.pushBatchSize,
    onDataChanged: repository.notifyChanged,
  );

  final scheduler = SyncScheduler(engine, interval: AppConfig.syncInterval);

  repository.onLocalWrite = () {
    engine.refreshPendingCount();
    scheduler.requestSync();
  };
  scheduler.start();

  runApp(OfflineSyncApp(repository: repository, syncEngine: engine));
}

class OfflineSyncApp extends StatelessWidget {
  const OfflineSyncApp({
    super.key,
    required this.repository,
    required this.syncEngine,
  });

  final ItemRepository repository;
  final SyncEngine syncEngine;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline Sync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: ItemListPage(repository: repository, syncEngine: syncEngine),
    );
  }
}
