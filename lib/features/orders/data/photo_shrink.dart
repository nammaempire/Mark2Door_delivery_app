import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Size a delivery photo is brought down to when it is larger.
const proofTargetBytes = 250 * 1024;

/// A delivery photo is never stored larger than this.
const proofMaxBytes = 500 * 1024;

/// Makes a camera photo small enough to store: about 200 KB, and never
/// above 500 KB. A photo that is already small is returned untouched;
/// otherwise it is resized and saved at lower quality, a step at a time,
/// until it fits. A 5 MB photo comes out at roughly 150 to 250 KB and is
/// still clear enough to see the order at the door.
///
/// Top-level and free of Flutter so it can run off the main thread.
Uint8List shrinkJpeg(Uint8List bytes) {
  if (bytes.length <= proofTargetBytes) return bytes;
  final raw = img.decodeImage(bytes);
  if (raw == null) return bytes; // not an image we can read: keep it as is
  // Turn the picture upright first; the rotation note is lost on saving.
  final photo = img.bakeOrientation(raw);

  var best = bytes;
  // Longest side in pixels, then JPEG quality.
  const steps = [
    (1280, 60),
    (1280, 45),
    (1024, 45),
    (1024, 35),
    (800, 35),
    (640, 30),
  ];
  for (final (side, quality) in steps) {
    final wide = photo.width >= photo.height;
    final longest = wide ? photo.width : photo.height;
    final sized = longest <= side
        ? photo
        : img.copyResize(
            photo,
            width: wide ? side : null,
            height: wide ? null : side,
            interpolation: img.Interpolation.average,
          );
    final out = img.encodeJpg(sized, quality: quality);
    if (out.length < best.length) best = out;
    if (out.length <= proofTargetBytes) break;
  }
  return best;
}
