import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Call once in `main` before showing a [MinimalVideoPlayer].
void initMediaPlayback() => MediaKit.ensureInitialized();

/// Minimal inline video playback for an item's attached clip: muted, no
/// autoplay, a single tap-anywhere play/pause control. No scrubber, volume,
/// or fullscreen UI — attachments are short clips, not
/// general video playback, so parity with a full player isn't the goal.
class MinimalVideoPlayer extends StatefulWidget {
  const MinimalVideoPlayer({super.key, required this.path});

  final String path;

  @override
  State<MinimalVideoPlayer> createState() => _MinimalVideoPlayerState();
}

class _MinimalVideoPlayerState extends State<MinimalVideoPlayer> {
  late final Player _player = Player();
  late final VideoController _controller = VideoController(_player);
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player.setVolume(0);
    _player.stream.playing.listen((playing) {
      if (mounted) setState(() => _playing = playing);
    });
    _player.open(Media(widget.path), play: false);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _toggle() => _playing ? _player.pause() : _player.play();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Video(controller: _controller, controls: NoVideoControls),
          if (!_playing)
            Container(
              decoration: const BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(12),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 36,
              ),
            ),
        ],
      ),
    );
  }
}
