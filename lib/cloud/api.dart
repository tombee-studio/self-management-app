import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../core/config/app_config.dart';
import 'contracts.dart';

typedef Json = Map<String, dynamic>;

class ApiFailure implements Exception {
  final String code;
  final bool unknownOutcome;
  final String? field;
  const ApiFailure(this.code, {this.unknownOutcome = false, this.field});
  @override
  String toString() =>
      unknownOutcome
          ? '保存結果を確認できません。同じ要求で再試行してください。'
          : switch (code) {
            'VersionConflict' => '他の端末で変更されています。最新版を取得してください。',
            'CursorInvalidated' => '一覧が更新されました。先頭から再取得してください。',
            'NotFound' => '対象データが見つかりません。',
            'ValidationFailed' => '入力内容を確認してください。${field ?? ''}',
            'InvariantViolation' => '同名のカテゴリや保護された項目を確認してください。',
            'UndoExpired' => '元に戻せる時間を過ぎました。',
            _ => '通信に失敗しました。入力と直前の表示は保持されています。',
          };
}

/// Immutable session-only command. A retry always uses the original ID and bytes.
class PendingCommand {
  final String requestId;
  final String path;
  final String body;
  PendingCommand._(this.requestId, this.path, this.body);
  factory PendingCommand.create(String operation, Json input) {
    final id = const Uuid().v4();
    return PendingCommand._(
      id,
      '/commands',
      jsonEncode({
        'schemaVersion': 3,
        'operation': operation,
        'input': input,
        'requestId': id,
      }),
    );
  }
  factory PendingCommand.payment(Json input) {
    final id = input['requestId'] as String? ?? const Uuid().v4();
    return PendingCommand._(
      id,
      '/payment',
      jsonEncode({...input, 'requestId': id}),
    );
  }
}

abstract class RemotePort {
  Future<Json> query(String operation, Json input);
  Future<Json> submit(PendingCommand command);
  Future<bool> health();
}

class HttpRemotePort implements RemotePort {
  final http.Client client;
  final String endpoint;
  final String owner;
  final Duration timeout;
  HttpRemotePort({
    http.Client? client,
    this.endpoint = AppConfig.defaultCloudSyncEndpoint,
    this.owner = AppConfig.defaultUserId,
    this.timeout = const Duration(seconds: 15),
  }) : client = client ?? http.Client();
  Uri uri(String path) =>
      Uri.parse('${endpoint.replaceAll(RegExp(r'/+$'), '')}$path');
  @override
  Future<Json> query(String operation, Json input) => _send(
    '/queries',
    jsonEncode({'schemaVersion': 3, 'operation': operation, 'input': input}),
    false,
  );
  @override
  Future<Json> submit(PendingCommand command) =>
      _send(command.path, command.body, true);
  Future<Json> _send(String path, String body, bool command) async {
    final request = jsonDecode(body) as Json;
    if (!Contract.valid(
      request,
      path == '/payment'
          ? 'PaymentInput'
          : command
          ? 'CommandRequest'
          : 'QueryRequest',
    )) {
      throw const ApiFailure('ValidationFailed');
    }
    try {
      final response = await client
          .post(
            uri(path),
            headers: {'content-type': 'application/json', 'x-user-id': owner},
            body: body,
          )
          .timeout(timeout);
      final decoded = jsonDecode(response.body);
      if (response.statusCode != 200) {
        if (!Contract.valid(decoded, 'Error')) {
          throw const FormatException('Invalid error');
        }
        throw ApiFailure(
          decoded['error'] as String,
          field: decoded['field'] as String?,
          unknownOutcome:
              command &&
              ['StorageFailure', 'TransportFailure'].contains(decoded['error']),
        );
      }
      final type =
          path == '/payment'
              ? 'PaymentResponse'
              : command
              ? 'CommandResponse'
              : 'QueryResponse';
      if (!Contract.valid(decoded, type) ||
          (path != '/payment' &&
              decoded['operation'] != request['operation']) ||
          (command && decoded['requestId'] != request['requestId'])) {
        throw const FormatException('Invalid response');
      }
      return decoded as Json;
    } on ApiFailure {
      rethrow;
    } catch (_) {
      throw ApiFailure('TransportFailure', unknownOutcome: command);
    }
  }

  @override
  Future<bool> health() async {
    try {
      final r = await client.get(uri('/health')).timeout(timeout);
      return r.statusCode == 200 &&
          Contract.valid(jsonDecode(r.body), 'HealthResponse');
    } catch (_) {
      return false;
    }
  }

  void close() => client.close();
}
