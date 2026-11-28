import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
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
/// await hub.watchJob('42'); // ref-counted; re-joined automatically on reconnect
/// ```
class JobHubClient {
  final FlutterSecureStorage _storage;

  HubConnection? _connection;

  /// In-flight [connect], so concurrent callers (home screen + job screen on a
  /// deep link) share one connection attempt instead of building two.
  Future<void>? _connecting;

  Timer? _heartbeatTimer;
  bool _heartbeatEnabled = false;

  /// Job groups screens currently want live updates for, with a reference
  /// count so two screens watching the same job don't undo each other.
  /// Server-side group membership is per connection, so this is the source of
  /// truth used to re-join after a reconnect.
  final Map<String, int> _watched = {};

  final _statusController = StreamController<JobStatusEvent>.broadcast();
  final _matchController = StreamController<NewJobMatchEvent>.broadcast();
  final _offerController = StreamController<OfferLifecycleEvent>.broadcast();
  final _adjustmentController =
      StreamController<JobAdjustmentEvent>.broadcast();
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

  /// Stream of v1.7 price-adjustment events (P12-18, `JobAdjustmentChanged`).
  /// Listeners reload the job's adjustment list — the payload shape is
  /// server-owned, so only the jobId is surfaced here.
  Stream<JobAdjustmentEvent> get onAdjustmentChanged =>
      _adjustmentController.stream;

  /// Fires when the automatic-reconnect policy drops the live connection.
  /// Events stop arriving until [onReconnected] fires; listeners should re-read
  /// state once reconnected.
  Stream<void> get onReconnecting => _reconnectingController.stream;

  /// Fires once per successful reconnect, after watched job groups have been
  /// re-joined (see [watchJob]). Events may have been missed while down, so
  /// listeners should re-read any cached state.
  Stream<void> get onReconnected => _reconnectedController.stream;

  JobHubClient(this._storage);

  /// Connects to the SignalR hub. Safe to call from several screens: returns
  /// immediately when already connected, and concurrent calls share one
  /// attempt. Any jobs registered through [watchJob] beforehand are joined once
  /// the connection is up.
  Future<void> connect({required String baseUrl}) {
    final state = _connection?.state;
    if (state == HubConnectionState.Connected ||
        state == HubConnectionState.Reconnecting) {
      return Future.value();
    }
    return _connecting ??= _connect(baseUrl).whenComplete(() {
      _connecting = null;
    });
  }

  Future<void> _connect(String baseUrl) async {
    final stale = _connection;
    if (stale != null) {
      unawaited(stale.stop().catchError((Object _) {}));
    }

    final conn = HubConnectionBuilder()
        .withUrl(
          '$baseUrl/hubs/jobs',
          options: HttpConnectionOptions(
            // Read per (re)connect so a refreshed JWT is picked up.
            accessTokenFactory: () async =>
                await _storage.read(key: 'jwt_token') ?? '',
          ),
        )
        .withAutomaticReconnect()
        .build();
    _connection = conn;

    conn.on('JobStatusChanged', (args) {
      if (args == null || args.isEmpty) return;
      final data = args.first as Map<String, dynamic>?;
      if (data != null) {
        _statusController.add(JobStatusEvent.fromJson(data));
      }
    });

    conn.on('NewJobMatch', (args) {
      if (args == null || args.isEmpty) return;
      final data = args[0] as Map<String, dynamic>?;
      if (data != null) _matchController.add(NewJobMatchEvent.fromJson(data));
    });

    conn.on('OfferLifecycleEvent', (args) {
      if (args == null || args.isEmpty) return;
      final data = args.first as Map<String, dynamic>?;
      if (data != null) {
        _offerController.add(OfferLifecycleEvent.fromJson(data));
      }
    });

    conn.on('JobAdjustmentChanged', (args) {
      if (args == null || args.isEmpty) return;
      final first = args.first;
      // Payload is server-owned — surface the jobId only; the payload may be
      // a flat map or nested under "adjustment".
      String? jobId;
      if (first is Map) {
        final map = Map<String, dynamic>.from(first);
        jobId =
            (map['jobId'] ??
                    (map['adjustment'] is Map
                        ? (map['adjustment'] as Map)['jobId']
                        : null))
                ?.toString();
      }
      if (jobId != null) {
        _adjustmentController.add(JobAdjustmentEvent(jobId: jobId));
      }
    });

    conn.onreconnecting(({error}) {
      if (!_reconnectingController.isClosed) _reconnectingController.add(null);
    });
    conn.onreconnected(({connectionId}) {
      unawaited(_afterReconnect());
    });

    await conn.start();
    await _syncWatched();
    if (_heartbeatEnabled) {
      unawaited(sendHeartbeat());
    }
  }

  /// Re-joins every watched job group (membership is lost on reconnect) and
  /// only then tells listeners, so their state re-read can't race the join.
  Future<void> _afterReconnect() async {
    await _syncWatched();
    if (_heartbeatEnabled) {
      unawaited(sendHeartbeat());
    }
    if (!_reconnectedController.isClosed) _reconnectedController.add(null);
  }

  /// Enables or pauses the 30-second tradie presence heartbeat (QA §1).
  /// Immediately sends a heartbeat when enabled while connected.
  void setHeartbeatEnabled(bool enabled) {
    _heartbeatEnabled = enabled;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    if (!enabled) return;
    unawaited(sendHeartbeat());
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(sendHeartbeat()),
    );
  }

  /// Sends one presence heartbeat to JobHub if currently connected.
  Future<void> sendHeartbeat() async {
    final conn = _connection;
    if (conn == null || conn.state != HubConnectionState.Connected) return;
    try {
      await conn.invoke('Heartbeat');
    } catch (e) {
      debugPrint('JobHub heartbeat failed (ignored): $e');
    }
  }

  /// Starts receiving `JobStatusChanged` for [jobId]. Ref-counted: every call
  /// must be balanced by one [unwatchJob]. Safe before the hub is connected or
  /// while it is reconnecting — the join is retried on connect/reconnect.
  Future<void> watchJob(String jobId) async {
    final count = _watched[jobId] ?? 0;
    _watched[jobId] = count + 1;
    if (count == 0) await _tryJoin(jobId);
  }

  /// Releases one [watchJob]; leaves the group when the last watcher is gone.
  Future<void> unwatchJob(String jobId) async {
    final count = _watched[jobId];
    if (count == null) return;
    if (count > 1) {
      _watched[jobId] = count - 1;
      return;
    }
    _watched.remove(jobId);
    try {
      await leaveJobGroup(jobId);
    } catch (e) {
      debugPrint('JobHub leave $jobId failed (ignored): $e');
    }
  }

  /// Job ids each owner (e.g. a home screen listing many jobs) wants watched.
  final Map<Object, Set<String>> _ownedWatches = {};

  /// Makes [owner] watch exactly [jobIds]: joins the new ones and releases the
  /// ones it no longer lists. For screens whose set of jobs changes over time;
  /// pair with [clearWatchedJobs] in `dispose`.
  Future<void> setWatchedJobs(Object owner, Set<String> jobIds) async {
    final previous = _ownedWatches[owner] ?? const <String>{};
    final next = Set<String>.of(jobIds);
    // Record before awaiting so overlapping calls diff against the latest set.
    _ownedWatches[owner] = next;
    for (final id in next.difference(previous)) {
      await watchJob(id);
    }
    for (final id in previous.difference(next)) {
      await unwatchJob(id);
    }
  }

  /// Releases everything [owner] holds via [setWatchedJobs].
  Future<void> clearWatchedJobs(Object owner) async {
    final previous = _ownedWatches.remove(owner) ?? const <String>{};
    for (final id in previous) {
      await unwatchJob(id);
    }
  }

  Future<void> _tryJoin(String jobId) async {
    try {
      await joinJobGroup(jobId);
    } catch (e) {
      // Not connected yet / mid-reconnect: _syncWatched re-joins later.
      debugPrint('JobHub join $jobId deferred: $e');
    }
  }

  Future<void> _syncWatched() async {
    for (final jobId in _watched.keys.toList()) {
      await _tryJoin(jobId);
    }
  }

  /// Raw group join for one connection. Screens should use [watchJob], which
  /// ref-counts and survives reconnects.
  Future<void> joinJobGroup(String jobId) async {
    await _connection?.invoke('JoinJobGroup', args: [jobId]);
  }

  /// Raw group leave; see [unwatchJob].
  Future<void> leaveJobGroup(String jobId) async {
    await _connection?.invoke('LeaveJobGroup', args: [jobId]);
  }

  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _connection?.stop();
    _connection = null;
  }

  void dispose() {
    _statusController.close();
    _matchController.close();
    _offerController.close();
    _adjustmentController.close();
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
  withdrawn,
  superseded,
  closed,
  unknown;

  static OfferEventType parse(String? raw) => switch (raw?.toLowerCase()) {
    'offercreated' => OfferEventType.created,
    'offerexpired' => OfferEventType.expired,
    'offeraccepted' => OfferEventType.accepted,
    'offerdeclined' => OfferEventType.declined,
    'offerwithdrawn' => OfferEventType.withdrawn,
    'offersuperseded' => OfferEventType.superseded,
    'offerclosed' => OfferEventType.closed,
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

/// v1.7: a price adjustment was proposed or decided on a job (P12-18).
/// Deliberately minimal — listeners refetch GET /api/jobs/:id/adjustments
/// rather than trusting an event payload.
class JobAdjustmentEvent {
  final String jobId;

  const JobAdjustmentEvent({required this.jobId});
}
