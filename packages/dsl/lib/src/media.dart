import 'package:path/path.dart' as p;

/// Largest image file the editor accepts. Far bigger than any real photo; the cap
/// only exists so a pathologically huge file can't blow up memory on decode.
const int maxImageBytes = 25 * 1024 * 1024;

/// Largest video file the editor accepts. Videos are meant to be short clips, not
/// general video hosting.
const int maxVideoBytes = 100 * 1024 * 1024;

/// Image extensions Flutter can decode and display directly. Images are stored
/// verbatim — no format conversion — so anything outside this set is rejected
/// at pick time rather than saved and later failing to render.
const Set<String> supportedImageExtensions = {
  '.jpg',
  '.jpeg',
  '.png',
  '.gif',
  '.webp',
  '.bmp',
};

/// Video extensions that are attached and played back.
const Set<String> supportedVideoExtensions = {'.mp4', '.webm', '.mov'};

/// Every extension an item's attachment may have — image or video.
const Set<String> supportedMediaExtensions = {
  ...supportedImageExtensions,
  ...supportedVideoExtensions,
};

bool isVideoFilename(String path) =>
    supportedVideoExtensions.contains(p.extension(path).toLowerCase());

bool isImageFilename(String path) =>
    supportedImageExtensions.contains(p.extension(path).toLowerCase());

bool isMediaFilename(String path) =>
    supportedMediaExtensions.contains(p.extension(path).toLowerCase());
