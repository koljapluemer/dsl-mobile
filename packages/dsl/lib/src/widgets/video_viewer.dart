import 'package:flutter/material.dart';

import 'minimal_video_player.dart';

/// Pushes a full-screen view of the video at [path] over a black backdrop.
/// Tap the close button or use the system back gesture to dismiss; tap the
/// video itself to play/pause (see [MinimalVideoPlayer]).
Future<void> showVideoViewer(BuildContext context, String path) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (context, _, _) => _VideoViewer(path: path),
    ),
  );
}

class _VideoViewer extends StatelessWidget {
  const _VideoViewer({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: Center(child: MinimalVideoPlayer(path: path)),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}
