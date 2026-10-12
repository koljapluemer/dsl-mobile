import 'dart:io';

import 'package:flutter/material.dart';

import '../media.dart';
import 'image_viewer.dart';
import 'minimal_video_player.dart';

/// An item's attachment inline, at most a third of the screen high: a video
/// plays in place, an image opens full-screen on tap.
class MediaPreview extends StatelessWidget {
  const MediaPreview({super.key, required this.path});

  /// Absolute path of the image or video.
  final String path;

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height / 3,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: isVideoFilename(path)
            ? MinimalVideoPlayer(key: ValueKey(path), path: path)
            : GestureDetector(
                onTap: () => showImageViewer(context, FileImage(file)),
                child: Image.file(
                  file,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                  errorBuilder: (context, _, _) => Text(
                    'Can\'t show $path',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
