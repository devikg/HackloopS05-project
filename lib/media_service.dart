import 'dart:io';

import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;

import 'database.dart';

class MediaSvc {
  static bool isVideo(String? p) =>
      p != null &&
      RegExp(
        r'\.(mp4|mov|3gp|webm|mkv)(\?|$)',
        caseSensitive: false,
      ).hasMatch(p);

  static bool hasMedia(Report r) =>
      r.mediaUrl != null ||
      (r.mediaPath != null && File(r.mediaPath!).existsSync());

  /// Returns a local file for the report's media (downloads it first if it only exists online).
  static Future<File?> localFile(Report r) async {
    if (r.mediaPath != null && File(r.mediaPath!).existsSync()) {
      return File(r.mediaPath!);
    }
    if (r.mediaUrl == null) return null;
    final ext =
        RegExp(r'\.\w{2,4}(?=\?|$)').firstMatch(r.mediaUrl!)?.group(0) ??
        '.jpg';
    final f = File('${Directory.systemTemp.path}/safe_${r.id}$ext');
    if (!f.existsSync()) {
      await f.writeAsBytes(await http.readBytes(Uri.parse(r.mediaUrl!)));
    }
    return f;
  }

  /// Saves the photo/video to the phone gallery (album "SAFE Reports").
  static Future<String> download(Report r) async {
    try {
      final f = await localFile(r);
      if (f == null) return 'No photo/video attached to this report';
      if (!await Gal.hasAccess()) await Gal.requestAccess();
      isVideo(f.path)
          ? await Gal.putVideo(f.path, album: 'SAFE Reports')
          : await Gal.putImage(f.path, album: 'SAFE Reports');
      return 'Saved to gallery (SAFE Reports)';
    } catch (e) {
      return 'Download failed: $e';
    }
  }
}
