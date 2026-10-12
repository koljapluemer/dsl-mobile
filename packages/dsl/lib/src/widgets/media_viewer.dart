import 'dart:io';

import 'package:flutter/widgets.dart';

import 'image_viewer.dart';
import 'video_viewer.dart';

/// Opens the full-screen image or video viewer for [file], picking the right
/// one based on [isVideo].
Future<void> showMediaViewer(
  BuildContext context,
  File file, {
  required bool isVideo,
}) {
  return isVideo
      ? showVideoViewer(context, file.path)
      : showImageViewer(context, FileImage(file));
}
