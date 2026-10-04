import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
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
              padding: const EdgeInsets.all(14),
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
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          "$selectedVideosCount videos, $selectedNotesCount notes",
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        ),
                      ],
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _startSelectedDownloads,
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text("Download Now"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            ...topic.lectures.map((l) => CheckboxListTile(
                  value: l.isSelected,
                  onChanged: (val) => setState(() => l.isSelected = val ?? false),
                  title: Text(l.title, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  secondary: const Icon(Icons.play_circle_fill, color: Color(0xFF38BDF8), size: 20),
                  activeColor: const Color(0xFF0284C7),
                  dense: true,
                )),
          if (showNotes)
            ...topic.notes.map((n) => CheckboxListTile(
                  value: n.isSelected,
                  onChanged: (val) => setState(() => n.isSelected = val ?? false),
                  title: Text(n.name, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  secondary: const Icon(Icons.picture_as_pdf, color: Color(0xFFF43F5E), size: 20),
                  activeColor: const Color(0xFF0284C7),
                  dense: true,
                )),
        ],
      ),
    );
  }
}
