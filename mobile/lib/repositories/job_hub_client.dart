import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:signalr_netcore/signalr_client.dart';

/// Dart wrapper for the SignalR JobHub (/hubs/jobs).
///
/// Connects with the JWT token from secure storage.
/// Callers subscribe to job events via [onJobStatusChanged], [onNewJobMatch]
/// and [onOfferLifecycle].
///
/// Usage:
/// ```dart
/// final hub = JobHubClient(storage);
/// await hub.connect(baseUrl: 'http://localhost:5000');
/// hub.onJobStatusChanged.listen((e) { ... });
/// hub.onOfferLifecycle.listen((e) { ... });
/// await hub.joinJobGroup('42');
/// ```
class JobHubClient {
  final FlutterSecureStorage _storage;

  HubConnection? _connection;

  final _statusController = StreamController<JobStatusEvent>.broadcast();
  final _matchController = StreamController<NewJobMatchEvent>.broadcast();
  final _offerController = StreamController<OfferLifecycleEvent>.broadcast();
  final _reconnectingController = StreamController<void>.broadcast();
  final _reconnectedController = StreamController<void>.broadcast();

  /// Stream of job status change events from the server.
  Stream<JobStatusEvent> get onJobStatusChanged => _statusController.stream;

  /// Stream of new-job-match events (tradie receives these).
  Stream<NewJobMatchEvent> get onNewJobMatch => _matchController.stream;

  /// Stream of sequential-offer lifecycle events (P3-10): OfferCreated,
  /// OfferExpired, OfferAccepted, OfferDeclined. The homeowner matching
  /// screen renders progress from these; the tradie request-detail screen
  /// uses them to stop its expiry countdown.
  Stream<OfferLifecycleEvent> get onOfferLifecycle => _offerController.stream;

  /// Fires when the automatic-reconnect policy drops the live connection.
  /// Events stop arriving until [onReconnected] fires; server-side job-group
  /// membership is lost at that point, so listeners must re-join and re-read
  /// state once reconnected.
  Stream<void> get onReconnecting => _reconnectingController.stream;

  /// Fires once per successful reconnect. Group membership does not survive
  /// reconnect — re-invoke [joinJobGroup] and re-read any cached state.
  Stream<void> get onReconnected => _reconnectedController.stream;

  JobHubClient(this._storage);

  /// Connects to the SignalR hub. Call once per session.
  Future<void> connect({required String baseUrl}) async {
    if (_connection != null &&
        _connection!.state == HubConnectionState.Connected)
      return;

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
      if (args == null || args.isEmpty) return;
      final data = args.first as Map<String, dynamic>?;
      if (data != null) {
        _statusController.add(JobStatusEvent.fromJson(data));
      }
    });

    _connection!.on('NewJobMatch', (args) {
      if (args == null || args.isEmpty) return;
      final data = args[0] as Map<String, dynamic>?;
      if (data != null) _matchController.add(NewJobMatchEvent.fromJson(data));
    });

    _connection!.on('OfferLifecycleEvent', (args) {
      if (args == null || args.isEmpty) return;
      final data = args.first as Map<String, dynamic>?;
      if (data != null) {
        _offerController.add(OfferLifecycleEvent.fromJson(data));
      }
    });

    _connection!.onreconnecting(({error}) => _reconnectingController.add(null));
    _connection!.onreconnected(
      ({connectionId}) => _reconnectedController.add(null),
    );

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
    _offerController.close();
    _reconnectingController.close();
    _reconnectedController.close();
    disconnect();
  }
}

/// Lifecycle kinds emitted by the server for a sequential job offer.
enum OfferEventType {
  created,
  expired,
  accepted,
  declined,
  unknown;

  static OfferEventType parse(String? raw) => switch (raw?.toLowerCase()) {
    'offercreated' => OfferEventType.created,
    'offerexpired' => OfferEventType.expired,
    'offeraccepted' => OfferEventType.accepted,
    'offerdeclined' => OfferEventType.declined,
    _ => OfferEventType.unknown,
  };
}

/// A job-status transition pushed over the hub. Mirrors the server's
/// JobStatusChangedPayload.
class JobStatusEvent {
  final String jobId;
  final String status;
  final String previousStatus;
  final String? reasonCode;
  final String? reason;

  const JobStatusEvent({
    required this.jobId,
    required this.status,
    this.previousStatus = '',
    this.reasonCode,
    this.reason,
  });

  factory JobStatusEvent.fromJson(Map<String, dynamic> json) => JobStatusEvent(
    jobId: json['jobId']?.toString() ?? '',
    status: json['status'] as String? ?? '',
    previousStatus: json['previousStatus'] as String? ?? '',
    reasonCode: json['reasonCode'] as String?,
    reason: json['reason'] as String?,
  );
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

/// A sequential-offer lifecycle event (P3-10). Mirrors the server's
/// OfferLifecyclePayload.
class OfferLifecycleEvent {
  final OfferEventType eventType;
  final String jobId;
  final String offerId;
  final String tradieId;
  final DateTime? expiresAtUtc;
  final String? jobTitle;

  /// 1-based position of this offer in the job's matching run. Zero when the
  /// server did not supply one (e.g. accept/decline responses).
  final int offerIndex;

  const OfferLifecycleEvent({
    required this.eventType,
    required this.jobId,
    required this.offerId,
    required this.tradieId,
    this.expiresAtUtc,
    this.jobTitle,
    this.offerIndex = 0,
  });

  factory OfferLifecycleEvent.fromJson(Map<String, dynamic> json) =>
      OfferLifecycleEvent(
        eventType: OfferEventType.parse(json['eventType'] as String?),
        jobId: json['jobId']?.toString() ?? '',
        offerId: json['offerId']?.toString() ?? '',
        tradieId: json['tradieId'] as String? ?? '',
        expiresAtUtc: json['expiresAtUtc'] != null
            ? DateTime.parse(json['expiresAtUtc'] as String).toUtc()
            : null,
        jobTitle: json['jobTitle'] as String?,
        offerIndex: (json['offerIndex'] as num?)?.toInt() ?? 0,
      );
}
