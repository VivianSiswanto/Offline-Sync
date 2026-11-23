import 'dart:io';

class AppConfig {
  static const _override = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    return Platform.isAndroid
        ? 'http://10.0.2.2:5050'
        : 'http://localhost:5050';
  }

  static const syncInterval = Duration(seconds: 30);
  static const pushBatchSize = 50;
}
