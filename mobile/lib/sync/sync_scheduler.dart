import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'sync_engine.dart';

class SyncScheduler with WidgetsBindingObserver {
  SyncScheduler(
    this.engine, {
    Connectivity? connectivity,
    this.interval = const Duration(seconds: 30),
  }) : _connectivity = connectivity ?? Connectivity();

  final SyncEngine engine;
  final Duration interval;
  final Connectivity _connectivity;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _periodic;
  Timer? _debounce;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) requestSync();
    });

    _periodic = Timer.periodic(interval, (_) => requestSync());
    requestSync();
  }

  void requestSync() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), engine.sync);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) requestSync();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub?.cancel();
    _periodic?.cancel();
    _debounce?.cancel();
  }
}
