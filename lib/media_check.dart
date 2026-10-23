import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:video_thumbnail/video_thumbnail.dart';

import 'database.dart';
import 'media_service.dart';

class MediaCheck {
  /// One JPEG frame per report: a photo, or the first second of a video. Null if none is available.
  /// Remote videos are skipped, because they would need downloading first.
  static Future<Uint8List?> frame(Report r) async {
    try {
      Uint8List? raw;
      final path = r.mediaPath;
      if (path != null && File(path).existsSync()) {
        raw = MediaSvc.isVideo(path)
            ? await VideoThumbnail.thumbnailData(
                video: path,
                timeMs: 1000,
                imageFormat: ImageFormat.JPEG,
                maxWidth: 768,
                quality: 70,
              )
            : await File(path).readAsBytes();
      } else if (r.mediaUrl != null && !MediaSvc.isVideo(r.mediaUrl)) {
        raw =
            (await http
                    .get(Uri.parse(r.mediaUrl!))
                    .timeout(const Duration(seconds: 15)))
                .bodyBytes;
      }
      if (raw == null || raw.isEmpty) return null;
      final im = img.decodeImage(raw);
      if (im == null) return null;
      final small = im.width > 768 ? img.copyResize(im, width: 768) : im;
      return Uint8List.fromList(img.encodeJpg(small, quality: 70));
    } catch (_) {
      return null;
    }
  }

  /// Average hash: a fingerprint that stays similar when an image is resized or re-compressed.
  /// Returns '' for flat, plain-colour images, which can't be compared meaningfully.
  static String aHash(Uint8List jpg) {
    final im = img.decodeImage(jpg);
    if (im == null) return '';
    final g = img.grayscale(img.copyResize(im, width: 8, height: 8));
    final px = <double>[];
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        px.add(img.getLuminance(g.getPixel(x, y)).toDouble());
      }
    }
    final mn = px.reduce((a, b) => a < b ? a : b);
    final mx = px.reduce((a, b) => a > b ? a : b);
    if (mx - mn < 10) return '';
    final avg = px.reduce((a, b) => a + b) / px.length;
    return px.map((p) => p >= avg ? '1' : '0').join();
  }

  static int distance(String a, String b) {
    var d = 0;
    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i] != b[i]) d++;
    }
    return d;
  }

  /// Local check, no API call. frames: report index -> JPEG bytes.
  static List<Map<String, String>> similarityFlags(Map<int, Uint8List> frames) {
    final hashes = <int, String>{};
    frames.forEach((i, bytes) {
      final h = aHash(bytes);
      if (h.isNotEmpty) hashes[i] = h;
    });
    final keys = hashes.keys.toList();
    final out = <Map<String, String>>[];
    for (var a = 0; a < keys.length; a++) {
      for (var b = a + 1; b < keys.length; b++) {
        final i = keys[a], j = keys[b];
        final d = distance(hashes[i]!, hashes[j]!);
        if (d <= 5) {
          out.add({
            'type': 'similar_media',
            'detail':
                'Report ${i + 1} and Report ${j + 1} contain near-identical images '
                '(difference $d of 64). Possibly the same photo or video reused.',
          });
        }
      }
    }
    return out;
  }
}
