import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:signalr_netcore/signalr_client.dart';

/// Dart wrapper for the SignalR JobHub (/hubs/jobs).
///
/// Connects with the JWT token from secure storage.
/// Callers subscribe to job events via [onJobStatusChanged] and [onNewJobMatch].
///
/// Usage:
/// ```dart
/// final hub = JobHubClient(storage);
/// await hub.connect(baseUrl: 'http://localhost:5000');
/// hub.onJobStatusChanged.listen((e) { ... });
/// await hub.joinJobGroup('42');
/// ```
class JobHubClient {
  final FlutterSecureStorage _storage;

  HubConnection? _connection;

  final _statusController =
      StreamController<JobStatusEvent>.broadcast();
  final _matchController =
      StreamController<NewJobMatchEvent>.broadcast();

  /// Stream of job status change events from the server.
  Stream<JobStatusEvent> get onJobStatusChanged => _statusController.stream;

  /// Stream of new-job-match events (tradie receives these).
  Stream<NewJobMatchEvent> get onNewJobMatch => _matchController.stream;

  JobHubClient(this._storage);

  /// Connects to the SignalR hub. Call once per session.
  Future<void> connect({required String baseUrl}) async {
    if (_connection != null &&
        _connection!.state == HubConnectionState.Connected) return;

    final token = await _storage.read(key: 'jwt_token');

    _connection = HubConnectionBuilder()
        .withUrl(
          '$baseUrl/hubs/jobs',
          options: HttpConnectionOptions(
            accessTokenFactory: () async => token ?? '',
          ),
        )
        .withAutomaticReconnect()
        .build();

    _connection!.on('JobStatusChanged', (args) {
      if (args == null || args.length < 2) return;
      final jobId = args[0]?.toString() ?? '';
      final status = args[1]?.toString() ?? '';
      _statusController.add(JobStatusEvent(jobId: jobId, status: status));
    });

    _connection!.on('NewJobMatch', (args) {
      if (args == null || args.isEmpty) return;
      final data = args[0] as Map<String, dynamic>?;
      if (data != null) _matchController.add(NewJobMatchEvent.fromJson(data));
    });

    await _connection!.start();
  }

  /// Subscribe to updates for a specific job.
  Future<void> joinJobGroup(String jobId) async {
    await _connection?.invoke('JoinJobGroup', args: [jobId]);
  }

  /// Unsubscribe from a job's updates.
  Future<void> leaveJobGroup(String jobId) async {
    await _connection?.invoke('LeaveJobGroup', args: [jobId]);
  }

  Future<void> disconnect() async {
    await _connection?.stop();
    _connection = null;
  }

  void dispose() {
    _statusController.close();
    _matchController.close();
    disconnect();
  }
}

class JobStatusEvent {
  final String jobId;
  final String status;
  const JobStatusEvent({required this.jobId, required this.status});
}

class NewJobMatchEvent {
  final String jobId;
  final String title;
  final String category;
  final String urgency;
  final String? address;
  final String distanceKm;

  const NewJobMatchEvent({
    required this.jobId,
    required this.title,
    required this.category,
    required this.urgency,
    this.address,
    required this.distanceKm,
  });

  factory NewJobMatchEvent.fromJson(Map<String, dynamic> json) =>
      NewJobMatchEvent(
        jobId: json['jobId']?.toString() ?? '',
        title: json['title'] as String? ?? '',
        category: json['category'] as String? ?? '',
        urgency: json['urgency'] as String? ?? '',
        address: json['address'] as String?,
        distanceKm: json['distanceKm'] as String? ?? '',
      );
}
