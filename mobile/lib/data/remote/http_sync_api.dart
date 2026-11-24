import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../../domain/entities/item.dart';
import '../models/item_mapper.dart';
import 'sync_api.dart';

class HttpSyncApi implements SyncApi {
  HttpSyncApi({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  final Duration timeout;

  @override
  Future<PushResult> push(List<Item> changes) async {
    final response = await _send(
      () => _client.post(
        Uri.parse('$baseUrl/api/sync/push'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'changes': changes.map((i) => i.toJson()).toList()}),
      ),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return PushResult(
      accepted: (body['accepted'] as List).cast<String>().toSet(),
    );
  }

  @override
  Future<PullResult> pull(int since) async {
    final response = await _send(
      () => _client.get(Uri.parse('$baseUrl/api/sync/pull?since=$since')),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final changes = (body['changes'] as List)
        .map((json) => itemFromJson(json as Map<String, dynamic>))
        .toList();
    return PullResult(changes: changes, cursor: body['cursor'] as int);
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request().timeout(timeout);
    } on TimeoutException {
      throw SyncException('Request timed out', retryable: true);
    } on SocketException catch (e) {
      throw SyncException('No connection: ${e.message}', retryable: true);
    } on http.ClientException catch (e) {
      throw SyncException('Network error: ${e.message}', retryable: true);
    }

    if (response.statusCode >= 200 && response.statusCode < 300)
      return response;

    final retryable = response.statusCode >= 500 || response.statusCode == 429;
    throw SyncException(
      'Server returned ${response.statusCode}: ${response.body}',
      retryable: retryable,
    );
  }
}
