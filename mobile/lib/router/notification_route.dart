/// Route destination for an FCM notification type.
///
/// Keep in sync with the API's `chat`, `job_status`, and `match` data values.
String routeForMessageType(String? type) => switch (type) {
  'chat' || 'job_status' => '/messages',
  'match' => '/jobs',
  _ => '/messages',
};

/// Route for a full FCM data payload. Types that need an id (a quote landing on
/// a specific job) are resolved here; everything else defers to
/// [routeForMessageType].
String routeForMessage(Map<String, dynamic> data) {
  final type = data['type'];
  final jobId = data['jobId']?.toString();
  if (type == 'quote_submitted' && jobId != null && jobId.isNotEmpty) {
    return '/jobs/$jobId/quotes';
  }
  return routeForMessageType(type is String ? type : null);
}
