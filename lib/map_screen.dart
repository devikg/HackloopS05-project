import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'database.dart';

/// Map of incident reports. Centers on [center] if given, otherwise on the first report.
class MapScreen extends StatelessWidget {
  final List<Report> reports;
  final LatLng? center;
  const MapScreen({super.key, required this.reports, this.center});

  @override
  Widget build(BuildContext context) {
    final LatLng c =
        center ??
        (reports.isNotEmpty
            ? LatLng(reports.first.lat, reports.first.lng)
            : const LatLng(0, 0));
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: FlutterMap(
        options: MapOptions(initialCenter: c, initialZoom: 13),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.hackloops05_project',
          ),
          MarkerLayer(
            markers: [
              for (final r in reports)
                Marker(
                  point: LatLng(r.lat, r.lng),
                  width: 40,
                  height: 40,
                  child: GestureDetector(
                    onTap: () => showModalBottomSheet(
                      context: context,
                      builder: (_) => ListTile(
                        title: Text(r.title),
                        subtitle: Text('${r.description}\n${r.area}'),
                        isThreeLine: true,
                      ),
                    ),
                    child: Icon(
                      Icons.location_on,
                      size: 36,
                      color: r.kind == 'emergency'
                          ? Colors.redAccent
                          : Colors.amber,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
