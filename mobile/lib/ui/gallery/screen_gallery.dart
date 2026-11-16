import 'package:flutter/material.dart';

import '../design/th_scope.dart';
import '../design/th_tokens.dart';
import 'screens.dart';

/// Debug-only index of the 30 generated v2 design screens (static sample data).
///
/// Visual baseline for Phase 2.7 goldens and for QA against
/// `docs/design/mockups/index.html`. These are NOT the real screens.
/// Route: `/debug/screen-gallery[?screen=<id>&theme=light|dark]`.
class ScreenGalleryPage extends StatefulWidget {
  const ScreenGalleryPage({super.key, this.initialScreen, this.initialDark = false});

  final String? initialScreen;
  final bool initialDark;

  @override
  State<ScreenGalleryPage> createState() => _ScreenGalleryPageState();
}

class _ScreenGalleryPageState extends State<ScreenGalleryPage> {
  late bool _dark = widget.initialDark;

  ThemeMode get _mode => _dark ? ThemeMode.dark : ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    final id = widget.initialScreen;
    final builder = id == null ? null : thScreenBuilders[id];
    if (builder != null) {
      return ThScope(themeMode: _mode, child: Builder(builder: builder));
    }
    return ThScope(
      themeMode: _mode,
      child: Builder(
        builder: (context) {
          final c = context.th;
          final ids = thScreenBuilders.keys.toList();
          return Scaffold(
            backgroundColor: c.paper,
            appBar: AppBar(
              backgroundColor: c.paper,
              foregroundColor: c.text,
              title: Text('v2 screen gallery (${ids.length})', style: THType.title),
              actions: [
                Switch(
                  key: const Key('gallery-dark-toggle'),
                  value: _dark,
                  onChanged: (v) => setState(() => _dark = v),
                ),
                const SizedBox(width: Space.s2),
              ],
            ),
            body: ListView.separated(
              padding: const EdgeInsets.all(Space.s4),
              itemCount: ids.length,
              separatorBuilder: (_, _) => Divider(height: 1, color: c.line),
              itemBuilder: (context, i) {
                final key = ids[i];
                return ListTile(
                  key: Key('gallery-$key'),
                  title: Text(key, style: THType.body.copyWith(color: c.text)),
                  subtitle: Text(thScreenRoutes[key] ?? '', style: THType.meta.copyWith(color: c.textSoft)),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ThScope(
                        themeMode: _mode,
                        child: Builder(builder: thScreenBuilders[key]!),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
