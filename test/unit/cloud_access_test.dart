import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iris_app/cloud/api.dart';
import 'package:iris_app/cloud/contracts.dart';
import 'package:iris_app/cloud/session.dart';

void main() {
  final fixtures =
      (jsonDecode(File('test/fixtures/api-v3.json').readAsStringSync()) as List)
          .cast<Json>();
  test(
    'all provider command/query/payment fixtures are consumed with matching types',
    () async {
      for (final f in fixtures) {
        expect(
          Contract.valid(
            f['response'],
            f['path'] == '/payment'
                ? 'PaymentResponse'
                : f['path'] == '/commands'
                ? 'CommandResponse'
                : 'QueryResponse',
          ),
          true,
          reason: f['request'].toString(),
        );
        final port = HttpRemotePort(
          client: MockClient((request) async {
            expect(request.url.path, f['path']);
            expect(request.headers['x-user-id'], isNotEmpty);
            final body = jsonDecode(request.body) as Json;
            if (f['path'] != '/payment') {
              expect(body['operation'], f['request']['operation']);
              expect(body['input'], f['request']['input']);
            }
            final response = Map<String, dynamic>.from(f['response'] as Map);
            if (body['requestId'] != null) {
              response['requestId'] = body['requestId'];
            }
            return http.Response.bytes(utf8.encode(jsonEncode(response)), 200);
          }),
        );
        final request = f['request'] as Json;
        final result =
            f['path'] == '/queries'
                ? await port.query(
                  request['operation'] as String,
                  request['input'] as Json,
                )
                : await port.submit(
                  f['path'] == '/payment'
                      ? PendingCommand.payment(request)
                      : PendingCommand.create(
                        request['operation'] as String,
                        request['input'] as Json,
                      ),
                );
        expect(result['schemaVersion'], 3);
        port.close();
      }
    },
  );
  test(
    'timeout keeps immutable command bytes and request ID for retry',
    () async {
      final sent = <String>[];
      bool fail = true;
      final f = fixtures.firstWhere(
        (f) => f['request']['operation'] == 'RecordExpense',
      );
      final api = HttpRemotePort(
        client: MockClient((request) async {
          sent.add(request.body);
          if (fail) throw TimeoutException('lost response');
          final body = jsonDecode(request.body);
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                ...f['response'] as Json,
                'requestId': body['requestId'],
              }),
            ),
            200,
          );
        }),
      );
      final s = CloudSession(api: api, loadSettings: false);
      final input = Map<String, dynamic>.from(f['request']['input'] as Json);
      await expectLater(
        s.command('form', 'RecordExpense', input),
        throwsA(
          isA<ApiFailure>().having((e) => e.unknownOutcome, 'unknown', true),
        ),
      );
      input['amount'] = 9999;
      fail = false;
      await s.command('form', 'RecordExpense', input);
      expect(sent[0], sent[1]);
      expect(s.hasPending('form'), false);
      await s.close();
    },
  );
  test(
    'query failure retains previous projection and restart has no offline data',
    () async {
      bool fail = false;
      final f = fixtures.firstWhere(
        (f) => f['request']['operation'] == 'GetCatalog',
      );
      final api = HttpRemotePort(
        client: MockClient((_) async {
          if (fail) throw Exception('offline');
          return http.Response.bytes(
            utf8.encode(jsonEncode(f['response'])),
            200,
          );
        }),
      );
      final s = CloudSession(api: api, loadSettings: false);
      await s.fetch('catalog', 'GetCatalog', {});
      final original = s.catalog;
      fail = true;
      await s.fetch('catalog', 'GetCatalog', {});
      expect(s.catalog, original);
      expect(s.slot('catalog').error, isNotNull);
      final restarted = CloudSession(api: api, loadSettings: false);
      expect(restarted.catalog, isNull);
      await restarted.fetch('catalog', 'GetCatalog', {});
      expect(restarted.catalog, isNull);
      await s.close();
    },
  );
  test(
    'wrong operation, malformed JSON, extra SDK attributes and legacy version cannot be success',
    () async {
      final f = fixtures.firstWhere(
        (f) => f['request']['operation'] == 'GetCatalog',
      );
      for (final invalid in [
        '{',
        jsonEncode({...f['response'] as Json, 'schemaVersion': 2}),
        jsonEncode({...f['response'] as Json, 'operation': 'GetExpense'}),
        jsonEncode({...f['response'] as Json, 'ownerId': 'leaked'}),
      ]) {
        final api = HttpRemotePort(
          client: MockClient(
            (_) async => http.Response.bytes(utf8.encode(invalid), 200),
          ),
        );
        await expectLater(
          api.query('GetCatalog', {}),
          throwsA(isA<ApiFailure>()),
        );
        api.close();
      }
    },
  );
  test('contract enforces money, graphemes and UUID', () {
    final f = Map<String, dynamic>.from(
      fixtures.firstWhere(
            (f) => f['request']['operation'] == 'RecordExpense',
          )['request']
          as Json,
    );
    for (final n in [0, -1, 100000000]) {
      final input = {...f['input'] as Json, 'amount': n};
      expect(Contract.valid({...f, 'input': input}, 'CommandRequest'), false);
    }
    expect(
      Contract.valid({
        ...f,
        'input': {
          ...f['input'] as Json,
          'memo': List.filled(100, '👨‍👩‍👧').join(),
        },
      }, 'CommandRequest'),
      true,
    );
    expect(Contract.valid({...f, 'requestId': 'bad'}, 'CommandRequest'), false);
  });
}
