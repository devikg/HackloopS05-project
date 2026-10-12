import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';

void main() => runApp(const SafeSphereApp());

const Color _background = Color(0xFF080D12);
const Color _surface = Color(0xFF151C23);
const Color _surface2 = Color(0xFF202A34);
const Color _red = Color(0xFFE6333B);
const Color _muted = Color(0xFF9BA8B5);
const Color _text = Color(0xFFF4F6F8);

class SafeSphereApp extends StatelessWidget {
  const SafeSphereApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeSphere',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _red,
          brightness: Brightness.dark,
          surface: _surface,
        ),
        fontFamily: 'Roboto',
      ),
      home: const SafeSphereHome(),
    );
  }
}

class LocalIssue {
  const LocalIssue({
    required this.title,
    required this.area,
    required this.category,
    required this.time,
    required this.icon,
    required this.color,
    this.description = '',
    this.mediaPaths = const [],
  });

  final String title;
  final String area;
  final String category;
  final String time;
  final IconData icon;
  final Color color;
  final String description;
  final List<String> mediaPaths;
}

class SafeSphereHome extends StatefulWidget {
  const SafeSphereHome({super.key});

  @override
  State<SafeSphereHome> createState() => _SafeSphereHomeState();
}

class _SafeSphereHomeState extends State<SafeSphereHome> {
  int _selectedIndex = 0;
  int _detailTab = 0;
  final PageController _pageController = PageController();

  final List<LocalIssue> _issues = [
    const LocalIssue(
      title: 'Waterlogging',
      area: 'Indiranagar',
      category: 'Local',
      time: '2h ago',
      icon: Icons.water_drop_rounded,
      color: Color(0xFFF18A9B),
    ),
    const LocalIssue(
      title: 'Pothole',
      area: 'Koramangala',
      category: 'Local',
      time: '3h ago',
      icon: Icons.warning_amber_rounded,
      color: Color(0xFFF49B89),
    ),
    const LocalIssue(
      title: 'Fallen Tree',
      area: 'Jayanagar',
      category: 'Local',
      time: '5h ago',
      icon: Icons.park_rounded,
      color: Color(0xFFF0CC79),
    ),
    const LocalIssue(
      title: 'Road Closure',
      area: 'Whitefield',
      category: 'Local',
      time: '6h ago',
      icon: Icons.block_rounded,
      color: Color(0xFF9E9BEF),
    ),
  ];

  final List<LocalIssue> _reports = [
    const LocalIssue(
      title: 'Fire at Sunrise Apartments',
      area: '3.4 km away',
      category: 'Emergency',
      time: '12 reports',
      icon: Icons.local_fire_department_rounded,
      color: Color(0xFFE65A47),
      description: 'Incident reported by nearby users.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _openReportForm({bool localIssue = false}) async {
    final LocalIssue? result = await Navigator.of(context).push<LocalIssue>(
      MaterialPageRoute(
        builder: (_) => ReportIncidentPage(localIssue: localIssue),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (localIssue) {
        _issues.insert(0, result);
      } else {
        _reports.insert(0, result);
      }
      _selectedIndex = localIssue ? 2 : 1;
      _pageController.jumpToPage(_selectedIndex);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report saved on this device.')),
    );
  }

  void _showEmergencyOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surface,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Emergency helplines',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('Choose a number to call from your phone.',
                  style: TextStyle(color: _muted)),
              const SizedBox(height: 16),
              _helplineRow(Icons.emergency_rounded, 'National emergency', '112'),
              _helplineRow(Icons.local_fire_department_rounded, 'Fire service', '101'),
              _helplineRow(Icons.medical_services_rounded, 'Ambulance', '108'),
              const SizedBox(height: 10),
              const Text(
                'Calling is not yet connected in this prototype. Use your phone dialer for an emergency.',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _helplineRow(IconData icon, String title, String number) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: _surface2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Icon(icon, color: _red),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
        Text(number, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _buildEmergencyPage(),
      _buildReportsPage(),
      _buildLocalAwarenessPage(),
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: PageView(
          controller: _pageController,
          onPageChanged: (index) => setState(() => _selectedIndex = index),
          children: pages,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 72,
        backgroundColor: const Color(0xFF0D1319),
        indicatorColor: _red.withValues(alpha: 0.18),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
          _pageController.animateToPage(index, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.call_rounded),
            selectedIcon: Icon(Icons.call_rounded, color: _red),
            label: 'Emergency',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment_rounded, color: _red),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded),
            selectedIcon: Icon(Icons.more_horiz_rounded, color: _red),
            label: 'More',
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyPage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      children: [
        Row(children: [
          const Icon(Icons.location_on_rounded, color: _text, size: 23),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Current Location', style: TextStyle(color: _muted, fontSize: 12)),
              SizedBox(height: 2),
              Text('Your area', style: TextStyle(fontWeight: FontWeight.w700)),
            ]),
          ),
          _roundButton(Icons.settings_outlined, () => _showInfo('Settings', 'Settings will be added in a later update.')),
        ]),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE51D25), Color(0xFF86191E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [BoxShadow(color: _red.withValues(alpha: 0.16), blurRadius: 24, offset: const Offset(0, 10))],
          ),
          child: Column(children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.13),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.38), width: 1.5),
              ),
              child: const Icon(Icons.call_rounded, size: 38, color: Colors.white),
            ),
            const SizedBox(height: 18),
            const Text('Emergency Helpline', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 7),
            const Text('Call the appropriate emergency number\nas the first priority.', textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, height: 1.35, fontSize: 13)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _showEmergencyOptions,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3841),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const StadiumBorder(),
                ),
                child: const Text('Tap to Call', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: _emergencyShortcut(Icons.local_police_rounded, 'Police', '112', _showEmergencyOptions)),
              Expanded(child: _emergencyShortcut(Icons.local_fire_department_rounded, 'Fire Brigade', '101', _showEmergencyOptions)),
              Expanded(child: _emergencyShortcut(Icons.medical_services_rounded, 'Ambulance', '108', _showEmergencyOptions)),
            ]),
          ]),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(22)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('After the call, you can report the incident', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openReportForm(),
                icon: const Icon(Icons.assignment_outlined),
                label: const Text('Report Incident', style: TextStyle(fontWeight: FontWeight.w800)),
                style: FilledButton.styleFrom(
                  backgroundColor: _red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        _sectionHeader('Stay informed', 'View updates', () { setState(() => _selectedIndex = 2); _pageController.animateToPage(2, duration: const Duration(milliseconds: 220), curve: Curves.easeOut); }),
        const SizedBox(height: 10),
        _smallInfoCard(Icons.cloud_outlined, 'Weather & local alerts', 'See updates reported around you', const Color(0xFF69B9EE), () { setState(() => _selectedIndex = 2); _pageController.animateToPage(2, duration: const Duration(milliseconds: 220), curve: Curves.easeOut); }),
      ],
    );
  }

  Widget _buildReportsPage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      children: [
        Row(children: [
          const Expanded(child: Text('Incident Reports', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900))),
          _roundButton(Icons.add_rounded, () => _openReportForm()),
        ]),
        const SizedBox(height: 16),
        Container(
          height: 238,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFF4A555D), Color(0xFF20262C), Color(0xFF11161B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(children: [
            Positioned(right: -10, top: 22, child: Icon(Icons.apartment_rounded, size: 180, color: Colors.white.withValues(alpha: 0.09))),
            Positioned(right: 22, top: 34, child: Icon(Icons.local_fire_department_rounded, size: 94, color: const Color(0xFFFF6C38).withValues(alpha: 0.75))),
            Positioned(left: 14, top: 14, child: _badge('●  LIVE / ONGOING', _red)),
            Positioned(right: 14, top: 14, child: _badge('↗  1.2 km', Colors.black54)),
            Positioned(left: 17, right: 17, bottom: 18, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Fire at Sunrise Apartments', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              const Row(children: [Icon(Icons.location_on_rounded, size: 15), SizedBox(width: 4), Text('3.4 km away  •  12 reports', style: TextStyle(color: Colors.white70, fontSize: 12))]),
            ])),
          ]),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(color: _surface2, borderRadius: BorderRadius.circular(16)),
          child: Row(children: List.generate(4, (index) {
            const labels = ['Overview', 'Timeline', 'Reports', 'Map'];
            final selected = _detailTab == index;
            return Expanded(child: GestureDetector(
              onTap: () => setState(() => _detailTab = index),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: selected ? const Color(0xFFE9EDF1) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                child: Text(labels[index], textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? const Color(0xFF17202A) : _text)),
              ),
            ));
          })),
        ),
        const SizedBox(height: 14),
        if (_detailTab == 0) ...[
          _panelCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [const Icon(Icons.auto_awesome_rounded, size: 19), const SizedBox(width: 8), const Expanded(child: Text('AI Situation Summary', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))), _badge('AI', const Color(0xFFB2C9FF), darkText: true)]),
              const SizedBox(height: 12),
              const Text('A fire has been reported at Sunrise Apartments. Nearby users have shared multiple reports. Verify information with emergency services and avoid the area.', style: TextStyle(height: 1.45, color: Color(0xFFD8DEE5), fontSize: 13)),
              const SizedBox(height: 10),
              const Text('Demo summary • not verified', style: TextStyle(color: _muted, fontSize: 11)),
            ]),
          ),
          const SizedBox(height: 12),
          _panelCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Recent Evidence', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _evidenceTile(Icons.videocam_rounded, 'Video', '0:24', const Color(0xFF6C5650))),
              const SizedBox(width: 8),
              Expanded(child: _evidenceTile(Icons.image_rounded, 'Photo', '0:05', const Color(0xFF45634E))),
              const SizedBox(width: 8),
              Expanded(child: _evidenceTile(Icons.image_rounded, 'Photo', '0:08', const Color(0xFF57616D))),
            ]),
            const SizedBox(height: 12),
            TextButton.icon(onPressed: () => setState(() => _detailTab = 2), icon: const Icon(Icons.arrow_forward_rounded, size: 17), label: const Text('View all reports (12)')),
          ])),
        ] else if (_detailTab == 1) ...[
          _panelCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Incident timeline', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 16),
            _timelineItem('First report received', '12 minutes ago', true),
            _timelineItem('Additional reports submitted', '9 minutes ago', false),
            _timelineItem('Situation awaiting verification', 'Just now', false),
          ])),
        ] else if (_detailTab == 2) ...[
          ..._reports.map((report) => _reportRow(report)),
          OutlinedButton.icon(onPressed: () => _openReportForm(), icon: const Icon(Icons.add_rounded), label: const Text('Submit a report')),
        ] else ...[
          _panelCard(child: const Column(children: [Icon(Icons.map_outlined, size: 54, color: _muted), SizedBox(height: 10), Text('Incident map', style: TextStyle(fontWeight: FontWeight.w800)), SizedBox(height: 5), Text('Location pins will appear here when reports include GPS coordinates.', textAlign: TextAlign.center, style: TextStyle(color: _muted))])),
        ],
        const SizedBox(height: 14),
        _sectionHeader('My Reports', 'New report', () => _openReportForm()),
        const SizedBox(height: 8),
        ..._reports.take(3).map(_reportRow),
      ],
    );
  }

  Widget _buildLocalAwarenessPage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(colors: [Color(0xFF163A58), Color(0xFF101F30)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: Row(children: [
            const Icon(Icons.search_rounded, color: Colors.white70),
            const SizedBox(width: 10),
            const Expanded(child: Text('Search area or location', style: TextStyle(color: Colors.white70))),
            _roundButton(Icons.tune_rounded, () => _showInfo('Location settings', 'Location-based filtering will be connected later.')),
          ]),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 19),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(colors: [Color(0xFF477FA0), Color(0xFF24435E)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: Row(children: [
            const Icon(Icons.cloud_rounded, color: Colors.white, size: 43),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('26°C', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800)),
              Text('Light rain', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ])),
            const Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('High 28° | Low 22°', style: TextStyle(fontSize: 11, color: Colors.white)), SizedBox(height: 5), Text('Demo weather', style: TextStyle(fontSize: 11, color: Colors.white70))]),
          ]),
        ),
        const SizedBox(height: 12),
        _alertRow(Icons.warning_rounded, const Color(0xFFE95656), 'Heavy Rainfall Alert', 'Weather alert preview', 'View details'),
        _alertRow(Icons.traffic_rounded, const Color(0xFFE9BC48), 'Traffic Advisory', 'Road work may cause delays', 'View details'),
        const SizedBox(height: 16),
        Row(children: [
          const Expanded(child: Text('Local Issues', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
          OutlinedButton.icon(
            onPressed: () => _openReportForm(localIssue: true),
            icon: const Icon(Icons.add_location_alt_outlined, size: 16),
            label: const Text('Report Issue', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10)),
          ),
        ]),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(20)),
          child: Column(children: _issues.map((issue) => _issueRow(issue)).toList()),
        ),
        const SizedBox(height: 16),
        _panelCard(child: const Row(children: [Icon(Icons.info_outline_rounded, color: _muted), SizedBox(width: 10), Expanded(child: Text('Weather and official alerts are demo content in this version. Live updates and location filtering are not connected yet.', style: TextStyle(color: _muted, fontSize: 12, height: 1.4)))])),
      ],
    );
  }

  Widget _emergencyShortcut(IconData icon, String title, String number, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(children: [
        CircleAvatar(radius: 20, backgroundColor: Colors.white.withValues(alpha: 0.16), child: Icon(icon, size: 21, color: Colors.white)),
        const SizedBox(height: 7),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.white)),
        const SizedBox(height: 2),
        Text(number, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
      ]),
    );
  }

  Widget _actionShortcut(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(children: [
        CircleAvatar(radius: 22, backgroundColor: const Color(0xFF303A45), child: Icon(icon, color: const Color(0xFFE1E8EF), size: 21)),
        const SizedBox(height: 8),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, height: 1.35, color: _text)),
      ]),
    );
  }

  Widget _roundButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: _surface2,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 42, height: 42, child: Icon(icon, size: 21, color: _text)),
      ),
    );
  }

  Widget _sectionHeader(String title, String action, VoidCallback onTap) => Row(children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
        TextButton(onPressed: onTap, child: Text(action)),
      ]);

  Widget _smallInfoCard(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [Icon(icon, color: color, size: 28), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: _muted, fontSize: 12))])), const Icon(Icons.chevron_right_rounded, color: _muted)]),
      ),
    );
  }

  Widget _badge(String label, Color color, {bool darkText = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(30)),
        child: Text(label, style: TextStyle(fontSize: 10, letterSpacing: 0.2, color: darkText ? const Color(0xFF14202B) : Colors.white, fontWeight: FontWeight.w800)),
      );

  Widget _panelCard({required Widget child}) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: const Color(0xFFF1F3F6), borderRadius: BorderRadius.circular(20)),
        child: DefaultTextStyle(style: const TextStyle(color: Color(0xFF18212A)), child: IconTheme(data: const IconThemeData(color: Color(0xFF18212A)), child: child)),
      );

  Widget _evidenceTile(IconData icon, String label, String duration, Color color) => Container(
        height: 82,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        child: Stack(children: [
          Align(alignment: Alignment.center, child: Icon(icon, size: 27, color: Colors.white70)),
          Align(alignment: Alignment.bottomLeft, child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))),
          Align(alignment: Alignment.bottomRight, child: Text(duration, style: const TextStyle(color: Colors.white, fontSize: 9))),
        ]),
      );

  Widget _timelineItem(String title, String time, bool active) => Padding(
        padding: const EdgeInsets.only(bottom: 17),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(active ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded, color: active ? _red : _muted, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text(time, style: const TextStyle(color: _muted, fontSize: 12))])),
        ]),
      );

  Widget _reportRow(LocalIssue report) => Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          CircleAvatar(backgroundColor: report.color.withValues(alpha: 0.18), child: Icon(report.icon, color: report.color, size: 20)),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(report.title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text('${report.area} • ${report.time}', style: const TextStyle(color: _muted, fontSize: 11))])),
          const Icon(Icons.chevron_right_rounded, color: _muted),
        ]),
      );

  Widget _alertRow(IconData icon, Color color, String title, String subtitle, String action) => InkWell(
        onTap: () => _showInfo(title, '$subtitle. Live alert details will be integrated later.'),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(17)),
          child: Row(children: [
            CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, color: color, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Color(0xFF7E282D), fontWeight: FontWeight.w800, fontSize: 13)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: Color(0xFF596572), fontSize: 11)), const SizedBox(height: 2), Text(action, style: const TextStyle(color: Color(0xFF596572), fontSize: 10))])),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF596572)),
          ]),
        ),
      );

  Widget _issueRow(LocalIssue issue) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(children: [
          CircleAvatar(radius: 19, backgroundColor: issue.color.withValues(alpha: 0.18), child: Icon(issue.icon, color: issue.color, size: 19)),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(issue.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)), const SizedBox(height: 4), Text('${issue.area} • ${issue.time}', style: const TextStyle(color: _muted, fontSize: 11))])),
          Container(
            width: 53,
            height: 46,
            decoration: BoxDecoration(color: issue.color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
            child: Icon(issue.icon, color: issue.color, size: 23),
          ),
        ]),
      );

  void _showInfo(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }
}

class ReportIncidentPage extends StatefulWidget {
  const ReportIncidentPage({super.key, required this.localIssue});
  final bool localIssue;

  @override
  State<ReportIncidentPage> createState() => _ReportIncidentPageState();
}

class _ReportIncidentPageState extends State<ReportIncidentPage> {
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final List<XFile> _attachments = [];
  String _category = 'Fire';
  bool _detectingLocation = false;
  String _locationStatus = 'Detecting your location…';

  @override
  void initState() {
    super.initState();
    _detectLocation();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _detectLocation() async {
    if (!mounted) return;
    setState(() {
      _detectingLocation = true;
      _locationStatus = 'Detecting your location…';
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _locationStatus = 'Location is turned off. Enable it or enter your location manually.';
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _locationStatus = permission == LocationPermission.deniedForever
              ? 'Location permission is blocked. Enable it in Android Settings or enter the location manually.'
              : 'Location permission denied. You can enter the location manually.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      var locationText = '';
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final parts = <String?>[
            place.name,
            place.subLocality,
            place.locality,
            place.administrativeArea,
            place.postalCode,
          ]
              .whereType<String>()
              .map((part) => part.trim())
              .where((part) => part.isNotEmpty)
              .toSet()
              .toList();
          locationText = parts.join(', ');
        }
      } catch (_) {
        // Coordinates remain a valid automatic location if address lookup fails.
      }

      if (locationText.isEmpty) {
        locationText = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      }

      if (!mounted) return;
      // Do not overwrite text if the user already started entering a manual location.
      if (_locationController.text.trim().isEmpty) {
        _locationController.text = locationText;
      }
      setState(() {
        _locationStatus = 'Location detected. You can edit it if needed.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationStatus = 'Could not detect location. Check GPS/permission or enter it manually.';
      });
    } finally {
      if (mounted) setState(() => _detectingLocation = false);
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final file = await _imagePicker.pickMedia();
      if (file != null && mounted) {
        setState(() => _attachments.add(file));
      }
    } catch (_) {
      _showMediaError();
    }
  }

  Future<void> _takePhoto() async {
    try {
      final file = await _imagePicker.pickImage(source: ImageSource.camera);
      if (file != null && mounted) {
        setState(() => _attachments.add(file));
      }
    } catch (_) {
      _showMediaError();
    }
  }

  Future<void> _recordVideo() async {
    try {
      final file = await _imagePicker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 2),
      );
      if (file != null && mounted) {
        setState(() => _attachments.add(file));
      }
    } catch (_) {
      _showMediaError();
    }
  }

  void _showMediaError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open the camera or gallery. Please try again.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.localIssue
        ? ['Waterlogging', 'Pothole', 'Fallen Tree', 'Road Closure', 'Street Light', 'Other']
        : ['Fire', 'Medical Emergency', 'Accident', 'Flood', 'Other'];
    if (!categories.contains(_category)) _category = categories.first;

    return Scaffold(
      appBar: AppBar(title: Text(widget.localIssue ? 'Report Local Issue' : 'Report Incident')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Add photo or video evidence', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: _surface,
              border: Border.all(color: Colors.white12),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              OutlinedButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choose photo/video from gallery'),
              ),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Take photo'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _recordVideo,
                    icon: const Icon(Icons.videocam_outlined),
                    label: const Text('Record video'),
                  ),
                ),
              ]),
              if (_attachments.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('${_attachments.length} item(s) attached', style: const TextStyle(color: _muted, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                ...List.generate(_attachments.length, (index) {
                  final file = _attachments[index];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      file.path.toLowerCase().endsWith('.mp4') ||
                              file.path.toLowerCase().endsWith('.mov')
                          ? Icons.videocam_outlined
                          : Icons.image_outlined,
                      color: _muted,
                    ),
                    title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      tooltip: 'Remove attachment',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() => _attachments.removeAt(index)),
                    ),
                  );
                }),
              ],
            ]),
          ),
          const SizedBox(height: 22),
          const Text('What are you reporting?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 9),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: InputDecoration(
              filled: true,
              fillColor: _surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            ),
            items: categories.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
            onChanged: (value) => setState(() { if (value != null) _category = value; }),
          ),
          const SizedBox(height: 18),
          Row(children: [
            const Expanded(child: Text('Location', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            TextButton.icon(
              onPressed: _detectingLocation ? null : _detectLocation,
              icon: _detectingLocation
                  ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location_rounded, size: 17),
              label: const Text('Use GPS'),
            ),
          ]),
          const SizedBox(height: 2),
          TextField(
            controller: _locationController,
            decoration: InputDecoration(
              hintText: 'GPS location will appear here; you can edit it',
              helperText: _locationStatus,
              helperMaxLines: 3,
              prefixIcon: const Icon(Icons.location_on_outlined),
              filled: true,
              fillColor: _surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 18),
          const Text('Description', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 9),
          TextField(
            controller: _descriptionController,
            minLines: 4,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: 'Describe what happened and any important details…',
              filled: true,
              fillColor: _surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _submit,
            style: FilledButton.styleFrom(backgroundColor: _red, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
            icon: const Icon(Icons.send_rounded),
            label: const Text('Save Report', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 10),
          const Text('This prototype saves reports on this device session only. Media is selected locally; online upload/storage is not connected yet.', textAlign: TextAlign.center, style: TextStyle(color: _muted, fontSize: 11)),
        ],
      ),
    );
  }

  void _submit() {
    final description = _descriptionController.text.trim();
    final area = _locationController.text.trim().isEmpty ? 'Location not added' : _locationController.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add a short description first.')));
      return;
    }
    final isLocal = widget.localIssue;
    final result = LocalIssue(
      title: _category,
      area: area,
      category: isLocal ? 'Local' : 'Emergency',
      time: 'Just now',
      icon: isLocal ? Icons.location_on_rounded : Icons.warning_amber_rounded,
      color: isLocal ? const Color(0xFF74B6E8) : _red,
      description: description,
      mediaPaths: _attachments.map((file) => file.path).toList(),
    );
    Navigator.of(context).pop(result);
  }
}
