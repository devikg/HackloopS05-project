import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'database.dart';
import 'database_helper.dart';

/// Notifies trusted contacts by SMS when the user files a report.
class Notifier {
  static Future<String> report(Report r, {String? callStatus}) async {
    final cs = await Db.i.contacts();
    if (cs.isEmpty) {
      return 'Report saved. Add Trusted Contacts to notify family.';
    }

    final latest = await Db.i.byId(r.id) ?? r;
    final time = DateFormat('HH:mm').format(r.createdAt);
    final callLine = (callStatus == null || callStatus.isEmpty)
        ? ''
        : '\nEmergency call: $callStatus';

    final msg =
        'SAFE ALERT: ${r.category} reported at $time.'
        '$callLine'
        '\nPlace: ${r.area}'
        '\nLocation: https://maps.google.com/?q=${r.lat},${r.lng}'
        '${r.description.isEmpty ? '' : '\nDetails: ${r.description}'}'
        '${latest.mediaUrl == null ? '' : '\nPhoto/Video: ${latest.mediaUrl}'}';

    final phones = cs.map((c) => c['phone'] as String).toList();
    await launchUrl(
      Uri.parse('sms:${phones.join(',')}?body=${Uri.encodeComponent(msg)}'),
    );
    return 'Report saved. Press Send in your messages app to notify contacts.';
  }
}
