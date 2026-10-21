/// Data models + Supabase schema (run supabaseSql once in the Supabase SQL editor).
class Report {
  final String id, kind, category, title, description, area;
  final double lat, lng;
  final DateTime createdAt;
  final String? mediaUrl, mediaPath, callStatus;
  final bool synced;

  Report({
    required this.id,
    required this.kind, // 'emergency' | 'local'
    required this.category,
    required this.title,
    required this.description,
    required this.area,
    required this.lat,
    required this.lng,
    required this.createdAt,
    this.mediaUrl,
    this.mediaPath,
    this.callStatus, // e.g. "connected at 10:02:15, confirmed by caller" (emergency only)
    this.synced = false,
  });

  Map<String, dynamic> toRemote() => {
    'id': id,
    'kind': kind,
    'category': category,
    'title': title,
    'description': description,
    'area': area,
    'lat': lat,
    'lng': lng,
    'created_at': createdAt.toUtc().toIso8601String(),
    'media_url': mediaUrl,
    'call_status': callStatus,
  };

  Map<String, dynamic> toLocal() => {
    ...toRemote(),
    'media_path': mediaPath,
    'synced': synced ? 1 : 0,
  };

  factory Report.fromMap(Map m) => Report(
    id: m['id'],
    kind: m['kind'],
    category: m['category'] ?? 'Other',
    title: m['title'] ?? '',
    description: m['description'] ?? '',
    area: m['area'] ?? '',
    lat: (m['lat'] as num).toDouble(),
    lng: (m['lng'] as num).toDouble(),
    createdAt: DateTime.parse(m['created_at']).toLocal(),
    mediaUrl: m['media_url'],
    mediaPath: m['media_path'],
    callStatus: m['call_status'],
    synced: m['synced'] == 1,
  );
}

const supabaseSql = '''
create table if not exists reports (
  id text primary key, kind text, category text, title text, description text,
  area text, lat double precision, lng double precision,
  created_at timestamptz default now(), media_url text, call_status text
);
alter table reports add column if not exists call_status text;
alter table reports enable row level security;
create policy "public read"  on reports for select using (true);
create policy "public write" on reports for insert with check (true);
-- Storage: create a PUBLIC bucket named "media" with an insert policy for anon.
''';
