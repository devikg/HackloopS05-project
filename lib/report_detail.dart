import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import 'database.dart';
import 'media_service.dart';

class ReportDetail extends StatefulWidget {
  final Report r;
  const ReportDetail({super.key, required this.r});
  @override
  State<ReportDetail> createState() => _ReportDetailState();
}

class _ReportDetailState extends State<ReportDetail> {
  VideoPlayerController? vc;
  bool busy = false;
  Report get r => widget.r;

  @override
  void initState() {
    super.initState();
    final src = r.mediaPath != null && File(r.mediaPath!).existsSync()
        ? r.mediaPath
        : r.mediaUrl;
    if (MediaSvc.isVideo(src)) {
      vc =
          (src == r.mediaUrl
                ? VideoPlayerController.networkUrl(Uri.parse(src!))
                : VideoPlayerController.file(File(src!)))
            ..initialize().then((_) => mounted ? setState(() {}) : null);
    }
  }

  @override
  void dispose() {
    vc?.dispose();
    super.dispose();
  }

  void toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> download() async {
    setState(() => busy = true);
    toast(await MediaSvc.download(r));
    if (mounted) setState(() => busy = false);
  }

  /// Share to Instagram / X / WhatsApp etc. with a verified caption (report ID + location + time).
  Future<void> share() async {
    setState(() => busy = true);
    final f = await MediaSvc.localFile(r);
    final caption =
        '${r.category} reported via SAFE • ${r.area}\n${DateFormat('d MMM y, HH:mm').format(r.createdAt)}\n'
        'https://maps.google.com/?q=${r.lat},${r.lng}\nReport ID: ${r.id}';
    await Share.shareXFiles(f == null ? [] : [XFile(f.path)], text: caption);
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final img = r.mediaPath != null && File(r.mediaPath!).existsSync()
        ? Image.file(File(r.mediaPath!), fit: BoxFit.cover)
        : r.mediaUrl != null
        ? Image.network(r.mediaUrl!, fit: BoxFit.cover)
        : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(r.title),
        actions: [
          if (MediaSvc.hasMedia(r))
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Save to gallery',
              onPressed: busy ? null : download,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (vc != null)
            vc!.value.isInitialized
                ? Column(
                    children: [
                      AspectRatio(
                        aspectRatio: vc!.value.aspectRatio,
                        child: VideoPlayer(vc!),
                      ),
                      IconButton(
                        iconSize: 40,
                        icon: Icon(
                          vc!.value.isPlaying
                              ? Icons.pause_circle
                              : Icons.play_circle,
                        ),
                        onPressed: () => setState(
                          () => vc!.value.isPlaying ? vc!.pause() : vc!.play(),
                        ),
                      ),
                    ],
                  )
                : const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  )
          else if (img != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(height: 300, child: img),
            )
          else
            const SizedBox(
              height: 120,
              child: Center(child: Text('No photo/video attached')),
            ),
          const SizedBox(height: 14),
          ListTile(
            leading: const Icon(Icons.category),
            title: Text(r.category),
            subtitle: const Text('Type'),
          ),
          ListTile(
            leading: const Icon(Icons.place),
            title: Text(r.area),
            subtitle: Text(
              '${r.lat.toStringAsFixed(5)}, ${r.lng.toStringAsFixed(5)}',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: Text(DateFormat('d MMM y, HH:mm').format(r.createdAt)),
            subtitle: Text(r.synced ? 'Synced' : 'Queued offline'),
          ),
          ListTile(
            leading: const Icon(Icons.notes),
            title: Text(
              r.description.isEmpty ? '(no description)' : r.description,
            ),
          ),
          const SizedBox(height: 10),
          if (MediaSvc.hasMedia(r)) ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: busy ? null : download,
              icon: const Icon(Icons.download),
              label: const Text('Download to gallery'),
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: busy ? null : share,
            icon: const Icon(Icons.share),
            label: const Text('Share to social media'),
          ),
        ],
      ),
    );
  }
}
