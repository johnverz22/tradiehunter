import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../viewmodels/jobs_viewmodel.dart';
import '../design/th_tokens.dart';
import '../design/th_widgets.dart';
import '../feedback/th_notice.dart';
import 'ho_post_job_mapper.dart';

class HoPostJobPhotos extends ConsumerStatefulWidget {
  const HoPostJobPhotos({super.key});

  @override
  ConsumerState<HoPostJobPhotos> createState() => _HoPostJobPhotosState();
}

class _HoPostJobPhotosState extends ConsumerState<HoPostJobPhotos> {
  void _pickPhoto() {
    unawaited(_pickPhotoFlow());
  }

  Future<void> _pickPhotoFlow() async {
    if (ref.read(postJobProvider).photoPaths.length >= thMaxPhotos) return;
    final source = await _showSourceSheet();
    if (!mounted || source == null) return;
    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
    );
    if (!mounted || file == null) return;
    final size = await File(file.path).length();
    if (!mounted) return;
    if (thPhotoTooLarge(size)) {
      THNotice.warning(
        context,
        'Photo exceeds 10 MB. Please choose a smaller image.',
      );
      return;
    }
    ref.read(postJobProvider.notifier).addPhoto(file.path);
  }

  Future<ImageSource?> _showSourceSheet() {
    final theme = Theme.of(context);
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Theme(
        data: theme,
        child: Builder(
          builder: (ctx) {
            final c = ctx.th;
            return Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(Radii.sheet),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(Sizes.gutter),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SourceRow(
                        icon: Icons.camera_alt_outlined,
                        label: 'Take a photo',
                        onTap: () => Navigator.pop(ctx, ImageSource.camera),
                      ),
                      const SizedBox(height: Space.s2),
                      _SourceRow(
                        icon: Icons.photo_library_outlined,
                        label: 'Choose from gallery',
                        onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(postJobProvider);
    final paths = state.photoPaths;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        THText(
          'PHOTOS · OPTIONAL',
          style: THTextStyle.label,
          tone: THTone.soft,
        ),
        const SizedBox(height: Space.s2),
        THText(
          '${paths.length}/$thMaxPhotos photos added',
          style: THTextStyle.meta,
          tone: paths.length >= thMaxPhotos ? THTone.accent : THTone.soft,
        ),
        const SizedBox(height: Space.s2),
        if (paths.isEmpty)
          Semantics(
            button: true,
            label: 'Add photos',
            child: InkWell(
              onTap: _pickPhoto,
              borderRadius: BorderRadius.circular(Radii.tile),
              child: const THDashBox(
                icon: Icons.photo_camera_rounded,
                title: 'Add photos',
                subtitle: 'Up to $thMaxPhotos, 10 MB each',
              ),
            ),
          )
        else
          Wrap(
            spacing: Space.s2,
            runSpacing: Space.s2,
            children: [
              for (var i = 0; i < paths.length; i++)
                _PhotoThumbnail(
                  path: paths[i],
                  label: 'Photo ${i + 1} of ${paths.length}, remove',
                  onRemove: () =>
                      ref.read(postJobProvider.notifier).removePhoto(paths[i]),
                ),
              if (paths.length < thMaxPhotos)
                Semantics(
                  button: true,
                  label: 'Add another photo',
                  child: InkWell(
                    onTap: _pickPhoto,
                    borderRadius: BorderRadius.circular(Radii.control),
                    child: Container(
                      width: Sizes.avatarLg,
                      height: Sizes.avatarLg,
                      decoration: BoxDecoration(
                        color: context.th.tintBrand,
                        borderRadius: BorderRadius.circular(Radii.control),
                        border: Border.all(color: context.th.line),
                      ),
                      child: Icon(
                        Icons.add_a_photo_outlined,
                        size: Sizes.iconLg,
                        color: context.th.textBrand,
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.card),
        child: THListRow(icon: icon, title: label),
      ),
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  const _PhotoThumbnail({
    required this.path,
    required this.label,
    required this.onRemove,
  });

  final String path;
  final String label;
  final VoidCallback onRemove;

  bool get _isAsset => path.startsWith('assets/');

  @override
  Widget build(BuildContext context) {
    final c = context.th;
    final fallback = Container(
      width: Sizes.avatarLg,
      height: Sizes.avatarLg,
      color: c.surfaceAlt,
      child: Icon(Icons.image_outlined, color: c.textSoft),
    );
    final image = _isAsset
        ? Image.asset(
            path,
            width: Sizes.avatarLg,
            height: Sizes.avatarLg,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          )
        : Image.file(
            File(path),
            width: Sizes.avatarLg,
            height: Sizes.avatarLg,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          );
    return SizedBox(
      width: Sizes.avatarLg,
      height: Sizes.avatarLg,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.control),
            child: image,
          ),
          Positioned(
            top: 0,
            right: 0,
            child: THIconButton(
              icon: Icons.close,
              kind: THButtonKind.primary,
              semanticLabel: label,
              onPressed: onRemove,
            ),
          ),
        ],
      ),
    );
  }
}
