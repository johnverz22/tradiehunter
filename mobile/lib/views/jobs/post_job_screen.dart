import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/design_tokens.dart';
import '../../viewmodels/jobs_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../widgets/fixo_buttons.dart';

/// Mockup 06-post-job: category chips, description, photo grid,
/// urgency cards, location field, sticky amber Post Job bar.
/// Wired to [PostJobNotifier] (M2-07). Photos are uploaded to
/// POST /api/jobs/:id/photos after job creation.
///
/// Role-guarded: tradies are redirected to /tradie — only homeowners
/// can post jobs.
class PostJobScreen extends ConsumerWidget {
  const PostJobScreen({super.key});

  static const _categories = [
    'Plumbing',
    'Electrical',
    'Builder',
    'Painter',
    'Landscaper',
    'General',
  ];

  static const _urgencies = ['Low', 'Medium', 'High', 'Emergency'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tradies cannot post jobs — redirect them to their dashboard.
    final isTradie =
        ref.read(profileViewModelProvider).profile?['role'] == 1;
    if (isTradie) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/tradie');
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final vm = ref.watch(postJobProvider);
    final notifier = ref.read(postJobProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Post a Job')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Category ───────────────────────────────────────────────────
            _Section(title: 'What do you need?'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((c) {
                final selected = c == vm.category;
                return ChoiceChip(
                  label: Text(c),
                  selected: selected,
                  selectedColor: DesignTokens.brand500,
                  labelStyle: TextStyle(
                      color: selected
                          ? Colors.white
                          : theme.colorScheme.onSurface),
                  onSelected: (_) => notifier.setCategory(c),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ── Description ────────────────────────────────────────────────
            _Section(title: 'Describe the job'),
            TextField(
              maxLines: 5,
              decoration: const InputDecoration(
                  hintText: 'e.g. Leaking kitchen tap, drips constantly…'),
              onChanged: notifier.setDescription,
            ),
            if (vm.error != null && vm.error!.contains('description'))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(vm.error!,
                    style:
                        TextStyle(color: theme.colorScheme.error, fontSize: 12)),
              ),
            const SizedBox(height: 24),

            // ── Photos ─────────────────────────────────────────────────────
            _Section(title: 'Photos (up to 5)'),
            _PhotoGrid(
              paths: vm.photoPaths,
              onAdd: () => _pickPhoto(context, ref),
              onRemove: (path) => notifier.removePhoto(path),
            ),
            const SizedBox(height: 24),

            // ── Urgency ────────────────────────────────────────────────────
            _Section(title: 'Urgency'),
            Row(
              children: _urgencies.map((u) {
                final selected = u == vm.urgency;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => notifier.setUrgency(u),
                    child: Container(
                      margin: EdgeInsets.only(
                          right: u != _urgencies.last ? 6 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: selected
                            ? DesignTokens.amber.withValues(alpha: 0.12)
                            : Colors.transparent,
                        border: Border.all(
                            color: selected
                                ? DesignTokens.amber
                                : theme.dividerColor,
                            width: selected ? 2 : 1),
                        borderRadius:
                            BorderRadius.circular(DesignTokens.radius),
                      ),
                      child: Text(u,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.normal)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ── Location ────────────────────────────────────────────────────
            _Section(title: 'Location'),
            TextField(
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.location_on_outlined),
                  hintText: 'e.g. Grey Lynn, Auckland'),
              onChanged: notifier.setAddress,
            ),

            // ── Error banner ────────────────────────────────────────────────
            if (vm.error != null && !vm.error!.contains('description'))
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(vm.error!,
                    style: TextStyle(color: theme.colorScheme.error)),
              ),
          ],
        ),
      ),
      bottomSheet: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            border: Border(top: BorderSide(color: theme.dividerColor)),
          ),
          child: FixoPrimaryButton(
            label: 'Post Job',
            isLoading: vm.isSubmitting,
            onPressed: vm.isSubmitting ? null : () => _submit(context, ref),
          ),
        ),
      ),
    );
  }

  Future<void> _pickPhoto(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(postJobProvider.notifier);
    final state = ref.read(postJobProvider);
    if (state.photoPaths.length >= 5) return;

    final picker = ImagePicker();
    final source = await _showSourceDialog(context);
    if (source == null) return;

    final file = await picker.pickImage(source: source, imageQuality: 85);
    if (file != null) notifier.addPhoto(file.path);
  }

  Future<ImageSource?> _showSourceDialog(BuildContext context) async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final jobId = await ref.read(postJobProvider.notifier).submit();
    if (jobId != null && context.mounted) {
      context.push('/jobs/$jobId/matching');
    }
  }
}

// ── Photo grid widget ─────────────────────────────────────────────────────────

class _PhotoGrid extends StatelessWidget {
  final List<String> paths;
  final VoidCallback onAdd;
  final void Function(String path) onRemove;

  const _PhotoGrid(
      {required this.paths, required this.onAdd, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final path in paths)
          _PhotoThumbnail(path: path, onRemove: () => onRemove(path)),
        if (paths.length < 5)
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                border: Border.all(
                    style: BorderStyle.solid, color: theme.dividerColor),
                borderRadius: BorderRadius.circular(DesignTokens.radius),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined,
                      size: 24, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 4),
                  Text('Add',
                      style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  final String path;
  final VoidCallback onRemove;
  const _PhotoThumbnail({required this.path, required this.onRemove});

  bool get _isAsset => path.startsWith('assets/');

  @override
  Widget build(BuildContext context) {
    final image = _isAsset
        ? Image.asset(
            path,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (_, _a, _b) => Container(
              width: 80,
              height: 80,
              color: DesignTokens.brand100Light,
              child: const Icon(Icons.image_outlined),
            ),
          )
        : Image.file(
            File(path),
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (_, _a, _b) => Container(
              width: 80,
              height: 80,
              color: DesignTokens.brand100Light,
              child: const Icon(Icons.image_outlined),
            ),
          );
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(DesignTokens.radius),
          child: image,
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(
                  color: Colors.black54, shape: BoxShape.circle),
              padding: const EdgeInsets.all(2),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  const _Section({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600)),
    );
  }
}
