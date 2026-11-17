/// Route destination for an FCM notification type.
///
/// Keep in sync with the API's `chat`, `job_status`, and `match` data values.
String routeForMessageType(String? type) => switch (type) {
  'chat' || 'job_status' => '/messages',
  'match' => '/jobs',
  _ => '/messages',
};
