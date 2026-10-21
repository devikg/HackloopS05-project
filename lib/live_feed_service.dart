import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

import 'database.dart';
import 'database_helper.dart';

class _NewsCache {
  final List<Map<String, dynamic>> items;
  final DateTime at;
  _NewsCache(this.items, this.at);
}

/// Weather, alerts, local news, city search and GPS location.
class Feed {
  static String get _owm => dotenv.env['OPENWEATHER_KEY'] ?? '';

  /// Shown on screen so testers can report whether news loaded.
  static String newsStatus = 'News: not fetched yet';

  /// News is kept for 6 hours per city, so testers don't use up the GNews daily limit.
  static final Map<String, _NewsCache> _newsCache = {};
  static const _newsTtl = Duration(hours: 6);

  /// Towns searched alongside each base city. Add more entries here as needed.
  static const Map<String, List<String>> nearbyTowns = {
    'karkala': ['Udupi', 'Mangaluru'],
    'udupi': ['Karkala', 'Mangaluru'],
    'mangaluru': ['Udupi', 'Karkala'],
  };

  static String _time() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }

  /// Current GPS position, or null if location is off or permission is denied.
  static Future<Position?> pos() async {
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition().timeout(
        const Duration(seconds: 10),
      );
    } catch (_) {
      return null;
    }
  }

  /// Returns a "City, State" label for coordinates.
  static Future<String> area(double lat, double lng) async {
    try {
      final r = await http.get(
        Uri.parse(
          'https://api.openweathermap.org/geo/1.0/reverse?lat=$lat&lon=$lng&limit=1&appid=$_owm',
        ),
      );
      final j = jsonDecode(r.body)[0];
      return '${j['name']}, ${j['state'] ?? j['country']}';
    } catch (_) {
      return '${lat.toStringAsFixed(3)}, ${lng.toStringAsFixed(3)}';
    }
  }

  /// City suggestions as the user types (OpenStreetMap Nominatim, India only, no key needed).
  static Future<List<Map<String, dynamic>>> suggest(String q) async {
    try {
      final r = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(q)}'
          '&format=json&limit=8&countrycodes=in&addressdetails=1',
        ),
        headers: {'User-Agent': 'SAFE-Community-App/1.0'},
      );
      final list = jsonDecode(r.body) as List;
      return list.map<Map<String, dynamic>>((j) {
        final addr = (j['address'] ?? {}) as Map;
        final name =
            (j['name'] ?? (j['display_name'] as String).split(',').first)
                .toString();
        final state = (addr['state'] ?? addr['country'] ?? '').toString();
        return {
          'name': name,
          'label': state.isEmpty ? name : '$name, $state',
          'lat': double.parse(j['lat'].toString()),
          'lng': double.parse(j['lon'].toString()),
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>?> weather(double lat, double lng) async {
    try {
      final r = await http.get(
        Uri.parse(
          'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lng&units=metric&appid=$_owm',
        ),
      );
      return jsonDecode(r.body);
    } catch (_) {
      return null;
    }
  }

  /// Disaster and weather alerts derived from current conditions.
  static List<Map<String, String>> alerts(Map<String, dynamic>? w) {
    if (w == null) return [];
    final id = (w['weather'][0]['id'] as int);
    final wind = (w['wind']['speed'] as num).toDouble();
    final out = <Map<String, String>>[];
    if (id < 300) {
      out.add({
        't': 'Thunderstorm Alert',
        'd': 'Stay indoors, avoid open areas',
      });
    }
    if (id >= 502 && id < 600) {
      out.add({
        't': 'Heavy Rainfall Alert',
        'd': 'Risk of waterlogging and flooding',
      });
    }
    if (id >= 600 && id < 700) {
      out.add({'t': 'Snow Alert', 'd': 'Travel disruptions likely'});
    }
    if (id == 781) {
      out.add({'t': 'Tornado Warning', 'd': 'Seek shelter immediately'});
    }
    if (wind > 14) {
      out.add({
        't': 'High Wind Alert',
        'd': 'Wind ${wind.toStringAsFixed(0)} m/s - beware falling trees',
      });
    }
    if ((w['main']['temp'] as num) > 40) {
      out.add({'t': 'Heatwave Alert', 'd': 'Stay hydrated, avoid midday sun'});
    }
    return out;
  }

  /// Local news for the city and nearby towns, cached for 6 hours per city.
  /// Only articles whose TITLE names a town are kept, and each is tagged with that town.
  /// Set [force] to true to bypass the cache (use sparingly).
  static Future<List<Map<String, dynamic>>> newsNearby(
    String city, {
    bool force = false,
  }) async {
    final base = city
        .replaceAll(
          RegExp(
            r'\b(taluk|taluka|district|tehsil|city)\b',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    final cacheKey = base.toLowerCase();

    final hit = _newsCache[cacheKey];
    if (!force && hit != null && DateTime.now().difference(hit.at) < _newsTtl) {
      newsStatus =
          'News from cache (saved ${hit.at.hour.toString().padLeft(2, '0')}:${hit.at.minute.toString().padLeft(2, '0')}), ${hit.items.length} articles';
      return hit.items;
    }

    final key = dotenv.env['GNEWS_API_KEY'] ?? '';
    if (key.isEmpty) {
      newsStatus = 'News FAILED: GNEWS_API_KEY missing in .env';
      return [];
    }

    final towns = [base, ...(nearbyTowns[cacheKey] ?? const <String>[])];
    final results = <Map<String, dynamic>>[];
    var okRequests = 0;
    String? lastError;

    for (final t in towns) {
      try {
        final q = Uri.encodeComponent('"$t"');
        final r = await http.get(
          Uri.parse(
            'https://gnews.io/api/v4/search?q=$q&lang=en&country=in&max=10&sortby=publishedAt&apikey=$key',
          ),
        );
        if (r.statusCode != 200) {
          lastError = 'HTTP ${r.statusCode}';
          continue;
        }
        okRequests++;
        final articles = List<Map<String, dynamic>>.from(
          jsonDecode(r.body)['articles'] ?? [],
        );
        for (final a in articles) {
          if ((a['title'] ?? '').toString().toLowerCase().contains(
            t.toLowerCase(),
          )) {
            results.add({...a, 'town': t});
          }
        }
      } catch (e) {
        lastError = 'no internet or timeout';
      }
    }

    // Remove duplicates by link, then show newest first
    final seen = <String>{};
    results.retainWhere((a) => seen.add((a['url'] ?? '').toString()));
    results.sort(
      (a, b) => (b['publishedAt'] ?? '').toString().compareTo(
        (a['publishedAt'] ?? '').toString(),
      ),
    );

    if (okRequests == 0) {
      // Nothing succeeded: don't cache, so the next load retries
      newsStatus = 'News FAILED at ${_time()}: ${lastError ?? 'unknown'}';
      return results;
    }

    _newsCache[cacheKey] = _NewsCache(results, DateTime.now());
    newsStatus =
        'News fetched live at ${_time()}: ${results.length} articles from $okRequests/${towns.length} towns';
    return results;
  }
}

/// Offline device-to-device relay using Google Nearby Connections (Android; Bluetooth/Wi-Fi Direct).
class Mesh {
  Mesh._();
  static final i = Mesh._();
  final peers = <String>{};
  final _seen = <String>{};
  bool running = false;
  void Function()? onChange;
  final _name = 'SAFE-${Random().nextInt(9999)}';
  static const _svc = Strategy.P2P_CLUSTER;

  Future<bool> start() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.location,
      Permission.nearbyWifiDevices,
    ].request();
    try {
      await Nearby().startAdvertising(
        _name,
        _svc,
        onConnectionInitiated: _init,
        onConnectionResult: _res,
        onDisconnected: _drop,
      );
      await Nearby().startDiscovery(
        _name,
        _svc,
        onEndpointFound: (id, n, s) => Nearby().requestConnection(
          _name,
          id,
          onConnectionInitiated: _init,
          onConnectionResult: _res,
          onDisconnected: _drop,
        ),
        onEndpointLost: (_) {},
      );
      running = true;
    } catch (_) {
      running = false;
    }
    onChange?.call();
    return running;
  }

  Future<void> stop() async {
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    await Nearby().stopAllEndpoints();
    peers.clear();
    running = false;
    onChange?.call();
  }

  void _init(String id, ConnectionInfo info) => Nearby().acceptConnection(
    id,
    onPayLoadRecieved: (from, p) async {
      if (p.type != PayloadType.BYTES) return;
      final m = jsonDecode(utf8.decode(p.bytes!));
      if (!_seen.add(m['id'])) return; // dedupe
      await Db.i.saveLocal(
        Report.fromMap(m),
      ); // store; synced later when online
      _send(m, except: from); // relay onward
      onChange?.call();
    },
  );

  void _res(String id, Status s) {
    if (s == Status.CONNECTED) peers.add(id);
    onChange?.call();
  }

  void _drop(String id) {
    peers.remove(id);
    onChange?.call();
  }

  void _send(Map m, {String? except}) {
    final b = Uint8List.fromList(utf8.encode(jsonEncode(m)));
    for (final p in peers) {
      if (p != except) Nearby().sendBytesPayload(p, b);
    }
  }

  void broadcast(Report r) {
    _seen.add(r.id);
    _send(r.toRemote()..remove('media_url'));
  }
}
