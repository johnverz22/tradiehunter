// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_helper.dart';

/// Client for the screen-recording orchestrator (`scripts/e2e-demo.py`).
///
/// The orchestrator hosts a tiny HTTP control server; each actor (homeowner
/// simulator, tradie simulator, admin browser) posts named signals and waits on
/// the signals it depends on, so the three points of view play out one after
/// the other in a fixed, watchable order.
class Demo {
  Demo._();

  static const _ctl =
      String.fromEnvironment('DEMO_CTL', defaultValue: 'http://127.0.0.1:5099');

  /// Seconds each screen is held so a viewer can read it.
  static const pace = int.fromEnvironment('DEMO_PACE', defaultValue: 3);

  static Future<Map<String, dynamic>> _call(String method, String path,
      [Object? body]) async {
    // Retried with hard timeouts — a stalled control request must never hold
    // the tour hostage; losing a signal would deadlock the choreography.
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      final client = HttpClient();
      try {
        final req = await client
            .openUrl(method, Uri.parse('$_ctl$path'))
            .timeout(const Duration(seconds: 10));
        req.headers.contentType = ContentType.json;
        if (body != null) {
          final bytes = utf8.encode(jsonEncode(body));
          req.headers.contentLength = bytes.length;
          req.add(bytes);
        }
        final resp = await req.close().timeout(const Duration(seconds: 10));
        final raw = await resp
            .transform(utf8.decoder)
            .join()
            .timeout(const Duration(seconds: 10));
        return raw.isEmpty ? {} : jsonDecode(raw) as Map<String, dynamic>;
      } catch (e) {
        lastError = e;
        await Future<void>.delayed(const Duration(milliseconds: 400));
      } finally {
        client.close(force: true);
      }
    }
    throw Exception('control call $method $path failed: $lastError');
  }

  /// Announces the scene that is about to play (shown in the orchestrator's
  /// terminal, written to the timeline, optionally spoken).
  static Future<void> step(String actor, String title) {
    print('__DEMO_STEP__ $actor | $title');
    return _call('POST', '/step', {'actor': actor, 'title': title});
  }

  /// Records a place where the demo used the API instead of the UI.
  static Future<void> note(String actor, String message) {
    print('__DEMO_NOTE__ $actor | $message');
    return _call('POST', '/note', {'actor': actor, 'message': message});
  }

  static Future<void> signal(String name) => _call('POST', '/signal/$name');

  static Future<void> setData(String key, String value) =>
      _call('POST', '/data/$key', {'value': value});

  /// Pumps the UI (so animations and SignalR keep running) until [name] is
  /// signalled by another actor.
  static Future<void> waitSignal(WidgetTester tester, String name,
      {Duration timeout = const Duration(minutes: 15)}) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final state = await _call('GET', '/state');
      if ((state['signals'] as Map?)?.containsKey(name) ?? false) return;
      await tester.pump(const Duration(milliseconds: 500));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    fail('timed out waiting for demo signal "$name"');
  }

  static Future<String> waitData(WidgetTester tester, String key,
      {Duration timeout = const Duration(minutes: 15)}) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final state = await _call('GET', '/state');
      final v = (state['data'] as Map?)?[key];
      if (v != null) return v as String;
      await tester.pump(const Duration(milliseconds: 500));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    fail('timed out waiting for demo data "$key"');
  }

  /// Holds the current screen for [multiplier] x [pace] seconds.
  static Future<void> beat(WidgetTester tester, [double multiplier = 1]) =>
      pumpFor(tester, Duration(milliseconds: (pace * 1000 * multiplier).round()));

  static Future<bool> tapKey(WidgetTester tester, String key) =>
      _tap(tester, find.byKey(Key(key)));

  static Future<bool> tapText(WidgetTester tester, String text) =>
      _tap(tester, find.text(text));

  static Future<bool> _tap(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) return false;
    await tester.ensureVisible(finder.first);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(finder.first);
    await beat(tester);
    return true;
  }

  /// Types into [finder] one chunk at a time so it reads as typing on camera.
  static Future<void> type(
      WidgetTester tester, Finder finder, String text) async {
    await tester.ensureVisible(finder.first);
    await tester.tap(finder.first);
    await tester.pump(const Duration(milliseconds: 300));
    final step = (text.length / 6).ceil().clamp(1, text.length);
    for (var i = step; i < text.length + step; i += step) {
      await tester.enterText(
          finder.first, text.substring(0, i > text.length ? text.length : i));
      await tester.pump(const Duration(milliseconds: 250));
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    await beat(tester, 0.5);
  }

  /// Polls [condition] while keeping the UI live.
  static Future<bool> until(
      WidgetTester tester, Future<bool> Function() condition,
      {Duration timeout = const Duration(seconds: 60)}) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await condition()) return true;
      await tester.pump(const Duration(milliseconds: 500));
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    return false;
  }
}
