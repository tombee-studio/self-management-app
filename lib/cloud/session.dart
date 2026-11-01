import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/app_config.dart';
import 'api.dart';

final sessionProvider = ChangeNotifierProvider<CloudSession>((ref) {
  final session = CloudSession();
  ref.onDispose(session.close);
  return session;
});

class Projection {
  dynamic value;
  ApiFailure? error;
  bool loading = false;
  int revision = 0;
  DateTime? lastSuccess;
}

/// Holds display projections and drafts in process memory only.
class CloudSession extends ChangeNotifier {
  RemotePort api;
  String timeZone;
  String endpoint;
  final bool loadSettings;
  bool ready = false;
  int mutationRevision = 0;
  bool _closed = false;
  String? startupError;
  DateTime? lastSuccessfulAccess;
  bool get hasReadError => _projections.values.any((p) => p.error != null);
  final Map<String, Projection> _projections = {};
  final Map<String, PendingCommand> _pending = {};
  CloudSession({
    RemotePort? api,
    this.timeZone = 'Asia/Tokyo',
    this.loadSettings = true,
  }) : api = api ?? HttpRemotePort(),
       endpoint = AppConfig.defaultCloudSyncEndpoint;
  Projection slot(String key) => _projections.putIfAbsent(key, Projection.new);
  Json? get catalog => slot('catalog').value as Json?;
  Json? get budget => slot('budget').value as Json?;
  List<Json> get categories =>
      (catalog?['categories'] as List? ?? []).cast<Json>();
  void update() {
    if (!_closed) notifyListeners();
  }

  Future<void> start() async {
    if (ready) return;
    try {
      if (loadSettings) {
        final prefs = await SharedPreferences.getInstance();
        endpoint =
            prefs.getString('iris_api_endpoint') ??
            AppConfig.defaultCloudSyncEndpoint;
        if (api is HttpRemotePort) {
          (api as HttpRemotePort).close();
          api = HttpRemotePort(endpoint: endpoint);
        }
        timeZone =
            await const MethodChannel(
              'com.iris.app/device',
            ).invokeMethod<String>('timeZone') ??
            timeZone;
      }
      await command('startup', 'EnsureDefaultCatalog', {});
      await refreshCommon();
      if (catalog == null) {
        throw slot('catalog').error ?? const ApiFailure('StorageFailure');
      }
      ready = true;
      startupError = null;
    } catch (e) {
      startupError = e.toString();
    }
    update();
  }

  Future<void> configureEndpoint(String value) async {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty) {
      throw const ApiFailure('ValidationFailed');
    }
    if (_pending.isNotEmpty) throw const ApiFailure('VersionConflict');
    final next = value.trim().replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('iris_api_endpoint', next);
    if (api is HttpRemotePort) (api as HttpRemotePort).close();
    endpoint = next;
    api = HttpRemotePort(endpoint: next);
    _projections.clear();
    ready = false;
    await start();
  }

  Future<void> refreshCommon() async {
    await Future.wait([
      fetch('catalog', 'GetCatalog', {}),
      fetch('budget', 'GetBudgetPlan', {}, missingAllowed: true),
    ]);
  }

  Future<dynamic> fetch(
    String key,
    String operation,
    Json input, {
    bool missingAllowed = false,
  }) async {
    final p = slot(key);
    final revision = ++p.revision;
    p.loading = true;
    update();
    try {
      final r = await api.query(operation, input);
      if (revision == p.revision) {
        p.value = r['value'];
        p.error = null;
        p.lastSuccess = DateTime.now();
        lastSuccessfulAccess = p.lastSuccess;
      }
      return r['value'];
    } on ApiFailure catch (e) {
      if (revision == p.revision) {
        if (missingAllowed && e.code == 'NotFound') {
          p.value = null;
          p.error = null;
        } else {
          p.error = e;
        }
      }
      return null;
    } finally {
      if (revision == p.revision) {
        p.loading = false;
        update();
      }
    }
  }

  bool hasPending(String key) => _pending.containsKey(key);
  Future<Json> command(String key, String operation, Json input) async {
    final pending = _pending.putIfAbsent(
      key,
      () => PendingCommand.create(operation, input),
    );
    return _submit(key, pending);
  }

  Future<Json> payment(String key, Json input) => _submit(
    key,
    _pending.putIfAbsent(key, () => PendingCommand.payment(input)),
  );
  Future<Json> _submit(String key, PendingCommand pending) async {
    try {
      final r = await api.submit(pending);
      _pending.remove(key);
      lastSuccessfulAccess = DateTime.now();
      final operation = jsonDecode(pending.body)['operation'];
      if (pending.path == '/payment' ||
          [
            'RecordExpense',
            'ModifyExpense',
            'DeleteExpense',
            'RestoreExpense',
            'ConfigureBudgetPlan',
          ].contains(operation)) {
        mutationRevision++;
        update();
      }
      return r;
    } on ApiFailure catch (e) {
      if (!e.unknownOutcome) _pending.remove(key);
      rethrow;
    }
  }

  Future<Json> getExpense(String id) async =>
      (await api.query('GetExpense', {'id': id}))['value'] as Json;
  Future<void> refreshVisible() async {
    final requests =
        _projections.entries
            .where((e) => e.key.startsWith('daily:'))
            .map((e) => e.key.substring(6))
            .toList();
    await refreshCommon();
    for (final date in requests) {
      await daily(date);
    }
  }

  Future<void> daily(String date) => fetch('daily:$date', 'WatchDailySummary', {
    'date': date,
    'timeZone': timeZone,
  });
  Future<void> close() async {
    _closed = true;
    if (api is HttpRemotePort) (api as HttpRemotePort).close();
  }
}

String dateText(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String monthText(DateTime d) => dateText(d).substring(0, 7);
String canonicalInput(Json value) => jsonEncode(value);
