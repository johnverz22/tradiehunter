import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixo/repositories/job_hub_client.dart';

/// Records raw join/leave calls so the ref-counting in watchJob/unwatchJob can
/// be checked without a live SignalR connection.
class _RecordingHub extends JobHubClient {
  _RecordingHub() : super(const FlutterSecureStorage());

  final calls = <String>[];
  bool failJoin = false;

  @override
  Future<void> joinJobGroup(String jobId) async {
    calls.add('join:$jobId');
    if (failJoin) throw StateError('not connected');
  }

  @override
  Future<void> leaveJobGroup(String jobId) async {
    calls.add('leave:$jobId');
  }
}

void main() {
  test('two watchers share one join; last unwatch leaves', () async {
    final hub = _RecordingHub();
    await hub.watchJob('7');
    await hub.watchJob('7');
    expect(hub.calls, ['join:7']);

    await hub.unwatchJob('7');
    expect(hub.calls, ['join:7']);

    await hub.unwatchJob('7');
    expect(hub.calls, ['join:7', 'leave:7']);
  });

  test('unwatch without watch is a no-op', () async {
    final hub = _RecordingHub();
    await hub.unwatchJob('7');
    expect(hub.calls, isEmpty);
  });

  test('a failed join (hub not connected yet) does not throw', () async {
    final hub = _RecordingHub()..failJoin = true;
    await hub.watchJob('7');
    expect(hub.calls, ['join:7']);
  });

  test('different jobs are independent', () async {
    final hub = _RecordingHub();
    await hub.watchJob('1');
    await hub.watchJob('2');
    await hub.unwatchJob('1');
    expect(hub.calls, ['join:1', 'join:2', 'leave:1']);
  });
}
