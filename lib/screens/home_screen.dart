import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../models/user_session.dart';
import '../models/batch_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/download_service.dart';
import 'download_screen.dart';
import 'auth_screen.dart';

class HomeScreen extends StatefulWidget {
  final ApiService apiService;
  final StorageService storageService;
  final UserSession session;

  const HomeScreen({
    super.key,
    required this.apiService,
    required this.storageService,
    required this.session,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  BatchManifest? _manifest;
  String _currentFilter = 'all'; // 'all', 'video', 'note'
  String _searchQuery = '';
  late DownloadService _downloadService;

  @override
  void initState() {
    super.initState();
    _downloadService = DownloadService(widget.apiService, widget.storageService);
    _initApp();
  }

  Future<void> _initApp() async {
    await widget.storageService.requestAllPermissions();
    await widget.apiService.fetchRemoteHeaders();
    final cached = await widget.storageService.loadLastBatch();
    if (cached != null) {
      setState(() {
        _manifest = cached;
      });
    }
  }

  // --- PICK BATCH MANIFEST JSON FILE ---
  Future<void> _pickManifestFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        final parsed = widget.storageService.parseManifestString(content);
        if (parsed != null) {
          await widget.storageService.cacheLastBatch(content);
          setState(() {
            _manifest = parsed;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Loaded batch: ${parsed.name}"),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        } else {
          _showError("Invalid JSON structure. Please select a valid course batch JSON.");
        }
      }
    } catch (e) {
      _showError("Failed to open file: $e");
    }
  }

  // --- PASTE BATCH MANIFEST JSON DIALOG ---
  void _showPasteJsonDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text("Paste Manifest JSON", style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: textController,
          maxLines: 8,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
          decoration: const InputDecoration(
            hintText: 'Paste {"batch": {...}, "subjects": [...]} here',
            hintStyle: TextStyle(color: Colors.white24),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = textController.text.trim();
              if (text.isNotEmpty) {
                final parsed = widget.storageService.parseManifestString(text);
                if (parsed != null) {
                  await widget.storageService.cacheLastBatch(text);
                  setState(() {
                    _manifest = parsed;
                  });
                  Navigator.pop(ctx);
                } else {
                  _showError("Invalid JSON format.");
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
            child: const Text("Load Course", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  // --- SELECTION COUNTERS ---
  int get selectedVideosCount {
    if (_manifest == null) return 0;
    int count = 0;
    for (var s in _manifest!.subjects) {
      for (var t in s.topics) {
        count += t.lectures.where((l) => l.isSelected).length;
      }
    }
    return count;
  }

  int get selectedNotesCount {
    if (_manifest == null) return 0;
    int count = 0;
    for (var s in _manifest!.subjects) {
      for (var t in s.topics) {
        count += t.notes.where((n) => n.isSelected).length;
      }
    }
    return count;
  }

  int get totalSelectedCount => selectedVideosCount + selectedNotesCount;

  void _toggleSelectAll(bool select) {
    if (_manifest == null) return;
    setState(() {
      for (var s in _manifest!.subjects) {
        for (var t in s.topics) {
          if (_currentFilter == 'all' || _currentFilter == 'video') {
            for (var l in t.lectures) {
              l.isSelected = select;
            }
          }
          if (_currentFilter == 'all' || _currentFilter == 'note') {
            for (var n in t.notes) {
              n.isSelected = select;
            }
          }
        }
      }
    });
  }

  void _startSelectedDownloads() {
    if (totalSelectedCount == 0 || _manifest == null) return;

    List<DownloadItem> queue = [];
    for (var s in _manifest!.subjects) {
      for (var t in s.topics) {
        for (var l in t.lectures) {
          if (l.isSelected) {
            queue.add(DownloadItem(
              id: l.videoId,
              title: l.title,
              type: 'video',
              batchId: _manifest!.id,
              subjectId: s.subjectId,
            ));
          }
        }
        for (var n in t.notes) {
          if (n.isSelected) {
            queue.add(DownloadItem(
              id: n.name,
              title: n.name,
              type: 'note',
              batchId: _manifest!.id,
              subjectId: s.subjectId,
              rawUrl: n.url,
            ));
          }
        }
      }
    }

    _downloadService.startDownloads(queue, _manifest!.name);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DownloadScreen(downloadService: _downloadService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080C16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bolt, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              "Study Pro",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8).withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_circle, color: Color(0xFF38BDF8), size: 16),
                const SizedBox(width: 6),
                Text(
                  widget.session.userName,
                  style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white54, size: 20),
            onPressed: () async {
              await widget.storageService.clearSession();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => AuthScreen(
                    apiService: widget.apiService,
                    storageService: widget.storageService,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Batch Card Banner
          Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF131D35), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _manifest?.name ?? "No Batch Loaded",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _manifest != null
                                ? "${_manifest!.subjects.length} Subjects available"
                                : "Tap button to load course syllabus JSON",
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.paste, color: Color(0xFF38BDF8)),
                          tooltip: "Paste JSON",
                          onPressed: _showPasteJsonDialog,
                        ),
                        ElevatedButton.icon(
                          onPressed: _pickManifestFile,
                          icon: const Icon(Icons.folder_open, size: 16),
                          label: const Text("Load JSON"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Filters & Selection row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                _buildFilterChip('all', 'All'),
                const SizedBox(width: 8),
                _buildFilterChip('video', 'Videos ($selectedVideosCount)'),
                const SizedBox(width: 8),
                _buildFilterChip('note', 'PDFs ($selectedNotesCount)'),
                const Spacer(),
                TextButton(
                  onPressed: () => _toggleSelectAll(true),
                  child: const Text("Select All", style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12)),
                ),
                TextButton(
                  onPressed: () => _toggleSelectAll(false),
                  child: const Text("Clear", style: TextStyle(color: Colors.white54, fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Tree Syllabus List
          Expanded(
            child: _manifest == null
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.layers_outlined, size: 48, color: Colors.white24),
                        SizedBox(height: 12),
                        Text(
                          "Load course batch JSON file to view syllabus",
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _manifest!.subjects.length,
                    itemBuilder: (ctx, sIdx) {
                      final subject = _manifest!.subjects[sIdx];
                      return _buildSubjectCard(subject);
                    },
                  ),
          ),
        ],
      ),

      // Bottom Bar when items are selected
      bottomNavigationBar: totalSelectedCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "$totalSelectedCount item(s) selected",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          "$selectedVideosCount videos, $selectedNotesCount notes",
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        ),
                      ],
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: _exportBatScript,
                      icon: const Icon(Icons.laptop, size: 16),
                      label: const Text("PC .BAT"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF38BDF8),
                        side: const BorderSide(color: Color(0xFF0284C7)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _startSelectedDownloads,
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text("Download"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final active = _currentFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _currentFilter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF0284C7) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? const Color(0xFF38BDF8) : Colors.white12),
        ),
        child: Text(
          label,
          style: TextStyle(color: active ? Colors.white : Colors.white60, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildSubjectCard(SubjectInfo subject) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ExpansionTile(
        title: Text(
          subject.subjectName,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Text(
          "${subject.topics.length} Chapters",
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
        iconColor: const Color(0xFF38BDF8),
        collapsedIconColor: Colors.white38,
        children: subject.topics.map((t) => _buildTopicTile(subject, t)).toList(),
      ),
    );
  }

  Widget _buildTopicTile(SubjectInfo subject, TopicInfo topic) {
    final showVideos = _currentFilter == 'all' || _currentFilter == 'video';
    final showNotes = _currentFilter == 'all' || _currentFilter == 'note';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF090E1C),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExpansionTile(
        title: Text(
          topic.chapterName,
          style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          "${topic.lectures.length} Videos • ${topic.notes.length} PDFs",
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
        ),
        children: [
          if (showVideos)
            ...topic.lectures.map((l) => _buildLectureTile(subject, topic, l)),
          if (showNotes)
            ...topic.notes.map((n) => _buildNoteTile(subject, topic, n)),
        ],
      ),
    );
  }

  // --- LECTURE ITEM TILE (PLAY + DOWNLOAD OPTIONS) ---
  Widget _buildLectureTile(SubjectInfo subject, TopicInfo topic, LectureItem l) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: l.isSelected ? const Color(0xFF0284C7) : Colors.white.withOpacity(0.04),
        ),
      ),
      child: Row(
        children: [
          // Select Checkbox
          InkWell(
            onTap: () => setState(() => l.isSelected = !l.isSelected),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                l.isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                color: l.isSelected ? const Color(0xFF38BDF8) : Colors.white30,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Title & Info
          Expanded(
            child: InkWell(
              onTap: () => _playLecture(subject, l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.title,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text("VIDEO", style: TextStyle(color: Color(0xFF38BDF8), fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                      if (l.duration.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(l.duration, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Action Buttons: Play & Download
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () => _playLecture(subject, l),
                icon: const Icon(Icons.play_arrow, size: 15),
                label: const Text("Play"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.download_outlined, color: Color(0xFF10B981), size: 20),
                tooltip: "Download Options",
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
                onPressed: () => _showDownloadLectureSheet(subject, l),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- PDF NOTE ITEM TILE ---
  Widget _buildNoteTile(SubjectInfo subject, TopicInfo topic, NoteItem n) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: n.isSelected ? const Color(0xFFF43F5E) : Colors.white.withOpacity(0.04),
        ),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => setState(() => n.isSelected = !n.isSelected),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                n.isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                color: n.isSelected ? const Color(0xFFF43F5E) : Colors.white30,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.name,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF43F5E).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text("PDF NOTE", style: TextStyle(color: Color(0xFFFB7185), fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              setState(() => n.isSelected = true);
              _startSelectedDownloads();
            },
            icon: const Icon(Icons.picture_as_pdf, size: 14),
            label: const Text("PDF"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ],
      ),
    );
  }

  // --- LAUNCH HARDWARE-ACCELERATED IN-APP VIDEO PLAYER ---
  Future<void> _playLecture(SubjectInfo subject, LectureItem l) async {
    bool isDialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          color: Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            side: BorderSide(color: Color(0xFF38BDF8), width: 0.5),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF38BDF8)),
                SizedBox(height: 16),
                Text(
                  "Connecting to stream...",
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 6),
                Text(
                  "Resolving keys & initializing player",
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      isDialogShowing = false;
    });

    try {
      final res = await widget.apiService.getVideoUrlDetails(
        batchId: _manifest!.id,
        subjectId: subject.subjectId,
        scheduleId: l.videoId,
      );

      if (isDialogShowing && mounted) {
        Navigator.pop(context);
        isDialogShowing = false;
      }

      String mpdUrl = '';
      List<String> keysList = [];

      if (res['success'] == true && res['data'] != null) {
        mpdUrl = res['data']['url'] as String? ?? '';
        keysList = (res['data']['keys'] as List? ?? []).map((e) => e.toString()).toList();
      }

      // Fallback: If API did not return url, check if rawUrl was in batch JSON
      if (mpdUrl.isEmpty && l.rawUrl.isNotEmpty) {
        mpdUrl = l.rawUrl;
      }

      if (mpdUrl.isEmpty) {
        _showError(res['error'] ?? "Stream URL not found for this lecture.");
        return;
      }

      const platform = MethodChannel('com.studypro.downloader/player');
      await platform.invokeMethod('playVideo', {
        'url': mpdUrl,
        'keys': keysList,
        'title': l.title,
        'subject': subject.subjectName,
        'batch': _manifest!.name,
        'userAgent': widget.apiService.userAgent,
        'cookie': widget.apiService.cookieHeaderString,
        'referer': "https://rarestudy.testuk.org/schedule-details?batchId=${_manifest!.id}&subjectId=${subject.subjectId}&scheduleId=${l.videoId}&tap=video",
      });
    } catch (e) {
      if (isDialogShowing && mounted) {
        Navigator.pop(context);
        isDialogShowing = false;
      }
      _showError("Error starting player: $e");
    }
  }

  // --- DOWNLOAD OPTIONS BOTTOM SHEET FOR LECTURE ---
  void _showDownloadLectureSheet(SubjectInfo subject, LectureItem l) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.title,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                "${subject.subjectName} • ${_manifest?.name ?? ''}",
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
              const Divider(color: Colors.white12, height: 24),

              // 1. Play in In-App Player
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF0284C7).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.play_circle_fill, color: Color(0xFF38BDF8), size: 22),
                ),
                title: const Text("Play in In-App Video Player", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text("Zero download needed. Full HD streaming with speed controls", style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _playLecture(subject, l);
                },
              ),

              // 2. Add to Mobile Download Queue
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.download, color: Color(0xFF10B981), size: 22),
                ),
                title: const Text("Add to Mobile Download Queue", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text("Download using mobile engine queue", style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => l.isSelected = true);
                  _startSelectedDownloads();
                },
              ),

              // 3. Copy PC .BAT Command
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.purple.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.laptop_chromebook, color: Colors.purpleAccent, size: 22),
                ),
                title: const Text("Copy PC / Laptop .BAT Command", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text("Copy command to download full 1080p MP4 on your computer", style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _generateSingleBatCommand(subject, l);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- RESOLVE & COPY SINGLE PC .BAT COMMAND ---
  Future<void> _generateSingleBatCommand(SubjectInfo subject, LectureItem l) async {
    bool isDialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          color: Color(0xFF0F172A),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.purpleAccent),
                SizedBox(width: 14),
                Text("Resolving keys for PC command...", style: TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      isDialogShowing = false;
    });

    try {
      final res = await widget.apiService.getVideoUrlDetails(
        batchId: _manifest!.id,
        subjectId: subject.subjectId,
        scheduleId: l.videoId,
      );

      if (isDialogShowing && mounted) {
        Navigator.pop(context);
        isDialogShowing = false;
      }

      String mpdUrl = '';
      List<String> keys = [];

      if (res['success'] == true && res['data'] != null) {
        mpdUrl = res['data']['url'] as String? ?? '';
        keys = (res['data']['keys'] as List? ?? []).map((e) => e.toString()).toList();
      }

      if (mpdUrl.isEmpty && l.rawUrl.isNotEmpty) {
        mpdUrl = l.rawUrl;
      }

      if (mpdUrl.isNotEmpty) {
        final sanitized = l.title.replaceAll(RegExp(r'[\\/*?:"<>|]'), '');
        final keyArgs = keys.map((k) => '--key "$k"').join(' ');

        final cmd = 'N_m3u8DL-RE "$mpdUrl" $keyArgs --select-video "res=.*(720|1280).*:for=best" --select-audio "for=best" --thread-count 32 --save-name "$sanitized" -M format=mp4:muxer=ffmpeg';

        await Clipboard.setData(ClipboardData(text: cmd));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Copied PC .BAT command for: ${l.title}"),
              backgroundColor: const Color(0xFF8B5CF6),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        _showError(res['error'] ?? "Failed to resolve stream URL for command.");
      }
    } catch (e) {
      if (isDialogShowing && mounted) {
        Navigator.pop(context);
        isDialogShowing = false;
      }
      _showError("Error: $e");
    }
  }

  // --- EXPORT COMPLETE BATCH .BAT FOR PC ---
  Future<void> _exportBatScript() async {
    if (_manifest == null) return;
    final List<LectureItem> selectedLectures = [];
    final List<NoteItem> selectedNotes = [];

    for (var s in _manifest!.subjects) {
      for (var t in s.topics) {
        selectedLectures.addAll(t.lectures.where((l) => l.isSelected));
        selectedNotes.addAll(t.notes.where((n) => n.isSelected));
      }
    }

    if (selectedLectures.isEmpty && selectedNotes.isEmpty) {
      _showError("No items selected to export.");
      return;
    }

    final batBuffer = StringBuffer();
    batBuffer.writeln("@echo off");
    batBuffer.writeln("chcp 65001 >nul");
    batBuffer.writeln("title Study Pro Bulk Downloader - ${_manifest!.name}");
    batBuffer.writeln("color 0b");
    batBuffer.writeln("echo =====================================================================");
    batBuffer.writeln("echo          Study Pro Bulk Downloader (Windows CMD Script)");
    batBuffer.writeln("echo          Batch: ${_manifest!.name}");
    batBuffer.writeln("echo          Selected Items: ${selectedLectures.length + selectedNotes.length}");
    batBuffer.writeln("echo =====================================================================");
    batBuffer.writeln("echo.");
    batBuffer.writeln('set "SAVE_DIR=%~dp0Downloads\\${_manifest!.name.replaceAll(RegExp(r'[\\/*?:"<>|]'), '')}"');
    batBuffer.writeln('if not exist "%SAVE_DIR%" mkdir "%SAVE_DIR%" 2>nul');
    batBuffer.writeln("echo Save Directory: %SAVE_DIR%");
    batBuffer.writeln("echo.");

    for (int i = 0; i < selectedLectures.length; i++) {
      final l = selectedLectures[i];
      final title = l.title.replaceAll(RegExp(r'[\\/*?:"<>|]'), '');
      batBuffer.writeln(":: [${i + 1}/${selectedLectures.length}] Video: $title");
      batBuffer.writeln('echo [${i + 1}/${selectedLectures.length}] Downloading: $title...');
      batBuffer.writeln('echo [NOTE] Run generate_bat.py or app.py on PC for full high-speed download.');
      batBuffer.writeln("echo.");
    }

    await Clipboard.setData(ClipboardData(text: batBuffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Windows .BAT template copied to clipboard!"),
        backgroundColor: Color(0xFF0284C7),
      ),
    );
  }
}
