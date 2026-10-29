import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'database.dart';
import 'database_helper.dart';
import 'gemini_service.dart';
import 'live_feed_service.dart';

import 'package:latlong2/latlong.dart';

import 'map_screen.dart';
import 'media_service.dart';
import 'notify_service.dart';
import 'report_detail.dart';

import 'package:speech_to_text/speech_to_text.dart';

import 'dart:io';

const red = Color(0xFFE53935), bg = Color(0xFF0B0F17), card = Color(0xFF161C28);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_KEY']!,
  );
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ground Truth',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: red,
          onPrimary: Colors.white,
        ),
        navigationBarTheme: const NavigationBarThemeData(
          indicatorColor: red,
          backgroundColor: bg,
        ),
      ),
      home: const Shell(),
    ),
  );
}

IconData iconFor(String c) => switch (c) {
  'Fire' => Icons.local_fire_department,
  'Flood' || 'Waterlogging' => Icons.water_drop,
  'Earthquake' || 'Building collapse' => Icons.domain_disabled,
  'Medical' => Icons.medical_services,
  'Pothole' => Icons.warning_amber,
  'Fallen tree' => Icons.park,
  'Road closure' => Icons.block,
  'Streetlight fault' => Icons.lightbulb,
  _ => Icons.report_problem,
};

String ago(DateTime t) {
  final d = DateTime.now().difference(t);
  return d.inMinutes < 60
      ? '${d.inMinutes}m ago'
      : d.inHours < 24
      ? '${d.inHours}h ago'
      : DateFormat('d MMM').format(t);
}

/// True for audio evidence (.m4a), for reports saved by older builds.
bool isAudioReport(Report r) =>
    (r.mediaPath ?? '').endsWith('.m4a') || (r.mediaUrl ?? '').contains('.m4a');

Widget thumb(Report r, {double s = 56}) {
  final vid = MediaSvc.isVideo(r.mediaPath ?? r.mediaUrl);
  final Widget img = isAudioReport(r)
      ? Container(color: Colors.white10, child: const Icon(Icons.mic))
      : !vid && r.mediaUrl != null
      ? Image.network(
          r.mediaUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
        )
      : !vid && r.mediaPath != null && File(r.mediaPath!).existsSync()
      ? Image.file(File(r.mediaPath!), fit: BoxFit.cover)
      : Container(
          color: Colors.white10,
          child: Icon(vid ? Icons.videocam : iconFor(r.category)),
        );
  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: SizedBox(
      width: s,
      height: s,
      child: Stack(
        fit: StackFit.expand,
        children: [
          img,
          if (vid)
            const Center(
              child: Icon(Icons.play_circle_fill, color: Colors.white70),
            ),
        ],
      ),
    ),
  );
}

Widget panel(Widget child, {Color? color}) => Container(
  margin: const EdgeInsets.only(bottom: 12),
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(
    color: color ?? card,
    borderRadius: BorderRadius.circular(16),
  ),
  child: child,
);

/// Remembers the chosen city while the app is open, even if the screen is rebuilt.
class SavedPlace {
  static String? city, region;
  static double? lat, lng;
}

/// Holds the emergency call status so the report can pass it to the family SMS.
class CallStatus {
  static String state = ''; // '', 'attempted', 'connected', 'not connected'
  static String? at;

  static String forSms() {
    switch (state) {
      case 'attempted':
        return 'attempted at $at, not confirmed by caller';
      case 'connected':
        return 'connected at $at, confirmed by caller';
      case 'not connected':
        return 'not connected, reported by caller';
      default:
        return '';
    }
  }

  static void clear() {
    state = '';
    at = null;
  }
}

// ---------------------------------------------------------------- Shell (swipe + bottom nav)
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  final pc = PageController();
  int idx = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: PageView(
        controller: pc,
        onPageChanged: (i) => setState(() => idx = i),
        children: const [EmergencyScreen(), ReportsScreen(), MoreScreen()],
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: idx,
      backgroundColor: bg,
      onDestinationSelected: (i) => pc.animateToPage(
        i,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      ),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.phone), label: 'Emergency'),
        NavigationDestination(icon: Icon(Icons.article), label: 'Reports'),
        NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
      ],
    ),
  );
}

// ---------------------------------------------------------------- 1. Emergency
class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});
  @override
  State<EmergencyScreen> createState() => _EmergencyState();
}

class _EmergencyState extends State<EmergencyScreen> {
  String place = 'Locating...';
  String? callAttemptAt; // time of the last attempt, e.g. 10:02:15
  String callState = ''; // '', 'attempted', 'connected', 'not connected'

  @override
  void initState() {
    super.initState();
    Feed.pos().then((p) async {
      final a = p == null
          ? 'Location unavailable'
          : await Feed.area(p.latitude, p.longitude);
      if (mounted) setState(() => place = a);
    });
  }

  Future<void> call(String n) async {
    final t = DateFormat('HH:mm:ss').format(DateTime.now());
    setState(() {
      callAttemptAt = t;
      callState = 'attempted';
    });
    CallStatus.state = 'attempted';
    CallStatus.at = t;
    await launchUrl(
      Uri.parse('tel:$n'),
    ); // opens the dialer; the app cannot see the call result
  }

  void _setCallState(String s) {
    setState(() => callState = s);
    CallStatus.state = s;
  }

  String _callLabel() {
    switch (callState) {
      case 'attempted':
        return 'Emergency call attempted at $callAttemptAt (not confirmed)';
      case 'connected':
        return 'Call confirmed connected at $callAttemptAt';
      case 'not connected':
        return 'Call NOT connected. Tap the helpline again or use 101 / 102.';
      default:
        return '';
    }
  }

  Future<void> notifyContacts() async {
    final cs = await Db.i.contacts();
    final p = await Feed.pos();
    if (cs.isEmpty) return trusted();
    final msg =
        'EMERGENCY: I need help. My location: https://maps.google.com/?q=${p?.latitude},${p?.longitude}';
    await launchUrl(
      Uri.parse(
        'sms:${cs.map((c) => c['phone']).join(',')}?body=${Uri.encodeComponent(msg)}',
      ),
    );
  }

  Future<void> trusted() async {
    final n = TextEditingController(), ph = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, set) => FutureBuilder(
          future: Db.i.contacts(),
          builder: (_, s) => Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Trusted Contacts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                for (final c in (s.data ?? []))
                  ListTile(
                    title: Text(c['name']),
                    subtitle: Text(c['phone']),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () async {
                        await Db.i.delContact(c['id']);
                        set(() {});
                      },
                    ),
                  ),
                TextField(
                  controller: n,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: ph,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () async {
                    if (n.text.isEmpty || ph.text.isEmpty) return;
                    await Db.i.addContact(n.text, ph.text);
                    n.clear();
                    ph.clear();
                    set(() {});
                  },
                  child: const Text('Add contact'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: box.maxHeight - 32),
        child: IntrinsicHeight(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.white70),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      place,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8E1B1B),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const CircleAvatar(
                        radius: 46,
                        backgroundColor: red,
                        child: Icon(Icons.phone, size: 46, color: Colors.white),
                      ),
                      const Text(
                        'Emergency Helpline',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Call the appropriate emergency number as the first priority.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(260, 56),
                        ),
                        onPressed: () => call('112'),
                        child: const Text(
                          'Tap to Call 112',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (final e in [
                            ['Police', '100', Icons.local_police],
                            [
                              'Fire brigade',
                              '101',
                              Icons.local_fire_department,
                            ],
                            ['Ambulance', '102', Icons.emergency],
                          ])
                            InkWell(
                              onTap: () => call(e[1] as String),
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: Colors.white24,
                                    child: Icon(
                                      e[2] as IconData,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(e[0] as String),
                                  Text(
                                    e[1] as String,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (callState.isNotEmpty)
                panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _callLabel(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (callState == 'attempted') ...[
                        const SizedBox(height: 6),
                        const Text(
                          'The dialer opened, but the app cannot confirm that 112 answered. Please confirm below.',
                          style: TextStyle(fontSize: 13, color: Colors.white70),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => _setCallState('connected'),
                                child: const Text('Call connected'),
                              ),
                            ),
                            Expanded(
                              child: TextButton(
                                onPressed: () => _setCallState('not connected'),
                                child: const Text('Not connected'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

              const Spacer(flex: 1),
              const Text(
                'After the call, you can report the incident',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(60),
                ),
                icon: const Icon(Icons.warning),
                label: const Text(
                  'REPORT INCIDENT',
                  style: TextStyle(fontSize: 17),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ReportScreen(kind: 'emergency'),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(60),
                ),
                icon: const Icon(Icons.person),
                label: const Text('Trusted Contacts'),
                onPressed: trusted,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(60),
                ),
                icon: const Icon(Icons.sms),
                label: const Text('Notify family with my location'),
                onPressed: notifyContacts,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------- 2. Incident reports
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsState();
}

class _ReportsState extends State<ReportsScreen> {
  List<Report> rs = [];
  List<Report> top = [];
  Map<String, dynamic>? ai;
  List<Map<String, String>> officialAlerts = [];
  bool aiLoading = false;
  LatLng? here;

  @override
  void initState() {
    super.initState();
    Feed.pos().then((p) {
      if (p != null && mounted) {
        setState(() => here = LatLng(p.latitude, p.longitude));
      }
      load();
    });
    load();
  }

  Future<void> load() async {
    final r = await Db.i.fetch('emergency');
    final cl = Db.i.clusters(r);
    final incident = cl.isEmpty ? <Report>[] : cl.first;
    if (!mounted) return;
    setState(() {
      rs = r;
      top = incident;
      ai = null;
      aiLoading = incident.isNotEmpty;
    });

    // Official alerts for the area (OpenWeather), shown beside user reports
    if (here != null) {
      final w = await Feed.weather(here!.latitude, here!.longitude);
      if (mounted) setState(() => officialAlerts = Feed.alerts(w));
    }

    if (incident.isNotEmpty) {
      final s = await Gemini.analyse(incident);
      if (mounted) {
        setState(() {
          ai = s;
          aiLoading = false;
        });
      }
    }
  }

  /// Confidence is calculated from the number of reports and whether any has media.
  static String confidence(List<Report> rs) {
    final n = rs.map((r) => r.id).toSet().length;
    final withMedia = rs.where(MediaSvc.hasMedia).length;
    if (n >= 4 || (n >= 3 && withMedia >= 1)) return 'High';
    if (n >= 2) return 'Medium';
    return 'Low';
  }

  /// Status is calculated from the newest report's age.
  static String statusOf(List<Report> rs) {
    final latest = rs
        .map((r) => r.createdAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    return DateTime.now().difference(latest).inHours < 2
        ? 'Likely still active'
        : 'Unconfirmed / possibly resolved';
  }

  Widget tile(Report r) => ListTile(
    leading: thumb(r),
    title: Text(r.title),
    subtitle: Text(
      '${r.area} • ${ago(r.createdAt)}${r.synced ? '' : ' • queued offline'}',
    ),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Audio can't be saved to the gallery, so the download icon is hidden for it
        if (MediaSvc.hasMedia(r) && !isAudioReport(r))
          IconButton(
            icon: const Icon(Icons.download, size: 20),
            onPressed: () async {
              final m = await MediaSvc.download(r);
              if (mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(m)));
              }
            },
          ),
        Icon(r.synced ? Icons.cloud_done : Icons.cloud_off, size: 18),
      ],
    ),
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReportDetail(r: r)),
    ),
  );

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: value),
        ],
      ),
    ),
  );

  Widget _incidentCard() {
    final first = top.first;
    final conf = confidence(top);
    final status = statusOf(top);
    final confColor = conf == 'High'
        ? Colors.greenAccent
        : conf == 'Medium'
        ? Colors.amberAccent
        : Colors.white54;
    final observed =
        (ai?['observed'] as List?)?.cast<String>() ?? const <String>[];
    final inferred =
        (ai?['inferred'] as List?)?.cast<String>() ?? const <String>[];
    final advice = ai?['advice']?.toString();
    final latest = top
        .map((r) => r.createdAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department, color: red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${first.category} • ${first.area}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const Chip(label: Text('LIVE'), backgroundColor: red),
            ],
          ),
          const SizedBox(height: 8),
          _line('Status', status),
          if (top.any((r) => r.callStatus != null))
            _line(
              'Emergency call',
              top.firstWhere((r) => r.callStatus != null).callStatus!,
            ),

          _line(
            'Confidence',
            '$conf (${top.length} independent report${top.length == 1 ? '' : 's'})',
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '● $conf confidence',
              style: TextStyle(color: confColor, fontSize: 12),
            ),
          ),
          _line(
            'First reported',
            DateFormat('HH:mm').format(
              top
                  .map((r) => r.createdAt)
                  .reduce((a, b) => a.isBefore(b) ? a : b),
            ),
          ),
          _line(
            'Last updated',
            '${ago(latest)} (${DateFormat('HH:mm').format(latest)})',
          ),
          const Divider(height: 24),
          if (aiLoading) const Text('Analysing reports with Gemini...'),
          if (!aiLoading && ai == null)
            const Text('AI analysis unavailable. Showing reports only.'),
          if ((ai?['media_verdict'] ?? '').toString().isNotEmpty)
            Text(
              'Photo check: ${Gemini.mediaLabel(ai!['media_verdict'].toString())}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color:
                    ai!['media_verdict'] == 'likely_fake' ||
                        ai!['media_verdict'] == 'reused_media'
                    ? Colors.redAccent
                    : Colors.amberAccent,
              ),
            ),
          for (final f
              in ((ai?['image_findings'] as List?) ?? []).cast<String>())
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                f,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          if ((ai?['media_assessment'] ?? '').toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                ai!['media_assessment'].toString(),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),

          if ((ai?['correlation'] ?? '').toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Correlation: ${ai!['correlation']}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          const SizedBox(height: 8),
          if (observed.isNotEmpty) ...[
            const Text(
              'Observed (reported directly)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            for (final o in observed)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('• $o'),
              ),
            const SizedBox(height: 8),
          ],
          if (inferred.isNotEmpty) ...[
            const Text(
              'Inferred (likely, not confirmed)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            for (final i in inferred)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '• $i',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            const SizedBox(height: 8),
          ],
          if (advice != null && advice.isNotEmpty)
            Text(
              'Advice: $advice',
              style: const TextStyle(color: Colors.amberAccent),
            ),
          const Divider(height: 24),
          const Text(
            'Official alerts (OpenWeather, your area)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          if (officialAlerts.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('No active official alerts.'),
            ),
          for (final a in officialAlerts)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '⚠ ${a['t']}: ${a['d']}',
                style: const TextStyle(color: Colors.amberAccent),
              ),
            ),
          const Divider(height: 24),
          const Text('Evidence', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final r in top.take(8)) thumb(r, s: 80)],
          ),
          if (top.any((r) => !MediaSvc.hasMedia(r)))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${top.where((r) => !MediaSvc.hasMedia(r)).length} text-only report(s) without media',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    child: Scaffold(
      backgroundColor: bg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: red,
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Report'),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ReportScreen(kind: 'emergency'),
            ),
          );
          load();
        },
      ),
      appBar: AppBar(
        backgroundColor: bg,
        toolbarHeight: 0,
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Overview'),
            Tab(text: 'Timeline'),
            Tab(text: 'Reports'),
            Tab(text: 'Map'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          RefreshIndicator(
            onRefresh: load,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (rs.isEmpty)
                  const SizedBox(
                    height: 420,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 72,
                            color: Colors.white38,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No incidents reported yet',
                            style: TextStyle(fontSize: 18),
                          ),
                          Text(
                            'Tap Report to share evidence.',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (top.isNotEmpty) _incidentCard(),
                if (rs.isNotEmpty && top.isEmpty)
                  panel(
                    const Text(
                      'Reports exist but none are close enough in time and place to form an incident yet.',
                    ),
                  ),
                panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gemini status',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Sync: ${Db.lastSyncError ?? 'OK'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                      Text(
                        'Fetch: ${Db.lastFetchError ?? 'OK'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        Gemini.lastStatus,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ListView(
            children: [
              for (final r in [
                ...rs,
              ]..sort((a, b) => a.createdAt.compareTo(b.createdAt)))
                tile(r),
            ],
          ),
          RefreshIndicator(
            onRefresh: load,
            child: ListView(children: [for (final r in rs) tile(r)]),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: here == null
                ? const Center(child: Text('Waiting for GPS...'))
                : MapScreen(reports: rs, center: here),
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------- Report form (emergency + local issue)
class ReportScreen extends StatefulWidget {
  final String kind;
  const ReportScreen({super.key, required this.kind});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late final cats = widget.kind == 'emergency'
      ? ['Fire', 'Flood', 'Earthquake', 'Building collapse', 'Medical', 'Other']
      : [
          'Waterlogging',
          'Pothole',
          'Fallen tree',
          'Road closure',
          'Streetlight fault',
          'Other',
        ];
  late String cat = cats.first;
  final desc = TextEditingController();
  String? path;
  bool busy = false;
  final stt = SpeechToText();
  bool listening = false;

  Future<void> toggleVoice() async {
    if (listening) {
      await stt.stop();
      setState(() => listening = false);
      return;
    }
    final ok = await stt.initialize(
      onError: (_) => setState(() => listening = false),
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') {
          setState(() => listening = false);
        }
      },
    );
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Voice input not available. Allow microphone access, or type instead.',
            ),
          ),
        );
      }
      return;
    }
    setState(() => listening = true);
    await stt.listen(
      localeId: 'en_IN',
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 5),
      onResult: (r) {
        desc.text = r.recognizedWords;
        desc.selection = TextSelection.collapsed(offset: desc.text.length);
      },
    );
  }

  @override
  void dispose() {
    stt.stop();
    super.dispose();
  }

  Future<void> pick(bool video) async {
    final f = video
        ? await ImagePicker().pickVideo(
            source: ImageSource.camera,
            maxDuration: const Duration(seconds: 30),
          )
        : await ImagePicker().pickImage(
            source: ImageSource.camera,
            imageQuality: 70,
          );
    if (f != null) setState(() => path = f.path);
  }

  Future<void> submit() async {
    setState(() => busy = true);
    final p = await Feed.pos();
    if (p == null) {
      setState(() => busy = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location not available. Turn on GPS and allow location permission, then try again.',
            ),
          ),
        );
      }
      return;
    }
    final lat = p.latitude, lng = p.longitude;
    final area = await Feed.area(lat, lng);
    final r = Report(
      id: '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(99999)}',
      kind: widget.kind,
      category: cat,
      title: cat == 'Other' ? 'Incident' : cat,
      description: desc.text.trim(),
      area: area,
      lat: lat,
      lng: lng,
      createdAt: DateTime.now(),
      mediaPath: path,
      callStatus: widget.kind == 'emergency' && CallStatus.state.isNotEmpty
          ? CallStatus.forSms()
          : null,
    );
    await Db.i.submit(r);
    Mesh.i.broadcast(
      r,
    ); // also relay to nearby devices (works with no internet)
    if (!mounted) return;
    final sm = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    final callInfo = widget.kind == 'emergency' ? CallStatus.forSms() : '';
    sm.showSnackBar(
      SnackBar(content: Text(await Notifier.report(r, callStatus: callInfo))),
    );
    if (widget.kind == 'emergency') {
      CallStatus.clear(); // so the next incident doesn't reuse this status
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.kind == 'emergency' ? 'Report Incident' : 'Report Local Issue',
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => pick(false),
                icon: const Icon(Icons.photo_camera),
                label: const Text('Photo'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => pick(true),
                icon: const Icon(Icons.videocam),
                label: const Text('Video'),
              ),
            ),
          ],
        ),
        if (path != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Attached: ${path!.split('/').last}',
              style: const TextStyle(color: Colors.greenAccent),
            ),
          ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: cat,
          items: [
            for (final c in cats) DropdownMenuItem(value: c, child: Text(c)),
          ],
          onChanged: (v) => setState(() => cat = v!),
          decoration: const InputDecoration(labelText: 'Type'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: desc,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'What did you see?',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
          onPressed: toggleVoice,
          icon: Icon(
            listening ? Icons.stop_circle : Icons.mic,
            color: listening ? red : null,
          ),
          label: Text(
            listening
                ? 'Listening... tap to stop'
                : 'Speak description (voice)',
          ),
        ),
        const SizedBox(height: 8),
        const ListTile(
          leading: Icon(Icons.location_on),
          title: Text('Location & time'),
          subtitle: Text('Auto-detected on submit'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: busy ? null : submit,
          child: Text(busy ? 'Saving...' : 'Submit'),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------- 3. Local awareness (+ offline mesh)
class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});
  @override
  State<MoreScreen> createState() => _MoreState();
}

class _MoreState extends State<MoreScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // keeps the selected city when swiping to other tabs

  double lat = 0, lng = 0;
  String city = 'Locating...', region = '';
  bool gotLocation = false;
  Map<String, dynamic>? w;
  List<Map<String, dynamic>> news = [];
  List<Report> issues = [];
  Map<String, dynamic>? localAi; // Gemini verification of local issues
  bool localAiLoading = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    Mesh.i.onChange = () {
      if (mounted) setState(() {});
    };
    if (SavedPlace.lat != null) {
      // Restore the city the user picked earlier
      final label = (SavedPlace.region ?? '').isNotEmpty
          ? '${SavedPlace.city}, ${SavedPlace.region}'
          : SavedPlace.city!;
      _applyPlace(label, SavedPlace.lat!, SavedPlace.lng!);
      load();
    } else {
      useGps();
    }
    // GNews free plan allows ~100 requests/day; 60 minutes keeps us well inside that
    _timer = Timer.periodic(const Duration(minutes: 60), (_) => load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Uses the phone's GPS location (default).
  Future<void> useGps() async {
    final p = await Feed.pos();
    if (p == null) {
      if (mounted) setState(() => city = 'Location off');
      return;
    }
    final label = await Feed.area(p.latitude, p.longitude);
    _applyPlace(label, p.latitude, p.longitude);
    if (mounted) setState(() {});
    load();
  }

  /// Sets city, region (state) and coordinates from a "City, State" label, and saves them.
  void _applyPlace(String label, double la, double lo) {
    final parts = label.split(',');
    lat = la;
    lng = lo;
    city = parts.first.trim();
    region = parts.length > 1 ? parts.last.trim() : '';
    gotLocation = true;
    SavedPlace.city = city;
    SavedPlace.region = region;
    SavedPlace.lat = la;
    SavedPlace.lng = lo;
  }

  Future<void> load() async {
    if (!gotLocation) return;
    final results = await Future.wait([
      Feed.weather(lat, lng),
      Feed.newsNearby(city),
      Db.i.fetch('local'),
    ]);
    if (!mounted) return;
    setState(() {
      w = results[0] as Map<String, dynamic>?;
      news = results[1] as List<Map<String, dynamic>>;
      issues = results[2] as List<Report>;
      localAiLoading = issues.isNotEmpty;
      if (issues.isEmpty) localAi = null;
    });

    if (issues.isEmpty) return;

    final analysis = await Gemini.analyse(issues, local: true);
    if (mounted) {
      setState(() {
        localAi = analysis;
        localAiLoading = false;
      });
    }
  }

  /// Human-readable label for the overall verdict of local issues.
  static String _verdictText(String v) => switch (v) {
    'consistent' => 'Reports are consistent with each other',
    'possibly_coordinated' => 'Reports may be coordinated or copied',
    'contradictory' => 'Reports contradict each other',
    'insufficient' => 'Not enough information to judge',
    _ => v.replaceAll('_', ' '),
  };

  /// Card that shows the same verification details as the emergency card.
  Widget _localAnalysisCard() {
    if (localAiLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Checking local reports with Gemini...'),
      );
    }
    final ai = localAi;
    if (ai == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'AI check unavailable. Showing reports only.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    final mediaVerdict = (ai['media_verdict'] ?? '').toString();
    final observed = (ai['observed'] as List?)?.cast<String>() ?? const [];
    final inferred = (ai['inferred'] as List?)?.cast<String>() ?? const [];
    final findings =
        (ai['image_findings'] as List?)?.cast<String>() ?? const [];
    final flags = (ai['flags'] as List?)?.whereType<Map>().toList() ?? const [];
    final advice = (ai['advice'] ?? '').toString();
    final assessment = (ai['media_assessment'] ?? '').toString();
    final correlation = (ai['correlation'] ?? '').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Text(
          _verdictText((ai['verdict'] ?? 'insufficient').toString()),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        if (mediaVerdict.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Photo check: ${Gemini.mediaLabel(mediaVerdict)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color:
                    mediaVerdict == 'likely_fake' ||
                        mediaVerdict == 'reused_media'
                    ? Colors.redAccent
                    : Colors.amberAccent,
              ),
            ),
          ),
        for (final f in findings)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              f,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        if (assessment.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              assessment,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        if (correlation.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Correlation: $correlation',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        if (observed.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'Observed (reported directly)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          for (final o in observed)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('• $o'),
            ),
        ],
        if (inferred.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'Inferred (likely, not confirmed)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          for (final i in inferred)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '• $i',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
        ],
        if (flags.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final f in flags)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '⚠ ${f['detail'] ?? f['type'] ?? ''}',
                style: const TextStyle(color: Colors.amberAccent, fontSize: 13),
              ),
            ),
        ],
        if (advice.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Advice: $advice',
              style: const TextStyle(color: Colors.amberAccent),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    final al = Feed.alerts(w);
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Autocomplete<Map<String, dynamic>>(
            displayStringForOption: (o) => o['label'] as String,
            optionsBuilder: (TextEditingValue v) async {
              if (v.text.trim().length < 2) {
                return const <Map<String, dynamic>>[];
              }
              return Feed.suggest(v.text.trim());
            },
            onSelected: (o) {
              _applyPlace(
                o['label'] as String,
                o['lat'] as double,
                o['lng'] as double,
              );
              setState(() {});
              load();
            },
            fieldViewBuilder: (ctx, controller, focusNode, onSubmit) =>
                TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Showing: $city. Type another city, e.g. Mum',
                    filled: true,
                    fillColor: card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: useGps,
              icon: const Icon(Icons.my_location, size: 18),
              label: const Text('Use my GPS location'),
            ),
          ),
          const SizedBox(height: 4),
          panel(
            w == null
                ? const Text('Weather unavailable (offline?)')
                : Row(
                    children: [
                      Image.network(
                        'https://openweathermap.org/img/wn/${w!['weather'][0]['icon']}@2x.png',
                        width: 60,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.cloud, size: 40),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${(w!['main']['temp'] as num).round()}°C',
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(w!['weather'][0]['description']),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        'Feels like ${(w!['main']['feels_like'] as num).round()}°\nHumidity ${w!['main']['humidity']}%',
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
            color: const Color(0xFF1B3A5C),
          ),
          for (final a in al)
            panel(
              Row(
                children: [
                  const Icon(Icons.warning, color: red),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a['t']!,
                          style: const TextStyle(
                            color: red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(a['d']!),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Local Issues',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ReportScreen(kind: 'local'),
                          ),
                        );
                        load();
                      },
                      child: const Text('Report Issue'),
                    ),
                  ],
                ),
                _localAnalysisCard(),
                Text(
                  Gemini.lastStatus,
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
                for (final r in issues.take(8))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: thumb(r, s: 44),
                    title: Text(r.title),
                    subtitle: Text('${r.area} • ${ago(r.createdAt)}'),
                  ),
                if (gotLocation)
                  SizedBox(
                    height: 260,
                    child: MapScreen(reports: issues, center: LatLng(lat, lng)),
                  ),
                if (!gotLocation)
                  const SizedBox(
                    height: 60,
                    child: Center(
                      child: Text(
                        'Waiting for GPS... turn on location to see the map.',
                      ),
                    ),
                  ),
              ],
            ),
          ),
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Local News: $city + nearby',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  Feed.newsStatus,
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),

                if (news.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'No local news found for $city or nearby towns right now.',
                    ),
                  ),
                for (final n in news)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      n['title'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${n['town']} • ${n['source']?['name'] ?? ''}',
                    ),
                    onTap: () => launchUrl(Uri.parse(n['url'])),
                  ),
              ],
            ),
          ),
          panel(
            Column(
              children: [
                const Row(
                  children: [
                    Icon(Icons.hub),
                    SizedBox(width: 8),
                    Text(
                      'Offline Communication',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const Text(
                  'No internet? Relay reports through nearby phones via Bluetooth / Google Nearby.',
                ),
                SwitchListTile(
                  value: Mesh.i.running,
                  title: Text(
                    Mesh.i.running
                        ? 'Mesh ON • ${Mesh.i.peers.length} nearby device(s)'
                        : 'Use Offline Network',
                  ),
                  onChanged: (v) => v ? Mesh.i.start() : Mesh.i.stop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
