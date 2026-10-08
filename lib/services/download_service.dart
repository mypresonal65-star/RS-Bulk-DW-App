import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/batch_model.dart';
import 'api_service.dart';
import 'storage_service.dart';

class DownloadItem {
  final String id;
  final String title;
  final String type; // 'video' or 'note'
  final String batchId;
  final String subjectId;
  final String rawUrl;

  DownloadItem({
    required this.id,
    required this.title,
    required this.type,
    required this.batchId,
    required this.subjectId,
    this.rawUrl = '',
  });
}

class DownloadProgress {
  bool isDownloading = false;
  bool isPaused = false;
  String currentFile = "";
  double fileProgress = 0.0;
  double overallProgress = 0.0;
  String speed = "0 KB/s";
  String eta = "--:--";
  String elapsed = "00:00:00";
  int completedCount = 0;
  int totalCount = 0;
  List<String> logs = [];
}

class DownloadService extends ChangeNotifier {
  final ApiService _apiService;
  final StorageService _storageService;

  DownloadProgress progress = DownloadProgress();
  bool _cancelRequested = false;

  DownloadService(this._apiService, this._storageService);

  void addLog(String message) {
    progress.logs.add("[${DateTime.now().toIso8601String().substring(11, 19)}] $message");
    if (progress.logs.length > 200) {
      progress.logs.removeAt(0);
    }
    notifyListeners();
  }

  void cancelDownload() {
    _cancelRequested = true;
    progress.isDownloading = false;
    addLog("🛑 Download stopped by user.");
    notifyListeners();
  }

  void pauseDownload() {
    progress.isPaused = !progress.isPaused;
    addLog(progress.isPaused ? "⏸ Download paused." : "▶ Download resumed.");
    notifyListeners();
  }

  // --- START QUEUE PROCESSOR ---
  Future<void> startDownloads(List<DownloadItem> queue, String batchName) async {
    if (progress.isDownloading || queue.isEmpty) return;

    _cancelRequested = false;
    progress.isDownloading = true;
    progress.isPaused = false;
    progress.totalCount = queue.length;
    progress.completedCount = 0;
    progress.overallProgress = 0.0;
    progress.logs.clear();

    final startTime = DateTime.now();
    addLog("🚀 Turbo Engine Started for ${queue.length} item(s)...");
    notifyListeners();

    final baseDir = await _storageService.getDownloadDirectory();
    final batchFolder = Directory("${baseDir.path}/$batchName");
    if (!await batchFolder.exists()) {
      await batchFolder.create(recursive: true);
    }

    for (int i = 0; i < queue.length; i++) {
      if (_cancelRequested) break;

      final item = queue[i];
      progress.currentFile = item.title;
      progress.fileProgress = 0.0;
      progress.speed = "Connecting...";
      notifyListeners();

      addLog("📥 Downloading: ${item.title} (${item.type.toUpperCase()})");

      bool success = false;
      if (item.type == 'note') {
        success = await _downloadPdf(item, batchFolder);
      } else {
        success = await _downloadVideo(item, batchFolder);
      }

      if (success) {
        progress.completedCount++;
        addLog("✅ Completed: ${item.title}");
      } else {
        addLog("❌ Failed / Skipped: ${item.title}");
      }

      final diff = DateTime.now().difference(startTime);
      progress.elapsed = "${diff.inHours.toString().padLeft(2, '0')}:${(diff.inMinutes % 60).toString().padLeft(2, '0')}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}";
      progress.overallProgress = (progress.completedCount / progress.totalCount) * 100;
      notifyListeners();
    }

    progress.isDownloading = false;
    addLog("🏁 All downloads completed! Files saved in: ${batchFolder.path}");
    notifyListeners();
  }

  // --- PDF DOWNLOAD WITH FALLBACK ---
  Future<bool> _downloadPdf(DownloadItem item, Directory saveFolder) async {
    final sanitized = item.title.replaceAll(RegExp(r'[\\/*?:"<>|]'), '');
    final targetFile = File("${saveFolder.path}/$sanitized.pdf");

    if (item.rawUrl.isEmpty) return false;

    // Try direct link first, then fallback to proxy API
    List<String> tryUrls = [
      item.rawUrl,
      _apiService.getPdfDownloadUrl(item.rawUrl),
    ];

    for (final url in tryUrls) {
      if (_cancelRequested) break;
      try {
        final client = http.Client();
        final request = http.Request('GET', Uri.parse(url));
        request.headers['User-Agent'] = _apiService.userAgent;

        final response = await client.send(request).timeout(const Duration(seconds: 20));
        if (response.statusCode == 200) {
          final totalBytes = response.contentLength ?? 0;
          int received = 0;
          final sink = targetFile.openWrite();

          final speedTimer = Stopwatch()..start();
          await for (var chunk in response.stream) {
            if (_cancelRequested) {
              await sink.close();
              if (await targetFile.exists()) await targetFile.delete();
              return false;
            }
            while (progress.isPaused) {
              await Future.delayed(const Duration(milliseconds: 500));
            }

            sink.add(chunk);
            received += chunk.length;

            if (totalBytes > 0) {
              progress.fileProgress = (received / totalBytes) * 100;
              final seconds = speedTimer.elapsedMilliseconds / 1000;
              if (seconds > 0.5) {
                final kbps = (received / 1024) / seconds;
                progress.speed = kbps > 1024 ? "${(kbps / 1024).toStringAsFixed(1)} MB/s" : "${kbps.toStringAsFixed(0)} KB/s";
              }
              notifyListeners();
            }
          }

          await sink.close();
          if (await targetFile.length() > 500) {
            return true;
          }
        }
      } catch (e) {
        addLog("[PDF RETRY] ${e.toString()}");
      }
    }
    return false;
  }

  Future<String?> _getNativeTool(String toolName) async {
    try {
      const channel = MethodChannel('com.studypro.downloader/tools');
      final String? libDir = await channel.invokeMethod<String>('getNativeLibraryDir');
      if (libDir != null && libDir.isNotEmpty) {
        final f = File("$libDir/$toolName");
        if (await f.exists()) return f.path;
      }
    } catch (_) {}
    return null;
  }

  // --- VIDEO DOWNLOAD (RESOLVES STREAM & RUNS ENGINE) ---
  Future<bool> _downloadVideo(DownloadItem item, Directory saveFolder) async {
    final sanitized = item.title.replaceAll(RegExp(r'[\\/*?:"<>|]'), '');
    final targetFile = File("${saveFolder.path}/$sanitized.mp4");

    addLog("🔑 Resolving Stream keys for ${item.title}...");
    final drmData = await _apiService.getVideoUrlDetails(
      batchId: item.batchId,
      subjectId: item.subjectId,
      scheduleId: item.id,
    );

    if (drmData['success'] != true || drmData['data'] == null) {
      addLog("⚠️ Stream Error: ${drmData['error'] ?? 'Could not get stream URL'}");
      return false;
    }

    final mpdUrl = drmData['data']['url'] as String? ?? '';
    final keys = drmData['data']['keys'] as List? ?? [];

    addLog("✨ Found ${keys.length} key(s). Stream: ${mpdUrl.length > 35 ? mpdUrl.substring(0, 35) : mpdUrl}...");

    // 1. Try Native ARM64 Engine (N_m3u8DL-RE + mp4decrypt + FFmpeg)
    final nM3u8Dl = await _getNativeTool("libn_m3u8dl.so");
    final mp4decrypt = await _getNativeTool("libmp4decrypt.so");
    final ffmpeg = await _getNativeTool("libffmpeg.so");

    addLog("Tools Status: N_m3u8DL=${nM3u8Dl != null ? '✅' : '❌'} | mp4decrypt=${mp4decrypt != null ? '✅' : '❌'} | ffmpeg=${ffmpeg != null ? '✅' : '❌'}");

    if (nM3u8Dl != null && await File(nM3u8Dl).exists()) {
      addLog("🚀 Running In-App Native Stream Engine...");
      
      final args = [
        mpdUrl,
        '--header', 'Accept: */*',
        '--header', 'Origin: https://rarestudy.testuk.org',
        '--header', 'User-Agent: ${_apiService.userAgent}',
        '--select-video', 'res=.*(720|1280).*:for=best',
        '--select-audio', 'for=best',
        '--thread-count', '16',
        '--download-retry-count', '3',
        '--concurrent-download',
        '--check-segments-count', 'false',
        '--no-date-info',
        '--del-after-done',
        '--save-dir', saveFolder.path,
        '--save-name', sanitized,
      ];

      if (_apiService.cookieHeaderString.isNotEmpty) {
        args.addAll(['--header', 'Cookie: ${_apiService.cookieHeaderString}']);
      }

      for (final k in keys) {
        args.addAll(['--key', k.toString()]);
      }

      if (mp4decrypt != null && await File(mp4decrypt).exists()) {
        args.addAll([
          '--decryption-binary-path', mp4decrypt,
        ]);
      }

      if (ffmpeg != null && await File(ffmpeg).exists()) {
        args.addAll([
          '--ffmpeg-binary-path', ffmpeg,
          '-M', 'format=mp4:muxer=ffmpeg',
        ]);
      }

      try {
        final process = await Process.start(nM3u8Dl, args);
        
        process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty) {
            final percMatch = RegExp(r'(\d+(?:\.\d+)?)\s*%').firstMatch(trimmed);
            if (percMatch != null) {
              final p = double.tryParse(percMatch.group(1) ?? '');
              if (p != null) {
                progress.fileProgress = p.clamp(0.0, 100.0);
              }
            }
            final speedMatch = RegExp(r'(\d+(?:\.\d+)?\s*(?:MB|KB|GB)/s)', caseSensitive: false).firstMatch(trimmed);
            if (speedMatch != null) {
              progress.speed = speedMatch.group(1) ?? '';
            }
            notifyListeners();
          }
        });

        process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
          if (line.trim().isNotEmpty) {
            addLog("[ENGINE] ${line.trim()}");
          }
        });

        final exitCode = await process.exitCode;
        if (exitCode == 0 || (await targetFile.exists() && await targetFile.length() > 1024 * 1024)) {
          return true;
        }
      } catch (e) {
        addLog("Native Engine notice: $e");
      }
    }

    // 2. Direct Stream Handling (Prevent saving 5KB XML manifest files as fake MP4)
    if (mpdUrl.endsWith('.mpd') || mpdUrl.contains('.mpd?')) {
      addLog("ℹ️ Protected MPEG-DASH Stream detected.");
      addLog("💡 Use In-App Player to stream in Full HD, or use 'PC .BAT' to download raw MP4 on computer.");
      if (await targetFile.exists() && await targetFile.length() < 100 * 1024) {
        await targetFile.delete();
      }
      return false;
    }

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(mpdUrl));
      request.headers['User-Agent'] = _apiService.userAgent;
      request.headers['Origin'] = 'https://rarestudy.testuk.org';
      if (_apiService.cookieHeaderString.isNotEmpty) {
        request.headers['Cookie'] = _apiService.cookieHeaderString;
      }

      final response = await client.send(request).timeout(const Duration(seconds: 25));
      if (response.statusCode == 200) {
        final sink = targetFile.openWrite();
        int received = 0;
        final total = response.contentLength ?? 1;

        await for (var chunk in response.stream) {
          if (_cancelRequested) {
            await sink.close();
            if (await targetFile.exists()) await targetFile.delete();
            return false;
          }
          sink.add(chunk);
          received += chunk.length;
          progress.fileProgress = (received / total).clamp(0.0, 1.0) * 100;
          notifyListeners();
        }
        await sink.close();

        // Verify that the file is an actual video file (> 500 KB)
        if (await targetFile.length() > 500 * 1024) {
          return true;
        } else {
          if (await targetFile.exists()) await targetFile.delete();
          addLog("⚠️ Stream response was not a full video file. Use In-App Player or PC .BAT export.");
          return false;
        }
      }
    } catch (e) {
      addLog("Stream Download Note: $e");
    }

    return false;
  }
}
