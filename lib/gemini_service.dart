import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'database.dart';

class Gemini {
  static const _model = 'gemini-2.5-flash';

  /// Shown on screen so testers can report whether Gemini answered.
  static String lastStatus = 'Gemini: not called yet';

  static String _time() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }

  static String _reason(int code) => switch (code) {
    400 => 'bad request',
    401 || 403 => 'key invalid or not allowed',
    429 => 'daily or rate limit reached',
    500 || 503 => 'Google server busy',
    _ => 'unknown error',
  };

  /// Plain summary used for the More screen (local issues).
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
        '''You are a public-safety analyst. From these crowd reports (${rs.length} total) write:
1) Current status, 2) Timeline of how it developed, 3) Likely outlook for the next hours,
4) Advice (${local ? 'civic/traffic' : 'safety'}). Max 70 words, plain language.
Reports:\n$data''';
    final text = await _call(prompt, rs.length);
    return text ?? _fallback(rs);
  }

  /// Structured analysis for the incident card. Returns observed facts, inferences and advice.
  /// Returns null if Gemini fails, so the UI shows the basic card instead.
  static Future<Map<String, dynamic>?> analyse(List<Report> rs) async {
    if (rs.isEmpty) {
      lastStatus = 'Gemini: no reports, not called';
      return null;
    }
    final data = rs
        .take(30)
        .map(
          (r) =>
              '${r.createdAt.toIso8601String()} | ${r.category} | ${r.area} | ${r.description} | media:${r.mediaUrl != null || r.mediaPath != null ? 'yes' : 'no'}',
        )
        .join('\n');
    final prompt =
        '''You are a public-safety analyst. Below are ${rs.length} independent crowd reports about one incident.
Return ONLY valid JSON, no markdown, in exactly this shape:
{"observed": ["..."], "inferred": ["..."], "advice": "..."}
Rules:
- "observed": facts stated directly in at least one report (max 4 items).
- "inferred": likely conclusions NOT stated directly, e.g. "Traffic disruption likely" (max 3 items).
- "advice": one sentence of safety advice for people nearby.
- Flag anything that looks like misinformation or conflicts between reports inside "inferred".
Reports:
$data''';
    final text = await _call(prompt, rs.length);
    if (text == null) return null;
    try {
      final clean = text.replaceAll(RegExp(r'```json|```'), '').trim();
      return jsonDecode(clean) as Map<String, dynamic>;
    } catch (_) {
      lastStatus =
          'Gemini FAILED at ${_time()}: answer was not in the expected format';
      return null;
    }
  }

  /// Shared HTTP call. Returns the text, or null after setting [lastStatus].
  static Future<String?> _call(String prompt, int count) async {
    final key = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (key.isEmpty) {
      lastStatus = 'Gemini FAILED: GEMINI_API_KEY missing in .env';
      return null;
    }
    final stamp = _time();
    try {
      final res = await http
          .post(
            Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent',
            ),
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': key,
            },
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt},
                  ],
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 20));
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
      lastStatus = 'Gemini OK at $stamp ($count reports)';
      return text.toString().trim();
    } catch (_) {
      lastStatus = 'Gemini FAILED at $stamp: no internet or timeout';
      return null;
    }
  }

  static String _fallback(List<Report> rs) {
    final l = rs.first;
    return '${rs.length} report(s) about ${l.category} near ${l.area}. Latest: ${l.description}. (AI summary unavailable.)';
  }
}
