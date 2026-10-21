import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';

void main() => runApp(const SafeSphereApp());

const Color _background = Color(0xFF080D12);
const Color _surface = Color(0xFF151C23);
const Color _surface2 = Color(0xFF202A34);
const Color _red = Color(0xFFE6333B);
const Color _amber = Color(0xFFF5A623);
const Color _green = Color(0xFF2ECC71);
const Color _blue = Color(0xFF4DA3FF);
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

// ============================================================================
// DATA MODELS
// ============================================================================

class TimelineEvent {
  const TimelineEvent({
    required this.title,
    required this.subtitle,
    required this.time,
    this.isActive = false,
    this.isVerified = false,
  });

  final String title;
  final String subtitle;
  final String time;
  final bool isActive;
  final bool isVerified;
}

class EvidenceItem {
  const EvidenceItem({
    required this.type, // 'video' or 'photo'
    required this.label,
    required this.meta,
    required this.contributorZone, // 'Inside Zone' or 'Outside / Nearby'
    required this.timestamp,
    required this.color,
  });

  final String type;
  final String label;
  final String meta;
  final String contributorZone;
  final String timestamp;
  final Color color;
}

class LocalIssue {
  LocalIssue({
    required this.id,
    required this.title,
    required this.area,
    required this.category,
    required this.time,
    required this.timestamp,
    required this.icon,
    required this.color,
    this.description = '',
    this.mediaPaths = const [],
    this.contributorZone = 'Inside Affected Area',
    this.upvotes = 1,
    this.latitude = 12.9716,
    this.longitude = 77.5946,
    this.relayedViaMesh = false,
  });

  final String id;
  final String title;
  final String area;
  final String category;
  final String time;
  final DateTime timestamp;
  final IconData icon;
  final Color color;
  final String description;
  final List<String> mediaPaths;
  final String contributorZone;
  int upvotes;
  final double latitude;
  final double longitude;
  final bool relayedViaMesh;
}

class IncidentCluster {
  IncidentCluster({
    required this.id,
    required this.title,
    required this.category,
    required this.distance,
    required this.locationName,
    required this.status,
    required this.icon,
    required this.accentColor,
    required this.aiSummary,
    required this.aiOutlook,
    required this.confidenceScore,
    required this.timeline,
    required this.evidence,
    required this.reports,
  });

  final String id;
  final String title;
  final String category;
  final String distance;
  final String locationName;
  final String status;
  final IconData icon;
  final Color accentColor;
  String aiSummary;
  String aiOutlook;
  int confidenceScore;
  final List<TimelineEvent> timeline;
  final List<EvidenceItem> evidence;
  final List<LocalIssue> reports;
}

class EmergencyContact {
  EmergencyContact({
    required this.name,
    required this.relation,
    required this.phone,
    this.notified = false,
  });

  final String name;
  final String relation;
  final String phone;
  bool notified;
}

// ============================================================================
// MAIN HOME STATE
// ============================================================================

class SafeSphereHome extends StatefulWidget {
  const SafeSphereHome({super.key});

  @override
  State<SafeSphereHome> createState() => _SafeSphereHomeState();
}

class _SafeSphereHomeState extends State<SafeSphereHome> {
  int _selectedIndex = 0;
  int _detailTab = 0;
  int _selectedClusterIndex = 0;
  final PageController _pageController = PageController();

  // Offline & Mesh State
  bool _isOfflineMeshMode = false;
  int _meshPeersConnected = 4;
  int _queuedMeshPackets = 0;

  // Location & Filter State
  String _currentAreaName = 'Indiranagar, Bengaluru';
  String _localSearchQuery = '';
  String _selectedIssueCategory = 'All';
  bool _isCorrelatingAI = false;

  // Family Contacts for Emergency Notification
  final List<EmergencyContact> _familyContacts = [
    EmergencyContact(
      name: 'Aarav Sharma',
      relation: 'Brother',
      phone: '+91 98765 43210',
    ),
    EmergencyContact(
      name: 'Priya Nair',
      relation: 'Mother',
      phone: '+91 98765 12345',
    ),
    EmergencyContact(
      name: 'Rohan Verma',
      relation: 'Roommate',
      phone: '+91 91234 56789',
    ),
  ];

  // Correlated Emergency Incident Clusters
  late final List<IncidentCluster> _clusters = [
    IncidentCluster(
      id: 'cluster_fire_1',
      title: 'Fire at Sunrise Apartments',
      category: 'Fire',
      distance: '1.2 km away',
      locationName: 'Sunrise Apartments, 100ft Road, Indiranagar',
      status: 'LIVE / ONGOING',
      icon: Icons.local_fire_department_rounded,
      accentColor: const Color(0xFFFF5E3A),
      confidenceScore: 94,
      aiSummary: 'Correlated from 12 independent reports (8 inside perimeter, 4 outside). Smoke first spotted on the 4th floor East Wing at 14:18. Fire tenders arrived on-site within 9 minutes. No structural collapse reported; evacuation is actively underway.',
      aiOutlook: 'Fire containment expected within 30–45 minutes. Heavy smoke drift moving northeast toward 12th Main. Avoid 100ft Road service lanes to keep emergency corridors clear.',
      timeline: [
        const TimelineEvent(
          title: 'First smoke & alarm reported (East Wing, 4th Floor)',
          subtitle: 'Uploaded with 2 photos from inside building perimeter',
          time: '14:18 • 18m ago',
          isVerified: true,
        ),
        const TimelineEvent(
          title: 'Multiple exterior videos confirm flames on balcony',
          subtitle: '6 nearby witnesses corroborated GPS & visual angles',
          time: '14:22 • 14m ago',
          isVerified: true,
        ),
        const TimelineEvent(
          title: '2 Fire Brigade units arrived on scene',
          subtitle: 'Confirmed via community timestamped video',
          time: '14:27 • 9m ago',
          isVerified: true,
        ),
        const TimelineEvent(
          title: 'Evacuation in progress • Smoke subsiding on lower floors',
          subtitle: 'Gemini AI cross-verified latest 3 citizen updates',
          time: 'Just now',
          isActive: true,
          isVerified: true,
        ),
      ],
      evidence: [
        const EvidenceItem(
          type: 'video',
          label: 'East Wing Balcony',
          meta: '0:24',
          contributorZone: 'Inside Zone',
          timestamp: '14m ago',
          color: Color(0xFF6C4640),
        ),
        const EvidenceItem(
          type: 'photo',
          label: 'Fire Engine Arrival',
          meta: 'JPG',
          contributorZone: 'Outside / Nearby',
          timestamp: '9m ago',
          color: Color(0xFF3E5C47),
        ),
        const EvidenceItem(
          type: 'photo',
          label: 'Smoke Plume View',
          meta: 'JPG',
          contributorZone: 'Outside / Nearby',
          timestamp: '5m ago',
          color: Color(0xFF4B5868),
        ),
      ],
      reports: [
        LocalIssue(
          id: 'rep_1',
          title: 'Thick black smoke from 4th floor balcony',
          area: 'Sunrise Apts, Block B',
          category: 'Fire',
          time: '18m ago',
          timestamp: DateTime.now().subtract(const Duration(minutes: 18)),
          icon: Icons.local_fire_department_rounded,
          color: const Color(0xFFE65A47),
          description: 'Called 101 immediately. Security has triggered the building fire alarm and residents are taking the stairs.',
          contributorZone: 'Inside Affected Area',
          upvotes: 14,
          latitude: 12.9784,
          longitude: 77.6408,
        ),
        LocalIssue(
          id: 'rep_2',
          title: 'Two fire trucks entering 100ft Rd',
          area: '300m from Sunrise Apts',
          category: 'Fire',
          time: '9m ago',
          timestamp: DateTime.now().subtract(const Duration(minutes: 9)),
          icon: Icons.fire_truck_rounded,
          color: const Color(0xFFF5A623),
          description: 'Traffic is being diverted by police at the junction so ambulances can pass.',
          contributorZone: 'Outside / Nearby Witness',
          upvotes: 9,
          latitude: 12.9760,
          longitude: 77.6390,
        ),
      ],
    ),
    IncidentCluster(
      id: 'cluster_flood_2',
      title: 'Flash Flooding at Sony World Underpass',
      category: 'Flood',
      distance: '3.4 km away',
      locationName: '80ft Road, Koramangala 4th Block',
      status: 'ESCALATING',
      icon: Icons.flood_rounded,
      accentColor: const Color(0xFF4DA3FF),
      confidenceScore: 89,
      aiSummary: '7 reports over the last 35 minutes show water levels rising above 2.5 feet following intense localized downpour. Two vehicles stalled in the center lane.',
      aiOutlook: 'With light-to-moderate rain continuing for the next 45 minutes, waterlogging will likely persist for 2+ hours. Use Inner Ring Road flyover instead.',
      timeline: [
        const TimelineEvent(
          title: 'Drainage overflow reported near signal',
          subtitle: 'Initial civic report upgraded to flood warning',
          time: '35m ago',
          isVerified: true,
        ),
        const TimelineEvent(
          title: 'Water depth exceeds knee-level; 2 cars stalled',
          subtitle: 'Correlated from 5 commuter photos',
          time: '12m ago',
          isActive: true,
          isVerified: true,
        ),
      ],
      evidence: [
        const EvidenceItem(
          type: 'video',
          label: 'Underpass Water Level',
          meta: '0:15',
          contributorZone: 'Inside Zone',
          timestamp: '12m ago',
          color: Color(0xFF2E5473),
        ),
        const EvidenceItem(
          type: 'photo',
          label: 'Traffic Backed Up',
          meta: 'JPG',
          contributorZone: 'Outside / Nearby',
          timestamp: '6m ago',
          color: Color(0xFF465A65),
        ),
      ],
      reports: [
        LocalIssue(
          id: 'rep_3',
          title: 'Underpass completely submerged',
          area: 'Koramangala 80ft Rd',
          category: 'Flood',
          time: '12m ago',
          timestamp: DateTime.now().subtract(const Duration(minutes: 12)),
          icon: Icons.water_drop_rounded,
          color: const Color(0xFF4DA3FF),
          description: 'Two-wheelers cannot cross. Traffic police putting up barricades now.',
          contributorZone: 'Inside Affected Area',
          upvotes: 19,
          latitude: 12.9352,
          longitude: 77.6245,
        ),
      ],
    ),
  ];

  // Civic & Local Situational Issues
  final List<LocalIssue> _issues = [
    LocalIssue(
      id: 'iss_1',
      title: 'Waterlogging',
      area: 'Indiranagar 100ft Rd',
      category: 'Waterlogging',
      time: '45m ago',
      timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
      icon: Icons.water_drop_rounded,
      color: const Color(0xFF69B9EE),
      description: 'Ankle-deep water near Metro pillar 64 slowing down left-lane traffic.',
      upvotes: 11,
    ),
    LocalIssue(
      id: 'iss_2',
      title: 'Fallen Tree',
      area: 'Jayanagar 4th Block',
      category: 'Fallen Tree',
      time: '1h ago',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      icon: Icons.park_rounded,
      color: const Color(0xFFF0CC79),
      description: 'Large branch fell across one lane due to gusty winds. BBMP team notified.',
      upvotes: 8,
    ),
    LocalIssue(
      id: 'iss_3',
      title: 'Traffic Signal Fault',
      area: 'CMH Road Junction',
      category: 'Signal Fault',
      time: '2h ago',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      icon: Icons.traffic_rounded,
      color: const Color(0xFFF18A9B),
      description: 'Signal stuck on blinking amber during peak rain. Manual traffic control needed.',
      upvotes: 15,
    ),
    LocalIssue(
      id: 'iss_4',
      title: 'Deep Pothole',
      area: 'Koramangala 5th Block',
      category: 'Pothole',
      time: '3h ago',
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      icon: Icons.warning_amber_rounded,
      color: const Color(0xFFF49B89),
      description: 'Submerged pothole in the middle lane—dangerous for two-wheelers in rain.',
      upvotes: 22,
    ),
    LocalIssue(
      id: 'iss_5',
      title: 'Road Closure',
      area: 'Whitefield Main Rd',
      category: 'Road Closure',
      time: '5h ago',
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      icon: Icons.block_rounded,
      color: const Color(0xFF9E9BEF),
      description:
          'Stormwater drain repair work; diversion via ITPL back gate.',
      upvotes: 6,
    ),
  ];

  String _geminiCivicSituation =
      'Current Status: Multiple waterlogging and signal fault reports across Indiranagar & CMH Road correlate with the ongoing 26°C rain band.\n\nPossible Outlook (Next 3 Hours): Expect 25–35 min commuter delays along 100ft Road and CMH Junction. Submerged potholes pose high risk for two-wheelers until rainfall subsides around 18:30.';

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ============================================================================
  // INTERACTIVE WORKFLOWS
  // ============================================================================

  Future<void> _openReportForm({
    bool localIssue = false,
    String? prefilledCategory,
    bool fromPostCall = false,
  }) async {
    final LocalIssue? result = await Navigator.of(context).push<LocalIssue>(
      MaterialPageRoute(
        builder: (_) => ReportIncidentPage(
          localIssue: localIssue,
          initialCategory: prefilledCategory,
          isOfflineMesh: _isOfflineMeshMode,
          fromEmergencyCall: fromPostCall,
        ),
      ),
    );
    if (result == null || !mounted) return;

    setState(() {
      if (localIssue) {
        _issues.insert(0, result);
        _recalculateCivicOutlook();
        _selectedIndex = 2;
      } else {
        // Correlate with existing cluster or create a new one
        final matchingClusterIdx = _clusters.indexWhere(
          (c) => c.category.toLowerCase() == result.category.toLowerCase(),
        );
        if (matchingClusterIdx != -1) {
          final cluster = _clusters[matchingClusterIdx];
          cluster.reports.insert(0, result);
          cluster.timeline.add(
            TimelineEvent(
              title: 'New ${result.contributorZone} report correlated',
              subtitle: '"${result.description}" (${result.area})',
              time: 'Just now',
              isActive: true,
              isVerified: true,
            ),
          );
          if (result.mediaPaths.isNotEmpty) {
            cluster.evidence.insert(
              0,
              EvidenceItem(
                type: result.mediaPaths.first.toLowerCase().endsWith('.mp4')
                    ? 'video'
                    : 'photo',
                label: result.title,
                meta: '${result.mediaPaths.length} file(s)',
                contributorZone: result.contributorZone.contains('Inside')
                    ? 'Inside Zone'
                    : 'Outside / Nearby',
                timestamp: 'Just now',
                color: const Color(0xFF5A4E6D),
              ),
            );
          }
          cluster.confidenceScore = (cluster.confidenceScore + 2).clamp(0, 99);
          _selectedClusterIndex = matchingClusterIdx;
        } else {
          _clusters.insert(
            0,
            IncidentCluster(
              id: 'cluster_${DateTime.now().millisecondsSinceEpoch}',
              title: '${result.title} at ${result.area}',
              category: result.category,
              distance: '0.2 km away',
              locationName: result.area,
              status: 'NEW REPORT • VERIFYING',
              icon: result.icon,
              accentColor: _red,
              confidenceScore: 76,
              aiSummary:
                  'Initial report logged by ${result.contributorZone}. "${result.description}". Gemini AI is monitoring nearby contributions to cross-verify severity.',
              aiOutlook: 'Emergency alert broadcast to nearby SafeSphere nodes within 2 km. Awaiting secondary visual confirmation.',
              timeline: [
                TimelineEvent(
                  title: 'Incident reported (${result.contributorZone})',
                  subtitle: result.description,
                  time: 'Just now',
                  isActive: true,
                  isVerified: false,
                ),
              ],
              evidence: result.mediaPaths.isNotEmpty
                  ? [
                      EvidenceItem(
                        type: 'photo',
                        label: result.title,
                        meta: '${result.mediaPaths.length} attached',
                        contributorZone: result.contributorZone,
                        timestamp: 'Just now',
                        color: const Color(0xFF6B3FA0),
                      ),
                    ]
                  : [],
              reports: [result],
            ),
          );
          _selectedClusterIndex = 0;
        }
        if (_isOfflineMeshMode) {
          _queuedMeshPackets++;
        }
        _selectedIndex = 1;
      }
      _pageController.jumpToPage(_selectedIndex);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _isOfflineMeshMode
            ? const Color(0xFF7B52AB)
            : _green.withValues(alpha: 0.9),
        content: Text(
          _isOfflineMeshMode
              ? 'Offline Mode: Report encrypted & relayed to $_meshPeersConnected nearby Bluetooth mesh peers!'
              : 'Report correlated with Gemini AI & published to live timeline.',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _recalculateCivicOutlook() {
    final total = _issues.length;
    final latest = _issues.first;
    _geminiCivicSituation =
        'Current Status: $total active civic reports correlated in $_currentAreaName. Latest report: ${latest.title} at ${latest.area} ("${latest.description}").\n\nPossible Outlook (Next 3 Hours): Gemini API correlates elevated waterlogging & obstruction clusters with ongoing rainfall. Commuters near ${latest.area} should expect 20–30 min slowdowns; nearby users within 3 km have been notified.';
  }

  Future<void> _triggerGeminiCorrelation() async {
    setState(() => _isCorrelatingAI = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _recalculateCivicOutlook();
      if (_clusters.isNotEmpty) {
        final c = _clusters[_selectedClusterIndex];
        c.confidenceScore = (c.confidenceScore + 1).clamp(70, 99);
        c.aiSummary =
            'Updated (${TimeOfDay.now().format(context)}): Gemini correlated ${c.reports.length + 10} reports & ${c.evidence.length} media files at ${c.locationName}. Cross-checked timestamps confirm emergency response is active on site.';
      }
      _isCorrelatingAI = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Gemini AI re-correlated all timestamps, locations, and media evidence.',
        ),
      ),
    );
  }

  void _startEmergencyCall(
    String serviceName,
    String number,
    String defaultCategory,
  ) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SimulatedCallDialog(
        serviceName: serviceName,
        number: number,
        locationName: _currentAreaName,
        onCallEnded: () {
          Navigator.of(ctx).pop();
          _showPostCallPrompt(serviceName, defaultCategory);
        },
      ),
    );
  }

  void _showPostCallPrompt(String serviceName, String defaultCategory) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surface,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: _green,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Call to $serviceName completed',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Now that emergency services have been contacted, capture photos/videos with your GPS & timestamp to help responders and warn nearby citizens.',
                style: TextStyle(color: _muted, height: 1.4),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _openReportForm(
                      prefilledCategory: defaultCategory,
                      fromPostCall: true,
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _red,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text(
                    'Capture Evidence & Report Incident',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _broadcastFamilyAlert();
                  },
                  icon: const Icon(Icons.family_restroom_rounded),
                  label: const Text('Notify Family Contacts Now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmergencyOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surface,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Emergency Helplines (Priority 1)',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Tap any helpline to initiate a priority emergency call with your GPS ($_currentAreaName).',
                style: const TextStyle(color: _muted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _helplineRow(
                ctx,
                Icons.emergency_rounded,
                'National Emergency Response',
                '112',
                'Accident',
              ),
              _helplineRow(
                ctx,
                Icons.local_fire_department_rounded,
                'Fire & Rescue Service',
                '101',
                'Fire',
              ),
              _helplineRow(
                ctx,
                Icons.medical_services_rounded,
                'Medical / Ambulance',
                '108',
                'Medical Emergency',
              ),
              _helplineRow(
                ctx,
                Icons.flood_rounded,
                'Disaster Management (NDRF)',
                '1078',
                'Flood',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _helplineRow(
    BuildContext sheetContext,
    IconData icon,
    String title,
    String number,
    String category,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(sheetContext).pop();
          _startEmergencyCall(title, number, category);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: _surface2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Icon(icon, color: _red),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _red,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.call_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      number,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _broadcastFamilyAlert() {
    setState(() {
      for (final c in _familyContacts) {
        c.notified = true;
      }
      if (_isOfflineMeshMode) _queuedMeshPackets += _familyContacts.length;
    });
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surface,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _isOfflineMeshMode
                        ? Icons.bluetooth_connected_rounded
                        : Icons.notifications_active_rounded,
                    color: _isOfflineMeshMode ? _blue : _green,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isOfflineMeshMode
                          ? 'SOS Queued via Bluetooth Mesh'
                          : 'Family & Nearby Users Notified',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _isOfflineMeshMode
                    ? 'Your GPS ($_currentAreaName), timestamp, and safety status are hopping across $_meshPeersConnected nearby devices until a gateway node with internet is reached.'
                    : 'Your live location ($_currentAreaName) and incident alert have been sent to your emergency contacts and SafeSphere users within 2 km.',
                style: const TextStyle(
                  color: _muted,
                  height: 1.4,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              ..._familyContacts.map(
                (c) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: _surface2,
                    child: Icon(Icons.person_rounded, color: _text),
                  ),
                  title: Text(
                    '${c.name} (${c.relation})',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    c.phone,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _green.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _isOfflineMeshMode ? 'Relayed (Mesh)' : 'Delivered',
                      style: const TextStyle(
                        color: _green,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOfflineMeshConsole() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surface,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.hub_rounded, color: _blue, size: 26),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Offline Mesh & Google Nearby Relay',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Switch(
                      value: _isOfflineMeshMode,
                      activeThumbColor: _blue,
                      onChanged: (val) {
                        setState(() {
                          _isOfflineMeshMode = val;
                          if (!val && _queuedMeshPackets > 0) {
                            _queuedMeshPackets = 0;
                          }
                        });
                        setSheetState(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'When cellular & internet networks overload during earthquakes, floods, or fires, SafeSphere uses Bluetooth Low Energy + Wi-Fi Direct (Google Nearby protocol) to hop emergency packets device-to-device.',
                  style: TextStyle(color: _muted, fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _surface2,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _meshStatRow(
                        'Network Mode',
                        _isOfflineMeshMode
                            ? 'Offline P2P Mesh Active'
                            : 'Online (Cloud + Mesh Standby)',
                      ),
                      const Divider(height: 18, color: Colors.white10),
                      _meshStatRow(
                        'Nearby Peer Nodes in Range',
                        '$_meshPeersConnected devices (within 120m)',
                      ),
                      const Divider(height: 18, color: Colors.white10),
                      _meshStatRow(
                        'Packets Relayed / Queued',
                        '$_queuedMeshPackets emergency payloads',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(
                            () => _meshPeersConnected =
                                (_meshPeersConnected % 9) + 3,
                          );
                          setSheetState(() {});
                        },
                        icon: const Icon(Icons.radar_rounded, size: 18),
                        label: const Text('Scan Peers'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _broadcastFamilyAlert();
                        },
                        style: FilledButton.styleFrom(backgroundColor: _blue),
                        icon: const Icon(Icons.cell_tower_rounded, size: 18),
                        label: const Text('Relay SOS Beacon'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _meshStatRow(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
      Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
      ),
    ],
  );

  // ============================================================================
  // SCAFFOLD & NAVIGATION
  // ============================================================================

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
        child: Column(
          children: [
            if (_isOfflineMeshMode)
              GestureDetector(
                onTap: _showOfflineMeshConsole,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: const Color(0xFF1E3A5F),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.bluetooth_Searching_rounded,
                        size: 16,
                        color: _blue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'OFFLINE MESH ACTIVE • $_meshPeersConnected nearby nodes relaying packets',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const Text(
                        'Manage',
                        style: TextStyle(
                          fontSize: 11,
                          color: _blue,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) =>
                    setState(() => _selectedIndex = index),
                children: pages,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 72,
        backgroundColor: const Color(0xFF0D1319),
        indicatorColor: _red.withValues(alpha: 0.18),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.call_rounded),
            selectedIcon: Icon(Icons.call_rounded, color: _red),
            label: 'Emergency',
          ),
          NavigationDestination(
            icon: Icon(Icons.hub_outlined),
            selectedIcon: Icon(Icons.hub_rounded, color: _red),
            label: 'Correlated Intel',
          ),
          NavigationDestination(
            icon: Icon(Icons.radar_rounded),
            selectedIcon: Icon(Icons.radar_rounded, color: _red),
            label: 'Local Awareness',
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // PAGE 1: EMERGENCY HELPLINE, OFFLINE MESH & FAMILY NOTIFICATION
  // ============================================================================

  Widget _buildEmergencyPage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      children: [
        // Top Header with Location & Mesh/Settings Buttons
        Row(
          children: [
            const Icon(Icons.location_on_rounded, color: _red, size: 23),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: _changePreferredLocation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Preferred / Current Location',
                      style: TextStyle(color: _muted, fontSize: 11.5),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _currentAreaName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: _muted,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            _roundButton(
              _isOfflineMeshMode
                  ? Icons.bluetooth_connected_rounded
                  : Icons.wifi_tethering_rounded,
              _showOfflineMeshConsole,
              activeColor: _isOfflineMeshMode ? _blue : null,
            ),
            const SizedBox(width: 8),
            _roundButton(Icons.family_restroom_rounded, _broadcastFamilyAlert),
          ],
        ),
        const SizedBox(height: 18),

        // Priority 1: Emergency Helpline Card
        Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE51D25), Color(0xFF7A1419)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: _red.withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _badge('PRIORITY 1 • LIFE SAFETY', Colors.black38),
                  _badge('GPS AUTO-SHARED', Colors.white24),
                ],
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => _startEmergencyCall(
                  'National Emergency Response',
                  '112',
                  'Accident',
                ),
                child: Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.45),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.call_rounded,
                    size: 38,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Emergency Helpline',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Quick access to the right helpline during panic.\nAfter the call, you will be prompted to share evidence.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  height: 1.35,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _showEmergencyOptions,
                  icon: const Icon(Icons.phone_in_talk_rounded),
                  label: const Text(
                    'Tap to Call Emergency Services',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3841),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _emergencyShortcut(
                      Icons.local_police_rounded,
                      'Police / SOS',
                      '112',
                      () => _startEmergencyCall(
                        'Police / National SOS',
                        '112',
                        'Accident',
                      ),
                    ),
                  ),
                  Expanded(
                    child: _emergencyShortcut(
                      Icons.local_fire_department_rounded,
                      'Fire Brigade',
                      '101',
                      () => _startEmergencyCall('Fire & Rescue', '101', 'Fire'),
                    ),
                  ),
                  Expanded(
                    child: _emergencyShortcut(
                      Icons.medical_services_rounded,
                      'Ambulance',
                      '108',
                      () => _startEmergencyCall(
                        'Medical Ambulance',
                        '108',
                        'Medical Emergency',
                      ),
                    ),
                  ),
                  Expanded(
                    child: _emergencyShortcut(
                      Icons.flood_rounded,
                      'Disaster',
                      '1078',
                      () => _startEmergencyCall(
                        'Disaster Relief (NDRF)',
                        '1078',
                        'Flood',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Priority 2: Post-Call Reporting & Public Contributions
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.camera_enhance_rounded,
                    color: _red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Emergency Reporting & Public Contributions',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'People inside or outside the affected area can upload photos, videos, GPS, and timestamps to build a verified incident timeline.',
                style: TextStyle(color: _muted, fontSize: 12, height: 1.35),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _openReportForm(),
                      icon: const Icon(Icons.add_a_photo_rounded, size: 18),
                      label: const Text(
                        'Report Incident',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _broadcastFamilyAlert,
                      icon: const Icon(
                        Icons.notifications_active_outlined,
                        size: 18,
                      ),
                      label: const Text(
                        'Notify Family',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Offline Mesh Communication Status Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isOfflineMeshMode
                  ? _blue.withValues(alpha: 0.5)
                  : Colors.white10,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: _blue.withValues(alpha: 0.16),
                    child: const Icon(
                      Icons.bluetooth_connected_rounded,
                      color: _blue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Offline Mesh & Nearby Device Relay',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isOfflineMeshMode
                              ? 'Active • Relaying via $_meshPeersConnected nearby Bluetooth nodes'
                              : 'Standby • Auto-activates if mobile network drops',
                          style: const TextStyle(color: _muted, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isOfflineMeshMode,
                    activeThumbColor: _blue,
                    onChanged: (v) => setState(() => _isOfflineMeshMode = v),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Live Correlated Incidents Preview
        _sectionHeader('Active Correlated Emergencies', 'View Timeline', () {
          setState(() => _selectedIndex = 1);
          _pageController.animateToPage(
            1,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        }),
        const SizedBox(height: 8),
        ..._clusters.map(
          (cluster) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _smallInfoCard(
              cluster.icon,
              cluster.title,
              '${cluster.distance} • ${cluster.reports.length + 10} correlated reports • ${cluster.confidenceScore}% AI verified',
              cluster.accentColor,
              () {
                setState(() {
                  _selectedClusterIndex = _clusters.indexOf(cluster);
                  _selectedIndex = 1;
                });
                _pageController.animateToPage(
                  1,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // PAGE 2: EVIDENCE CORRELATION, INCIDENT TIMELINE & PUBLIC AWARENESS
  // ============================================================================

  Widget _buildReportsPage() {
    final cluster = _clusters[_selectedClusterIndex];

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Correlated Incidents',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Evidence grouped by location, timestamp & AI analysis',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            _roundButton(
              Icons.auto_awesome_rounded,
              _triggerGeminiCorrelation,
              activeColor: _blue,
            ),
            const SizedBox(width: 8),
            _roundButton(Icons.add_rounded, () => _openReportForm()),
          ],
        ),
        const SizedBox(height: 14),

        // Incident Selector Chips (Switch between active incidents)
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _clusters.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final item = _clusters[index];
              final isSelected = index == _selectedClusterIndex;
              return ChoiceChip(
                selected: isSelected,
                selectedColor: item.accentColor.withValues(alpha: 0.25),
                backgroundColor: _surface,
                label: Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: isSelected ? Colors.white : _muted,
                  ),
                ),
                avatar: Icon(item.icon, size: 16, color: item.accentColor),
                onSelected: (_) =>
                    setState(() => _selectedClusterIndex = index),
              );
            },
          ),
        ),
        const SizedBox(height: 14),

        // Hero Incident Card
        Container(
          height: 230,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                cluster.accentColor.withValues(alpha: 0.45),
                const Color(0xFF1F2730),
                const Color(0xFF11161B),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -10,
                top: 18,
                child: Icon(
                  Icons.apartment_rounded,
                  size: 175,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              Positioned(
                right: 22,
                top: 34,
                child: Icon(
                  cluster.icon,
                  size: 88,
                  color: cluster.accentColor.withValues(alpha: 0.78),
                ),
              ),
              Positioned(
                left: 14,
                top: 14,
                child: _badge('●  ${cluster.status}', _red),
              ),
              Positioned(
                right: 14,
                top: 14,
                child: _badge(
                  'AI Confidence: ${cluster.confidenceScore}%',
                  Colors.black54,
                ),
              ),
              Positioned(
                left: 17,
                right: 17,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cluster.title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 15,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${cluster.locationName} • ${cluster.distance}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _badge(
                          '${cluster.reports.length + 10} Correlated Reports',
                          Colors.white12,
                        ),
                        const SizedBox(width: 6),
                        _badge(
                          'Inside & Outside Zone Verified',
                          Colors.white12,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 4 Sub-tabs: Overview, Timeline, Reports, Map
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: _surface2,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: List.generate(4, (index) {
              const labels = ['Overview', 'Timeline', 'Contributions', 'Map'];
              final selected = _detailTab == index;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _detailTab = index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFE9EDF1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      labels[index],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: selected ? const Color(0xFF17202A) : _text,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 14),

        // TAB 0: OVERVIEW (GEMINI CORRELATION + PUBLIC AWARENESS + EVIDENCE)
        if (_detailTab == 0) ...[
          _panelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 19),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Gemini Correlated Situation & Outlook',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                    _badge(
                      'VERIFIED INTEL',
                      const Color(0xFFB2C9FF),
                      darkText: true,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_isCorrelatingAI)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  const Text(
                    'WHAT IS HAPPENING NOW:',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF4A5868),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cluster.aiSummary,
                    style: const TextStyle(
                      height: 1.45,
                      color: Color(0xFF18212A),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'EXPECTED OUTLOOK & SAFETY GUIDANCE:',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF9C2B2B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cluster.aiOutlook,
                    style: const TextStyle(
                      height: 1.4,
                      color: Color(0xFF18212A),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Anti-misinformation check: Cross-verified via GPS & EXIF',
                      style: TextStyle(color: Color(0xFF5A6875), fontSize: 11),
                    ),
                    TextButton.icon(
                      onPressed: _triggerGeminiCorrelation,
                      icon: const Icon(Icons.refresh_rounded, size: 15),
                      label: const Text(
                        'Re-analyze',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _panelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Correlated Photo & Video Evidence',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${cluster.evidence.length} files',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF5A6875),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: cluster.evidence.take(3).map((ev) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _evidenceTile(
                          ev.type == 'video'
                              ? Icons.play_circle_fill_rounded
                              : Icons.image_rounded,
                          ev.label,
                          ev.contributorZone,
                          ev.timestamp,
                          ev.color,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openReportForm(
                          prefilledCategory: cluster.category,
                        ),
                        icon: const Icon(Icons.upload_file_rounded, size: 17),
                        label: const Text('Contribute Photo/Video'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ]
        // TAB 1: CHRONOLOGICAL INCIDENT TIMELINE
        else if (_detailTab == 1) ...[
          _panelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Evolving Incident Timeline',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    _badge(
                      'CHRONOLOGICAL',
                      const Color(0xFFD5E3F0),
                      darkText: true,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Ordered automatically by report timestamps to show how the emergency developed.',
                  style: TextStyle(color: Color(0xFF5A6875), fontSize: 12),
                ),
                const SizedBox(height: 16),
                ...cluster.timeline.map(
                  (t) => _timelineItem(
                    t.title,
                    t.subtitle,
                    t.time,
                    t.isActive,
                    t.isVerified,
                  ),
                ),
              ],
            ),
          ),
        ]
        // TAB 2: PUBLIC CONTRIBUTIONS (INSIDE & OUTSIDE AFFECTED AREA)
        else if (_detailTab == 2) ...[
          ...cluster.reports.map((report) => _reportRow(report)),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () =>
                _openReportForm(prefilledCategory: cluster.category),
            style: FilledButton.styleFrom(
              backgroundColor: _red,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.add_photo_alternate_rounded),
            label: const Text(
              'Add Public Contribution (Inside or Outside Zone)',
            ),
          ),
        ]
        // TAB 3: INTERACTIVE INCIDENT RADAR MAP
        else ...[
          _panelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Geospatial Evidence Cluster Map',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    _badge(
                      '${cluster.reports.length + 4} GPS Pins',
                      const Color(0xFFDCE7F3),
                      darkText: true,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  height: 210,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF121C26),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black26),
                  ),
                  child: Stack(
                    children: [
                      // Simulated Radar Grid
                      Center(
                        child: Container(
                          width: 170,
                          height: 170,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _red.withValues(alpha: 0.25),
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Container(
                          width: 95,
                          height: 95,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _red.withValues(alpha: 0.15),
                            border: Border.all(
                              color: _red.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                      // Epicenter Pin
                      const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              color: _red,
                              size: 34,
                            ),
                            Text(
                              'EPICENTER (Inside Zone)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Outside Witness Pins
                      const Positioned(
                        left: 38,
                        top: 42,
                        child: Column(
                          children: [
                            Icon(
                              Icons.videocam_rounded,
                              color: _amber,
                              size: 20,
                            ),
                            Text(
                              'Witness (200m)',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Positioned(
                        right: 42,
                        bottom: 38,
                        child: Column(
                          children: [
                            Icon(
                              Icons.camera_alt_rounded,
                              color: _blue,
                              size: 20,
                            ),
                            Text(
                              'Witness (450m)',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Epicenter: ${cluster.locationName} • Red zone indicates reports from inside the perimeter; Amber/Blue pins show external witness uploads.',
                  style: const TextStyle(
                    color: Color(0xFF4A5868),
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ============================================================================
  // PAGE 3: LOCAL SITUATIONAL AWARENESS (WEATHER, CIVIC ISSUES & GEMINI OUTLOOK)
  // ============================================================================

  Widget _buildLocalAwarenessPage() {
    const categories = [
      'All',
      'Waterlogging',
      'Pothole',
      'Fallen Tree',
      'Road Closure',
      'Signal Fault',
    ];
    final filteredIssues = _issues.where((issue) {
      final matchesCategory =
          _selectedIssueCategory == 'All' ||
          issue.category.toLowerCase() ==
              _selectedIssueCategory.toLowerCase() ||
          issue.title.toLowerCase().contains(
            _selectedIssueCategory.toLowerCase(),
          );
      final matchesQuery =
          _localSearchQuery.trim().isEmpty ||
          issue.title.toLowerCase().contains(_localSearchQuery.toLowerCase()) ||
          issue.area.toLowerCase().contains(_localSearchQuery.toLowerCase()) ||
          issue.description.toLowerCase().contains(
            _localSearchQuery.toLowerCase(),
          );
      return matchesCategory && matchesQuery;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      children: [
        // Search Bar + Preferred Location Selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFF163A58), Color(0xFF101F30)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: Colors.white70),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  onChanged: (val) => setState(() => _localSearchQuery = val),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search area or issue in $_currentAreaName…',
                    hintStyle: const TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              _roundButton(
                Icons.edit_location_alt_rounded,
                _changePreferredLocation,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Live Weather & Disaster API Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [Color(0xFF3B7397), Color(0xFF1E3950)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.thunderstorm_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '26°C • Heavy Rain Band',
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Preferred Area: $_currentAreaName',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _badge('IMD YELLOW ALERT', _amber, darkText: true),
                      const SizedBox(height: 5),
                      const Text(
                        'Rainfall: 18mm/hr',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Gemini AI Evolving Local Situation & Outlook Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _blue.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: _blue,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Gemini Evolving Local Situation & Outlook',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Re-correlate with Gemini API',
                    onPressed: _triggerGeminiCorrelation,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: _blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _geminiCivicSituation,
                style: const TextStyle(
                  color: Color(0xFFD8DEE5),
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _badge(
                    '${_issues.length} Civic Reports Correlated',
                    _surface2,
                  ),
                  const SizedBox(width: 8),
                  _badge('Area Notifications Active', _surface2),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Official Weather & Traffic Alerts
        _alertRow(
          Icons.warning_rounded,
          const Color(0xFFE95656),
          'Flash Waterlogging Advisory',
          'Low-lying roads in Indiranagar & Koramangala accumulating water rapidly',
          'Tap for safety guidance',
        ),
        _alertRow(
          Icons.traffic_rounded,
          const Color(0xFFE9BC48),
          'Civic Infrastructure & Traffic Disruption',
          'Fallen tree & signal fault causing 25 min delay on CMH-100ft corridor',
          'Tap for alternate routes',
        ),
        const SizedBox(height: 16),

        // Local Civic Issues Header + Report Button
        Row(
          children: [
            const Expanded(
              child: Text(
                'Reported Local Issues',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ),
            FilledButton.icon(
              onPressed: () => _openReportForm(localIssue: true),
              icon: const Icon(Icons.add_location_alt_outlined, size: 16),
              label: const Text(
                'Report Issue',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: const Color(0xFF08121E),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Category Filter Chips
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 7),
            itemBuilder: (context, idx) {
              final cat = categories[idx];
              final selected = _selectedIssueCategory == cat;
              return ChoiceChip(
                selected: selected,
                label: Text(cat, style: const TextStyle(fontSize: 12)),
                onSelected: (_) => setState(() => _selectedIssueCategory = cat),
              );
            },
          ),
        ),
        const SizedBox(height: 10),

        // Filtered Issues List
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: filteredIssues.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'No local issues match your filter.',
                      style: TextStyle(color: _muted),
                    ),
                  ),
                )
              : Column(
                  children: filteredIssues
                      .map((issue) => _issueRow(issue))
                      .toList(),
                ),
        ),
      ],
    );
  }

  void _changePreferredLocation() {
    final controller = TextEditingController(text: _currentAreaName);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('Preferred Area for Updates'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'City / Neighborhood',
            hintText: 'e.g., Indiranagar, Bengaluru',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _currentAreaName = controller.text.trim();
                  _recalculateCivicOutlook();
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Update Area'),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // REUSABLE UI HELPERS
  // ============================================================================

  Widget _emergencyShortcut(
    IconData icon,
    String title,
    String number,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white.withValues(alpha: 0.16),
              child: Icon(icon, size: 20, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10.5, color: Colors.white),
            ),
            const SizedBox(height: 2),
            Text(
              number,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundButton(IconData icon, VoidCallback onTap, {Color? activeColor}) {
    return Material(
      color: activeColor != null
          ? activeColor.withValues(alpha: 0.22)
          : _surface2,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 20, color: activeColor ?? _text),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, String action, VoidCallback onTap) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      TextButton(onPressed: onTap, child: Text(action)),
    ],
  );

  Widget _smallInfoCard(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.18),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(color: _muted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _muted),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color, {bool darkText = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 0.2,
            color: darkText ? const Color(0xFF14202B) : Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  Widget _panelCard({required Widget child}) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F3F6),
      borderRadius: BorderRadius.circular(20),
    ),
    child: DefaultTextStyle(
      style: const TextStyle(color: Color(0xFF18212A)),
      child: IconTheme(
        data: const IconThemeData(color: Color(0xFF18212A)),
        child: child,
      ),
    ),
  );

  Widget _evidenceTile(
    IconData icon,
    String label,
    String zone,
    String time,
    Color color,
  ) => Container(
    height: 92,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Stack(
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              zone,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: Icon(icon, size: 28, color: Colors.white70),
        ),
        Align(
          alignment: Alignment.bottomLeft,
          child: Text(
            '$label • $time',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _timelineItem(
    String title,
    String subtitle,
    String time,
    bool active,
    bool verified,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          active
              ? Icons.radio_button_checked_rounded
              : Icons.check_circle_rounded,
          color: active ? _red : _green,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF4A5868), fontSize: 12),
              ),
              const SizedBox(height: 3),
              Text(
                verified ? '$time • GPS & Timestamp Verified' : time,
                style: const TextStyle(
                  color: Color(0xFF6C7A89),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _reportRow(LocalIssue report) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundColor: report.color.withValues(alpha: 0.18),
              child: Icon(report.icon, color: report.color, size: 20),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${report.area} • ${report.time} • ${report.contributorZone}',
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (report.relayedViaMesh)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.bluetooth_connected_rounded,
                  size: 16,
                  color: _blue,
                ),
              ),
          ],
        ),
        if (report.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            report.description,
            style: const TextStyle(color: Color(0xFFD0D7DE), fontSize: 12.5),
          ),
        ],
      ],
    ),
  );

  Widget _alertRow(
    IconData icon,
    Color color,
    String title,
    String subtitle,
    String action,
  ) => InkWell(
    onTap: () => _showInfo(
      title,
      '$subtitle.\n\nGemini API has correlated this alert with local citizen reports and notified commuters within 3 km.',
    ),
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF7E282D),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF394552),
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  action,
                  style: const TextStyle(
                    color: Color(0xFF596572),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF596572)),
        ],
      ),
    ),
  );

  Widget _issueRow(LocalIssue issue) => InkWell(
    onTap: () => _showInfo(
      '${issue.title} (${issue.area})',
      'Reported ${issue.time}\n\n"${issue.description}"\n\nConfirmed by ${issue.upvotes} people in the area.',
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: issue.color.withValues(alpha: 0.18),
            child: Icon(issue.icon, color: issue.color, size: 19),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  issue.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${issue.area} • ${issue.time}',
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
                if (issue.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    issue.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFB8C4D0),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => setState(() => issue.upvotes++),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: issue.color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.thumb_up_alt_rounded,
                    color: issue.color,
                    size: 15,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${issue.upvotes}',
                    style: TextStyle(
                      color: issue.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  void _showInfo(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surface,
        title: Text(title),
        content: Text(message, style: const TextStyle(height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SIMULATED EMERGENCY CALL DIALOG (PRIORITY 1 -> LEADS TO REPORTING)
// ============================================================================

class _SimulatedCallDialog extends StatefulWidget {
  const _SimulatedCallDialog({
    required this.serviceName,
    required this.number,
    required this.locationName,
    required this.onCallEnded,
  });

  final String serviceName;
  final String number;
  final String locationName;
  final VoidCallback onCallEnded;

  @override
  State<_SimulatedCallDialog> createState() => _SimulatedCallDialogState();
}

class _SimulatedCallDialogState extends State<_SimulatedCallDialog> {
  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mins = (_seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_seconds % 60).toString().padLeft(2, '0');
    return Dialog(
      backgroundColor: const Color(0xFF121820),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'EMERGENCY DISPATCH CONNECTED',
                style: TextStyle(
                  color: _red,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 18),
            CircleAvatar(
              radius: 36,
              backgroundColor: _red.withValues(alpha: 0.2),
              child: const Icon(
                Icons.phone_in_talk_rounded,
                color: _red,
                size: 36,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.serviceName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              'Helpline ${widget.number} • $mins:$secs',
              style: const TextStyle(color: _muted, fontSize: 14),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _surface2,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.my_location_rounded,
                    color: _green,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Live GPS telemetry shared: ${widget.locationName}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: widget.onCallEnded,
                style: FilledButton.styleFrom(
                  backgroundColor: _red,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.call_end_rounded),
                label: const Text(
                  'End Call & Proceed to Report Evidence',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// REPORT INCIDENT / LOCAL ISSUE PAGE (WITH ZONE, TIMESTAMP & OFFLINE SUPPORT)
// ============================================================================

class ReportIncidentPage extends StatefulWidget {
  const ReportIncidentPage({
    super.key,
    required this.localIssue,
    this.initialCategory,
    this.isOfflineMesh = false,
    this.fromEmergencyCall = false,
  });

  final bool localIssue;
  final String? initialCategory;
  final bool isOfflineMesh;
  final bool fromEmergencyCall;

  @override
  State<ReportIncidentPage> createState() => _ReportIncidentPageState();
}

class _ReportIncidentPageState extends State<ReportIncidentPage> {
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final List<XFile> _attachments = [];

  late String _category;
  String _contributorZone = 'Inside Affected Area';
  bool _notifyNearbyAndFamily = true;
  bool _detectingLocation = false;
  String _locationStatus = 'Detecting your GPS coordinates & address…';
  late final DateTime _capturedTimestamp = DateTime.now();

  @override
  void initState() {
    super.initState();
    _category =
        widget.initialCategory ?? (widget.localIssue ? 'Waterlogging' : 'Fire');
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
          _locationStatus =
              'Location is turned off. Enable GPS or enter location manually.';
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
          _locationStatus =
              'Location permission denied. Enter location manually.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
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
          final parts =
              <String?>[
                    place.name,
                    place.subLocality,
                    place.locality,
                    place.administrativeArea,
                  ]
                  .whereType<String>()
                  .map((part) => part.trim())
                  .where((part) => part.isNotEmpty)
                  .toSet()
                  .toList();
          locationText = parts.join(', ');
        }
      } catch (_) {}

      if (locationText.isEmpty) {
        locationText =
            '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      }

      if (!mounted) return;
      if (_locationController.text.trim().isEmpty) {
        _locationController.text = locationText;
      }
      setState(() {
        _locationStatus = 'GPS coordinates locked & verified for correlation.';
      });
    } catch (_) {
      if (!mounted) return;
      if (_locationController.text.trim().isEmpty) {
        _locationController.text = '100ft Road, Indiranagar (Simulated GPS)';
      }
      setState(() {
        _locationStatus =
            'Using fallback location coordinates. You can edit above.';
      });
    } finally {
      if (mounted) setState(() => _detectingLocation = false);
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final file = await _imagePicker.pickMedia();
      if (file != null && mounted) setState(() => _attachments.add(file));
    } catch (_) {
      _showMediaError();
    }
  }

  Future<void> _takePhoto() async {
    try {
      final file = await _imagePicker.pickImage(source: ImageSource.camera);
      if (file != null && mounted) setState(() => _attachments.add(file));
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
      if (file != null && mounted) setState(() => _attachments.add(file));
    } catch (_) {
      _showMediaError();
    }
  }

  void _showMediaError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Camera/Gallery unavailable on this simulator. Attached demo metadata.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.localIssue
        ? [
            'Waterlogging',
            'Pothole',
            'Fallen Tree',
            'Road Closure',
            'Signal Fault',
            'Street Light',
            'Other',
          ]
        : [
            'Fire',
            'Flood',
            'Earthquake',
            'Building Collapse',
            'Medical Emergency',
            'Accident',
            'Other',
          ];
    if (!categories.contains(_category)) _category = categories.first;

    final formattedTime =
        '${_capturedTimestamp.hour.toString().padLeft(2, '0')}:${_capturedTimestamp.minute.toString().padLeft(2, '0')}:${_capturedTimestamp.second.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.localIssue
              ? 'Report Local Civic Issue'
              : 'Report Emergency Evidence',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.fromEmergencyCall)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _green.withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_rounded, color: _green, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Emergency call logged. Your photos, video, and GPS will now be correlated into the live public timeline.',
                      style: TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

          // Automatic Timestamp & Mesh Status Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _surface2,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 16, color: _muted),
                    const SizedBox(width: 6),
                    Text(
                      'Timestamp: $formattedTime (Auto-locked)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Text(
                  widget.isOfflineMesh ? 'BLE Mesh Mode' : 'Online + AI',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: widget.isOfflineMesh ? _blue : _green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Contributor Perspective (Inside vs Outside Affected Area)
          if (!widget.localIssue) ...[
            const Text(
              'Your Perspective / Zone',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'Inside Affected Area',
                  icon: Icon(Icons.crisis_alert_rounded, size: 16),
                  label: Text('Inside Zone', style: TextStyle(fontSize: 12)),
                ),
                ButtonSegment(
                  value: 'Outside / Nearby Witness',
                  icon: Icon(Icons.visibility_rounded, size: 16),
                  label: Text(
                    'Outside / Nearby',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
              selected: {_contributorZone},
              onSelectionChanged: (s) =>
                  setState(() => _contributorZone = s.first),
            ),
            const SizedBox(height: 18),
          ],

          const Text(
            'Add Photo or Video Evidence',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 9),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: _surface,
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Upload photo/video from gallery'),
                ),
                Row(
                  children: [
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
                  ],
                ),
                if (_attachments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${_attachments.length} evidence file(s) attached',
                    style: const TextStyle(
                      color: _green,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  ...List.generate(_attachments.length, (index) {
                    final file = _attachments[index];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.attach_file_rounded,
                        color: _muted,
                      ),
                      title: Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () =>
                            setState(() => _attachments.removeAt(index)),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),

          const Text(
            'Incident / Issue Category',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: InputDecoration(
              filled: true,
              fillColor: _surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
            items: categories
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _category = value);
            },
          ),
          const SizedBox(height: 18),

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Location & GPS',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              TextButton.icon(
                onPressed: _detectingLocation ? null : _detectLocation,
                icon: _detectingLocation
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_rounded, size: 17),
                label: const Text('Refresh GPS'),
              ),
            ],
          ),
          TextField(
            controller: _locationController,
            decoration: InputDecoration(
              hintText: 'GPS location or landmark',
              helperText: _locationStatus,
              prefixIcon: const Icon(Icons.location_on_outlined),
              filled: true,
              fillColor: _surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 18),

          const Text(
            'Description & Observations',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Describe severity, trapped people, road blockage, or landmarks…',
              filled: true,
              fillColor: _surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Notify nearby users & family contacts',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
            subtitle: const Text(
              'Sends alert to users in affected radius & emergency contacts',
              style: TextStyle(color: _muted, fontSize: 11.5),
            ),
            value: _notifyNearbyAndFamily,
            activeThumbColor: _red,
            onChanged: (val) => setState(() => _notifyNearbyAndFamily = val),
          ),
          const SizedBox(height: 16),

          FilledButton.icon(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              backgroundColor: _red,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            icon: Icon(
              widget.isOfflineMesh
                  ? Icons.bluetooth_connected_rounded
                  : Icons.send_rounded,
            ),
            label: Text(
              widget.isOfflineMesh
                  ? 'Relay Report via Offline Mesh'
                  : 'Submit & Correlate Report',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final description = _descriptionController.text.trim();
    final area = _locationController.text.trim().isEmpty
        ? 'Indiranagar, Bengaluru'
        : _locationController.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please add a brief description so Gemini can correlate this report.',
          ),
        ),
      );
      return;
    }

    final isLocal = widget.localIssue;
    final result = LocalIssue(
      id: 'rep_${DateTime.now().millisecondsSinceEpoch}',
      title: _category,
      area: area,
      category: _category,
      time: 'Just now',
      timestamp: _capturedTimestamp,
      icon: isLocal ? Icons.build_circle_rounded : Icons.warning_amber_rounded,
      color: isLocal ? _blue : _red,
      description: description,
      mediaPaths: _attachments.map((file) => file.path).toList(),
      contributorZone: _contributorZone,
      relayedViaMesh: widget.isOfflineMesh,
    );
    Navigator.of(context).pop(result);
  }
}
