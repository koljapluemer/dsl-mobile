import 'dart:convert';
import 'package:flutter/painting.dart';

/// 32-bit FNV-1a. Unlike [String.hashCode] it is stable across runs and
/// platforms, so a note keeps its color.
int _fnv1a(String input, {int offsetBasis = 0x811c9dc5}) {
  var hash = offsetBasis;
  for (final byte in utf8.encode(input)) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash;
}

/// Hue in degrees [0, 360) derived from [fileName].
double hueFor(String fileName) =>
    (_fnv1a(fileName, offsetBasis: 0x9747b28c) % 360).toDouble();

Color cardColorFor(String fileName) =>
    HSVColor.fromAHSV(1, hueFor(fileName), 0.3, 0.95).toColor();
