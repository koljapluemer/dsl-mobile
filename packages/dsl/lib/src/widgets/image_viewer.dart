import 'package:flutter/material.dart';

/// Pushes a full-screen, pinch-to-zoom view of [image] over a black backdrop.
/// Tap anywhere, hit the close button, or use the system back gesture to
/// dismiss.
Future<void> showImageViewer(BuildContext context, ImageProvider image) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (context, _, _) => _ImageViewer(image: image),
    ),
  );
}

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.image});

  final ImageProvider image;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 8,
                child: Center(child: Image(image: image)),
              ),
            ),
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
