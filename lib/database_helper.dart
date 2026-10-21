import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'database.dart';

/// Offline-first store: SQLite locally, Supabase when online.
class Db {
  Db._();
  static final i = Db._();
  Database? _db;
  SupabaseClient get _sb => Supabase.instance.client;

  Future<Database> get db async => _db ??= await openDatabase(
    join(await getDatabasesPath(), 'safe.db'),
    version: 2,
    onCreate: (d, _) async {
      await d.execute(
        'CREATE TABLE reports(id TEXT PRIMARY KEY, kind TEXT, category TEXT, '
        'title TEXT, description TEXT, area TEXT, lat REAL, lng REAL, created_at TEXT, '
        'media_url TEXT, media_path TEXT, call_status TEXT, synced INTEGER DEFAULT 0)',
      );
      await d.execute(
        'CREATE TABLE contacts(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, phone TEXT)',
      );
    },
    onUpgrade: (d, oldV, newV) async {
      // Existing installs: add the new column without losing queued reports
      if (oldV < 2) {
        await d.execute('ALTER TABLE reports ADD COLUMN call_status TEXT');
      }
    },
  );

  Future<void> saveLocal(Report r) async => (await db).insert(
    'reports',
    r.toLocal(),
    conflictAlgorithm: ConflictAlgorithm.ignore,
  );

  Future<void> submit(Report r) async {
    await saveLocal(r);
    await sync();
  }

  /// Push unsynced reports (called after submit, on refresh, and when network returns).
  Future<void> sync() async {
    final d = await db;
    final rows = await d.query('reports', where: 'synced=0');
    for (final m in rows) {
      try {
        final r = Report.fromMap(m);
        String? url = r.mediaUrl;
        if (url == null &&
            r.mediaPath != null &&
            File(r.mediaPath!).existsSync()) {
          final name = '${r.id}${extension(r.mediaPath!)}';
          await _sb.storage.from('media').upload(name, File(r.mediaPath!));
          url = _sb.storage.from('media').getPublicUrl(name);
        }
        await _sb.from('reports').upsert({...r.toRemote(), 'media_url': url});
        await d.update(
          'reports',
          {'synced': 1, 'media_url': url},
          where: 'id=?',
          whereArgs: [r.id],
        );
      } catch (_) {
        return; // offline - keep queued
      }
    }
  }

  /// Pull latest public reports, merge locally, return filtered list (newest first).
  Future<List<Report>> fetch(String kind) async {
    try {
      await sync();
      final rows = await _sb
          .from('reports')
          .select()
          .order('created_at', ascending: false)
          .limit(300);
      for (final m in rows) {
        await saveLocal(Report.fromMap({...m, 'synced': 1}));
      }
    } catch (_) {}
    final local = await (await db).query(
      'reports',
      where: 'kind=?',
      whereArgs: [kind],
      orderBy: 'created_at DESC',
    );
    return local.map(Report.fromMap).toList();
  }

  /// Evidence correlation: same category, within [km] km and [hours] hours of the cluster's first report.
  List<List<Report>> clusters(
    List<Report> rs, {
    double km = 1.5,
    int hours = 12,
  }) {
    final sorted = [...rs]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final out = <List<Report>>[];
    for (final r in sorted) {
      final hit = out.where(
        (c) =>
            c.first.category == r.category &&
            r.createdAt.difference(c.first.createdAt).inHours.abs() <= hours &&
            Geolocator.distanceBetween(
                  c.first.lat,
                  c.first.lng,
                  r.lat,
                  r.lng,
                ) <=
                km * 1000,
      );
      if (hit.isEmpty) {
        out.add([r]);
      } else {
        hit.first.add(r);
      }
    }
    out.sort((a, b) => b.length.compareTo(a.length));
    return out;
  }

  Future<Report?> byId(String id) async {
    final r = await (await db).query('reports', where: 'id=?', whereArgs: [id]);
    return r.isEmpty ? null : Report.fromMap(r.first);
  }

  Future<List<Map<String, dynamic>>> contacts() async =>
      (await db).query('contacts');
  Future<void> addContact(String n, String p) async =>
      (await db).insert('contacts', {'name': n, 'phone': p});
  Future<void> delContact(int id) async =>
      (await db).delete('contacts', where: 'id=?', whereArgs: [id]);
}
