// Photo strip + full-screen swipe viewer for the v2 tradie request detail
// (`tr_lead`, plan 5.0 #3 / 5.2). Port of the v1 gallery: same `photo_thumb_$i`
// Keys, page indicator, close button and URL resolution.
import 'package:flutter/material.dart';

import '../design/th_test_id.dart';
import '../design/th_tokens.dart';
import 'tr_lead_mapper.dart';

/// Horizontal strip of tappable photo thumbnails.
class TrPhotoStrip extends StatelessWidget {
  const TrPhotoStrip({
    super.key,
    required this.photoUrls,
    required this.baseUrl,
    required this.onOpen,
  });

  final List<String> photoUrls;
  final String baseUrl;
  final void Function(int index) onOpen;

  static const double _thumb = 96;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: _thumb,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: photoUrls.length,
      separatorBuilder: (_, _) => const SizedBox(width: Space.s2_5),
      itemBuilder: (context, i) => _Thumb(
        index: i,
        total: photoUrls.length,
        url: trResolvePhotoUrl(photoUrls[i], baseUrl),
        onTap: () => onOpen(i),
      ),
    ),
  );
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.index,
    required this.total,
    required this.url,
    required this.onTap,
  });

  final int index;
  final int total;
  final String url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    final id = 'photo_thumb_$index';
    return Semantics(
      button: true,
      label: 'Photo ${index + 1} of $total, tap to view full screen',
      child: thTestIdWrap(
        GestureDetector(
          key: ValueKey<String>(id),
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.control),
            child: Image.network(
              url,
              width: TrPhotoStrip._thumb,
              height: TrPhotoStrip._thumb,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: TrPhotoStrip._thumb,
                height: TrPhotoStrip._thumb,
                color: c.tintBrand,
                alignment: Alignment.center,
                child: Icon(Icons.photo_outlined, color: c.textBrand),
              ),
            ),
          ),
        ),
        ValueKey<String>(id),
      ),
    );
  }
}

/// Pushes the full-screen viewer on the root navigator.
void showTrPhotoViewer(
  BuildContext context, {
  required List<String> photoUrls,
  required int initialIndex,
  required String baseUrl,
}) {
  if (photoUrls.isEmpty) return;
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => TrPhotoViewer(
        photoUrls: photoUrls,
        initialIndex: initialIndex,
        baseUrl: baseUrl,
      ),
    ),
  );
}

/// Swipeable, pinch-zoomable full-screen photos with a page indicator.
class TrPhotoViewer extends StatefulWidget {
  const TrPhotoViewer({
    super.key,
    required this.photoUrls,
    required this.initialIndex,
    required this.baseUrl,
  });

  final List<String> photoUrls;
  final int initialIndex;
  final String baseUrl;

  @override
  State<TrPhotoViewer> createState() => _TrPhotoViewerState();
}

class _TrPhotoViewerState extends State<TrPhotoViewer> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        tooltip: 'Close photo viewer',
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        'Photo ${_index + 1} of ${widget.photoUrls.length}',
        style: THType.title.copyWith(color: Colors.white),
      ),
    ),
    body: PageView.builder(
      controller: _controller,
      itemCount: widget.photoUrls.length,
      onPageChanged: (i) => setState(() => _index = i),
      itemBuilder: (context, i) => Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Image.network(
            trResolvePhotoUrl(widget.photoUrls[i], widget.baseUrl),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Padding(
              padding: const EdgeInsets.all(Space.s6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.broken_image_outlined,
                    size: 48,
                    color: Colors.white54,
                  ),
                  const SizedBox(height: Space.s3),
                  Text(
                    'Failed to load photo ${i + 1}',
                    style: THType.body.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
