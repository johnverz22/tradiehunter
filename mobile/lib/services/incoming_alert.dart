import 'dart:async';

import 'package:flutter/services.dart';

/// In-app audible + haptic cue while the incoming-request screen is open
/// (QA plan §3). Plays the platform alert sound on a loop and a haptic pulse
/// with each ring; [stop] is called on every action, dismiss and expiry.
///
/// This uses the system alert sound, so it follows the device's silent mode
/// and volume. The custom ring for a backgrounded or locked phone comes from
/// the `incoming_requests` notification channel, not from here.
class IncomingAlert {
  IncomingAlert({this.interval = const Duration(seconds: 2)});

  final Duration interval;
  Timer? _timer;

  bool get isRinging => _timer != null;

  void start() {
    if (_timer != null) return;
    _ring();
    _timer = Timer.periodic(interval, (_) => _ring());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _ring() {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
  }
}
