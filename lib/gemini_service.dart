import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'database.dart';
import 'media_check.dart';

class Gemini {
  /// Tried in order. The first model this key can access is used.
  static const _models = [
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'gemini-3.5-flash',
  ];

  /// Shown on screen so testers can report whether Gemini answered.
  static String lastStatus = 'Gemini: not called yet';

  static String _time() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }

  static String _reason(int code) => switch (code) {
    400 => 'bad request',
    401 || 403 => 'key invalid or not allowed',
    404 => 'model not available for this key',
    429 => 'daily or rate limit reached',
    500 || 503 => 'Google server busy',
    _ => 'unknown error',
  };

  /// Turns the internal media verdict into the text shown on the card.
  static String mediaLabel(String v) => switch (v) {
    'likely_fake' => 'likely fake: photo of a screen or print',
    'claim_not_visible' => 'claimed issue not visible in photo',
    'claim_visible' =>
      'claimed issue visible in photo (this is not proof the photo is genuine)',
    'reused_media' => 'same photo reused across reports',
    'cannot_determine' => 'cannot determine from photo',
    'no_media' => 'no photo to check',
    _ => v.replaceAll('_', ' '),
  };

  static Set<String> _words(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.length > 2)
      .toSet();

  /// Local check, no API call. Finds pairs of reports with near-identical wording.
  static List<Map<String, String>> duplicateFlags(List<Report> rs) {
    var pairs = 0;
    final sets = rs.map((r) => _words(r.description)).toList();
    for (var i = 0; i < sets.length; i++) {
      for (var j = i + 1; j < sets.length; j++) {
        if (sets[i].isEmpty || sets[j].isEmpty) continue;
        final inter = sets[i].intersection(sets[j]).length;
        final union = sets[i].union(sets[j]).length;
        if (union > 0 && inter / union >= 0.8) pairs++;
      }
    }
    if (pairs == 0) return [];
    return [
      {
        'type': 'identical_wording',
        'detail':
            '$pairs pair(s) of reports use near-identical wording. Possibly copied or coordinated.',
      },
    ];
  }

  /// Plain written summary for the More screen (no photo checks).
  static Future<String> summarize(List<Report> rs, {bool local = false}) async {
    if (rs.isEmpty) {
      lastStatus = 'Gemini: no reports, not called';
      return 'No reports yet.';
    }
    final data = rs
        .take(30)
        .map(
          (r) =>
              '${r.createdAt.toIso8601String()} | ${r.category} | ${r.area} | ${r.description}',
        )
        .join('\n');
    final prompt =
        '''You are ${local ? 'a civic-issues analyst' : 'a public-safety analyst'}. From these community reports (${rs.length} total) write:
1) Current status, 2) Timeline of how it developed, 3) Likely outlook for the next hours,
4) Advice (${local ? 'civic/traffic' : 'safety'}). Max 70 words, plain language.
Reports:\n$data''';
    final text = await _call([
      {'text': prompt},
    ], rs.length);
    return text ?? _fallback(rs);
  }

  /// Checks each photo against the claim in its report.
  /// Works for emergency reports (local: false) and local community issues (local: true).
  /// Gives opinions only. It cannot confirm that an issue is real or fake.
  static Future<Map<String, dynamic>?> analyse(
    List<Report> rs, {
    bool local = false,
  }) async {
    if (rs.isEmpty) {
      lastStatus = 'Gemini: no reports, not called';
      return null;
    }

    final role = local
        ? 'a verification assistant for a community issue-reporting app'
        : 'a verification assistant for a public-safety app';
    final examples = local
        ? 'for example pothole, broken streetlight, flooded road, overflowing drain, garbage dump, damaged footpath'
        : 'for example fire, flames, smoke, flooding, a collapsed structure';
    final adviceRule = local
        ? 'say the relevant authority or local residents should verify on the ground before acting'
        : 'say responders must verify on the ground before acting';

    // 1. One image per report, for up to 6 reports (JPEG, max 768px)
    final frames = <int, Uint8List>{};
    for (var i = 0; i < rs.length && frames.length < 6; i++) {
      final f = await MediaCheck.frame(rs[i]);
      if (f != null) frames[i] = f;
    }

    // 2. Local checks, no API call: reused images and copied text
    final similarFlags = MediaCheck.similarityFlags(frames);
    final localFlags = [...similarFlags, ...duplicateFlags(rs)];

    // 3. Text description of each report, with the claim it makes
    final data = rs
        .take(30)
        .toList()
        .asMap()
        .entries
        .map((e) {
          final r = e.value;
          return 'Report ${e.key + 1}: ${r.createdAt.toIso8601String()} | claimed: ${r.category} | ${r.area} '
              '| call:${r.callStatus ?? 'none'} | photo:${frames.containsKey(e.key) ? 'attached' : 'none'} '
              '| description: ${r.description}';
        })
        .join('\n');

    // 4. Photos, sent after the text (up to 3)
    final parts = <Map<String, dynamic>>[];
    for (final e in frames.entries.take(3)) {
      parts.add({'text': 'Photo for Report ${e.key + 1}:'});
      parts.add({
        'inline_data': {
          'mime_type': 'image/jpeg',
          'data': base64Encode(e.value),
        },
      });
    }

    final localNote = localFlags.isEmpty
        ? 'nothing'
        : localFlags.map((f) => f['detail']).join(' ');

    final prompt =
        '''You are $role.
You can see the written reports and up to 3 photos. Each report claims a type of ${local ? 'community issue' : 'incident'}.
You can NOT confirm that any ${local ? 'issue' : 'incident'} is real or fake. Describe only what the photos show.

For EACH photo that is attached, answer:
- hazard_visible: "yes", "no" or "unclear". Is the claimed ${local ? 'issue' : 'hazard'} (claimed type: $examples) clearly visible in the photo? Only "yes" if it is clearly visible.
- is_screen_or_print: "yes", "no" or "unclear". Is this a photo of a computer monitor, laptop, phone, TV, tablet, or a printed picture, instead of a direct photo of a real scene? Look for bezels or device edges, a pixel grid or moire pattern, glare or reflections of the screen, keyboards, taskbars, window frames, or a visible rectangular screen border.
- evidence: a short phrase naming what you saw that supports your answer. Write "none" if nothing.

Then give ONE overall media_verdict:
- "likely_fake": at least one photo is a photo of a screen or print.
- "claim_not_visible": the photos are direct photos of a real scene, and the claimed ${local ? 'issue' : 'hazard'} is not visible in them.
- "claim_visible": the photos are direct photos of a real scene, and the claimed ${local ? 'issue' : 'hazard'} is clearly visible in them.
- "cannot_determine": the photos are unclear.
- "no_media": no photos are attached.

Local checks already found: $localNote

Reports:
$data

Return ONLY valid JSON, no markdown, in exactly this shape:
{"media_verdict": "cannot_determine", "image_findings": [{"report": 1, "hazard_visible": "no", "is_screen_or_print": "yes", "evidence": "..."}], "media_assessment": "...", "verdict": "consistent", "correlation": "...", "observed": ["..."], "inferred": ["..."], "flags": [{"type": "...", "detail": "..."}], "advice": "..."}

Rules:
- "verdict": consistent, possibly_coordinated, contradictory, or insufficient.
- "media_assessment": one or two sentences starting with "Opinion:". Say what the photos show and what they cannot show.
- "correlation": one sentence on time, location, and whether the reports describe the same ${local ? 'issue' : 'event'}.
- "observed": facts stated in the reports or clearly visible in the photos (max 4).
- "inferred": likely conclusions, each clearly marked as an inference (max 3).
- "flags": only these types: screen_photo, hazard_not_visible, media_manipulation_signs, ai_generation_signs, conflicting_details, timing_gap, location_mismatch, identical_wording, no_media, single_source. Empty list if none apply.
- "advice": one sentence. If the verdict is not consistent, or the media_verdict is not claim_visible, $adviceRule.
- Never say that an ${local ? 'issue' : 'incident'} is real or fake. Only describe the photos.''';

    parts.insert(0, {'text': prompt});

    final text = await _call(parts, rs.length);
    if (text == null) return null;

    try {
      final clean = text.replaceAll(RegExp(r'```json|```'), '').trim();
      final map = jsonDecode(clean) as Map<String, dynamic>;

      var verdict = (map['verdict'] ?? 'insufficient').toString();
      var mediaVerdict = (map['media_verdict'] ?? 'cannot_determine')
          .toString();

      // Safety nets: local checks override a too-friendly answer
      if (localFlags.isNotEmpty && verdict == 'consistent') {
        verdict = 'possibly_coordinated';
      }
      if (similarFlags.isNotEmpty) mediaVerdict = 'reused_media';

      final findings = ((map['image_findings'] as List?) ?? [])
          .whereType<Map>()
          .map((f) {
            final shows = f['hazard_visible']?.toString() ?? 'unclear';
            final screen = f['is_screen_or_print']?.toString() ?? 'unclear';
            final ev = f['evidence']?.toString() ?? '';
            return 'Report ${f['report']}: claimed issue visible: $shows; screen or print: $screen'
                '${ev.isNotEmpty && ev != 'none' ? ' ($ev)' : ''}';
          })
          .toList();

      final geminiFlags = ((map['flags'] as List?) ?? []).whereType<Map>().map(
        (f) => {
          'type': f['type']?.toString() ?? '',
          'detail': f['detail']?.toString() ?? '',
        },
      );

      return {
        'verdict': verdict,
        'media_verdict': mediaVerdict,
        'media_assessment': (map['media_assessment'] ?? '').toString(),
        'image_findings': findings,
        'correlation': (map['correlation'] ?? '').toString(),
        'observed': ((map['observed'] as List?) ?? [])
            .map((e) => e.toString())
            .toList(),
        'inferred': ((map['inferred'] as List?) ?? [])
            .map((e) => e.toString())
            .toList(),
        'flags': [...geminiFlags, ...localFlags],
        'advice': (map['advice'] ?? '').toString(),
      };
    } catch (_) {
      lastStatus =
          'Gemini FAILED at ${_time()}: answer was not in the expected format';
      return null;
    }
  }

  /// Tries each model in turn. Uses the first one this key can access.
  /// [parts] can hold text and photos.
  static Future<String?> _call(
    List<Map<String, dynamic>> parts,
    int count,
  ) async {
    final key = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (key.isEmpty) {
      lastStatus = 'Gemini FAILED: GEMINI_API_KEY missing in .env';
      return null;
    }
    final stamp = _time();
    for (final model in _models) {
      try {
        final res = await http
            .post(
              Uri.parse(
                'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
              ),
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': key,
              },
              body: jsonEncode({
                'contents': [
                  {'parts': parts},
                ],
              }),
            )
            .timeout(const Duration(seconds: 30));

        if (res.statusCode == 404) {
          continue; // this model isn't available for this key, try the next one
        }
        if (res.statusCode != 200) {
          lastStatus =
              'Gemini FAILED ${res.statusCode} at $stamp (${_reason(res.statusCode)})';
          return null;
        }

        final j = jsonDecode(res.body);
        final text = j['candidates']?[0]?['content']?['parts']?[0]?['text'];
        if (text == null || text.toString().trim().isEmpty) {
          lastStatus = 'Gemini FAILED at $stamp: empty answer';
          return null;
        }
        lastStatus = 'Gemini OK ($model) at $stamp ($count reports)';
        return text.toString().trim();
      } catch (_) {
        lastStatus = 'Gemini FAILED at $stamp: no internet or timeout';
        return null;
      }
    }
    lastStatus = 'Gemini FAILED 404 at $stamp: no model available for this key';
    return null;
  }

  static String _fallback(List<Report> rs) {
    final l = rs.first;
    return '${rs.length} report(s) about ${l.category} near ${l.area}. Latest: ${l.description}. (AI summary unavailable.)';
  }
}
