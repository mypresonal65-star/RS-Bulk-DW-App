import 'package:flutter/material.dart';
import '../services/download_service.dart';

class DownloadScreen extends StatefulWidget {
  final DownloadService downloadService;

  const DownloadScreen({
    super.key,
    required this.downloadService,
  });

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  final ScrollController _logScrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    widget.downloadService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    widget.downloadService.removeListener(_onServiceUpdate);
    _logScrollController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (!mounted) return;
    if (_autoScroll && _logScrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_logScrollController.hasClients) {
          _logScrollController.animateTo(
            _logScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _confirmStop() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Text("Stop Download?", style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: const Text(
          "Are you sure you want to cancel remaining downloads? Any partially downloaded file will be cleaned up.",
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Keep Going", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.downloadService.cancelDownload();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text("Stop"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.downloadService,
      builder: (context, _) {
        final p = widget.downloadService.progress;
        final isDone = !p.isDownloading && p.totalCount > 0 && (p.completedCount == p.totalCount);

        return Scaffold(
          backgroundColor: const Color(0xFF080C16),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F172A),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Download Center",
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  p.isDownloading
                      ? (p.isPaused ? "Paused" : "Downloading in background...")
                      : (isDone ? "All Done! 🎉" : "Stopped"),
                  style: TextStyle(
                    color: isDone
                        ? const Color(0xFF10B981)
                        : (p.isPaused ? Colors.amber : const Color(0xFF38BDF8)),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            actions: [
              if (p.isDownloading)
                IconButton(
                  tooltip: p.isPaused ? "Resume" : "Pause",
                  icon: Icon(p.isPaused ? Icons.play_arrow : Icons.pause, color: Colors.white70),
                  onPressed: () => widget.downloadService.pauseDownload(),
                ),
              if (p.isDownloading)
                IconButton(
                  tooltip: "Stop",
                  icon: const Icon(Icons.stop_circle_outlined, color: Color(0xFFEF4444)),
                  onPressed: _confirmStop,
                ),
            ],
          ),
          body: Column(
            children: [
              // Overall Progress Card
              Container(
                margin: const EdgeInsets.all(14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withOpacity(0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Circular percentage indicator
                        SizedBox(
                          height: 60,
                          width: 60,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CircularProgressIndicator(
                                value: p.totalCount > 0 ? (p.completedCount / p.totalCount) : 0.0,
                                backgroundColor: Colors.white10,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isDone ? const Color(0xFF10B981) : const Color(0xFF0284C7),
                                ),
                                strokeWidth: 6,
                              ),
                              Center(
                                child: Text(
                                  "${p.overallProgress.toStringAsFixed(0)}%",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Queue: ${p.completedCount} of ${p.totalCount} completed",
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Saved to: Download/Study_Pro/",
                                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Telemetry Row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF090E1C),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem("Speed", p.speed, Icons.speed),
                          _buildDivider(),
                          _buildStatItem("Elapsed", p.elapsed, Icons.timer_outlined),
                          _buildDivider(),
                          _buildStatItem("Status", p.isPaused ? "PAUSED" : (p.isDownloading ? "ACTIVE" : "IDLE"), Icons.sync),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Current active item tile
              if (p.isDownloading && p.currentFile.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              p.currentFile,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            "${p.fileProgress.toStringAsFixed(0)}%",
                            style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: p.fileProgress / 100.0,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                          minHeight: 5,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              // Realtime Terminal Logs Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.terminal, color: Color(0xFF38BDF8), size: 16),
                    const SizedBox(width: 6),
                    const Text(
                      "Live Download Logs",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _autoScroll = !_autoScroll),
                      child: Row(
                        children: [
                          Icon(
                            _autoScroll ? Icons.check_box : Icons.check_box_outline_blank,
                            size: 14,
                            color: _autoScroll ? const Color(0xFF38BDF8) : Colors.white38,
                          ),
                          const SizedBox(width: 4),
                          const Text("Autoscroll", style: TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Terminal logs box
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF030712),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: ListView.builder(
                    controller: _logScrollController,
                    itemCount: p.logs.length,
                    itemBuilder: (context, index) {
                      final log = p.logs[index];
                      Color logColor = const Color(0xFF94A3B8);
                      if (log.contains("✅") || log.contains("Completed") || log.contains("🏁")) {
                        logColor = const Color(0xFF34D399);
                      } else if (log.contains("❌") || log.contains("Error") || log.contains("🛑")) {
                        logColor = const Color(0xFFF87171);
                      } else if (log.contains("🔑") || log.contains("✨")) {
                        logColor = const Color(0xFFFBBF24);
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          log,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: logColor,
                            fontSize: 10.5,
                            height: 1.3,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Bottom control button when finished
              if (isDone)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text("Done • Back to Syllabus"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: const Color(0xFF94A3B8)),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 24,
      color: Colors.white10,
    );
  }
}
