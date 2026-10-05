package com.studypro.downloader

import android.annotation.SuppressLint
import android.app.Activity
import android.app.AlertDialog
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.pm.ActivityInfo
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import android.webkit.*
import android.widget.FrameLayout
import android.widget.Toast
import org.json.JSONArray
import org.json.JSONObject

class PlayerActivity : Activity() {
    private lateinit var webView: WebView
    private var isLandscape = false
    private var currentMpdUrl = ""
    private var currentTitle = ""
    private var currentKeys = arrayListOf<String>()

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Keep screen on while playing lectures
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        hideSystemUI()

        currentMpdUrl = intent.getStringExtra("mpdUrl") ?: ""
        currentTitle = intent.getStringExtra("title") ?: "Lecture Player"
        val subject = intent.getStringExtra("subject") ?: ""
        val batchName = intent.getStringExtra("batchName") ?: ""
        currentKeys = intent.getStringArrayListExtra("keys") ?: arrayListOf()
        val userAgent = intent.getStringExtra("userAgent") ?: ""
        val cookie = intent.getStringExtra("cookie") ?: ""
        val referer = intent.getStringExtra("referer") ?: "https://rarestudy.testuk.org/"

        webView = WebView(this).apply {
            setBackgroundColor(Color.BLACK)
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }

        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            mediaPlaybackRequiresUserGesture = false
            allowFileAccess = true
            allowContentAccess = true
            databaseEnabled = true
            setSupportMultipleWindows(false)
            if (userAgent.isNotEmpty()) {
                userAgentString = userAgent
            }
        }

        webView.webChromeClient = object : WebChromeClient() {
            override fun onConsoleMessage(consoleMessage: ConsoleMessage?): Boolean {
                return super.onConsoleMessage(consoleMessage)
            }
        }

        webView.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
                return false
            }
        }

        webView.addJavascriptInterface(PlayerBridge(this), "PlayerBridge")

        val html = buildPlayerHtml(currentMpdUrl, currentTitle, subject, batchName, currentKeys, referer)
        webView.loadDataWithBaseURL("https://rarestudy.testuk.org/", html, "text/html", "UTF-8", null)

        setContentView(webView)
    }

    private fun hideSystemUI() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.let { controller ->
                controller.hide(WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars())
                controller.systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_FULLSCREEN
            )
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            hideSystemUI()
        }
    }

    fun toggleOrientation() {
        runOnUiThread {
            isLandscape = !isLandscape
            requestedOrientation = if (isLandscape) {
                ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
            } else {
                ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
            }
        }
    }

    fun showDownloadDialog() {
        runOnUiThread {
            val options = arrayOf(
                "💻 Copy Windows .BAT Command (High-Speed PC Download)",
                "📋 Copy Stream Details (MPEG-DASH URL & Keys)",
                "ℹ️ Video Download Info"
            )

            AlertDialog.Builder(this, android.R.style.Theme_DeviceDefault_Dialog_Alert)
                .setTitle("Download Options")
                .setItems(options) { _, which ->
                    when (which) {
                        0 -> copyBatCommand()
                        1 -> copyStreamDetails()
                        2 -> showDownloadInfo()
                    }
                }
                .setNegativeButton("Close", null)
                .show()
        }
    }

    private fun copyBatCommand() {
        val sanitized = currentTitle.replace(Regex("""[\\/*?:"<>|]"""), "")
        val keyArgs = currentKeys.joinToString(" ") { "--key \"$it\"" }
        val cmd = "N_m3u8DL-RE \"$currentMpdUrl\" $keyArgs --select-video \"res=.*(720|1280).*:for=best\" --select-audio \"for=best\" --thread-count 32 --save-name \"$sanitized\" -M format=mp4:muxer=ffmpeg"

        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = ClipData.newPlainText("PC Download Command", cmd)
        clipboard.setPrimaryClip(clip)

        Toast.makeText(this, "PC .BAT Command copied to clipboard! Run on laptop to download full MP4.", Toast.LENGTH_LONG).show()
    }

    private fun copyStreamDetails() {
        val details = "Video: $currentTitle\nMPD URL: $currentMpdUrl\nKeys: ${currentKeys.joinToString(", ")}"
        val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = ClipData.newPlainText("Stream Details", details)
        clipboard.setPrimaryClip(clip)

        Toast.makeText(this, "Stream details copied to clipboard!", Toast.LENGTH_SHORT).show()
    }

    private fun showDownloadInfo() {
        AlertDialog.Builder(this, android.R.style.Theme_DeviceDefault_Dialog_Alert)
            .setTitle("Mobile Video Playback & Download")
            .setMessage("Protected DASH streams are securely decoded in real-time inside this In-App Player with full HD quality, seeking, and speed controls.\n\nAndroid operating system security restricts external decryption executables from saving raw MP4s directly into phone storage without root.\n\nTo save clear MP4 videos for permanent offline backup, use the 'Copy Windows .BAT Command' option to download on any laptop/PC at 32-64 parallel thread speed.")
            .setPositiveButton("OK", null)
            .show()
    }

    override fun onDestroy() {
        webView.destroy()
        super.onDestroy()
    }

    private fun buildPlayerHtml(
        mpdUrl: String,
        title: String,
        subject: String,
        batchName: String,
        keys: ArrayList<String>,
        referer: String
    ): String {
        val keysJson = JSONArray(keys).toString()
        val safeTitle = JSONObject.quote(title)
        val safeSubject = JSONObject.quote(subject)
        val safeBatch = JSONObject.quote(batchName)
        val safeMpdUrl = JSONObject.quote(mpdUrl)
        val safeReferer = JSONObject.quote(referer)

        return """
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>Study Pro Player</title>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/shaka-player/4.3.5/shaka-player.compiled.js"></script>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; user-select: none; -webkit-user-select: none; }
    body, html { width: 100%; height: 100%; background: #000; overflow: hidden; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
    #player-container { position: relative; width: 100%; height: 100%; display: flex; align-items: center; justify-content: center; background: #000; }
    video { width: 100%; height: 100%; object-fit: contain; }

    /* Top Bar */
    .top-bar {
      position: absolute; top: 0; left: 0; right: 0;
      padding: 16px 20px;
      background: linear-gradient(to bottom, rgba(0,0,0,0.88), transparent);
      display: flex; align-items: center; justify-content: space-between;
      z-index: 20;
      transition: opacity 0.3s ease;
    }
    .back-btn {
      background: rgba(255,255,255,0.18); border: none; color: #fff;
      font-size: 20px; width: 40px; height: 40px; border-radius: 50%;
      display: flex; align-items: center; justify-content: center; cursor: pointer;
    }
    .title-box { flex: 1; margin: 0 16px; overflow: hidden; }
    .video-title { color: #fff; font-size: 15px; font-weight: 700; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .video-subtitle { color: #94a3b8; font-size: 11px; margin-top: 2px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

    .download-btn {
      background: linear-gradient(135deg, #10b981, #059669);
      border: none; color: #fff; font-size: 12px; font-weight: 700;
      padding: 8px 16px; border-radius: 20px; display: flex; align-items: center;
      gap: 6px; cursor: pointer; box-shadow: 0 4px 14px rgba(16,185,129,0.35);
    }

    /* Bottom Controls */
    .bottom-bar {
      position: absolute; bottom: 0; left: 0; right: 0;
      padding: 16px 20px;
      background: linear-gradient(to top, rgba(0,0,0,0.92), transparent);
      display: flex; flex-direction: column; gap: 8px;
      z-index: 20;
      transition: opacity 0.3s ease;
    }
    .progress-container {
      width: 100%; height: 22px; display: flex; align-items: center; cursor: pointer;
    }
    .progress-bar {
      position: relative; width: 100%; height: 5px; background: rgba(255,255,255,0.25);
      border-radius: 3px;
    }
    .progress-buffer {
      position: absolute; left: 0; top: 0; height: 100%; width: 0%;
      background: rgba(255,255,255,0.45); border-radius: 3px;
    }
    .progress-filled {
      position: absolute; left: 0; top: 0; height: 100%; width: 0%;
      background: #0284c7; border-radius: 3px;
    }
    .progress-scrubber {
      position: absolute; top: -5px; right: -7px; width: 15px; height: 15px;
      background: #38bdf8; border-radius: 50%; box-shadow: 0 0 10px #0284c7;
    }

    .controls-row {
      display: flex; align-items: center; justify-content: space-between;
    }
    .left-controls, .right-controls {
      display: flex; align-items: center; gap: 14px;
    }
    .icon-btn {
      background: transparent; border: none; color: #fff; font-size: 20px;
      display: flex; align-items: center; justify-content: center; cursor: pointer;
    }
    .time-text { color: #cbd5e1; font-size: 12px; font-weight: 500; font-variant-numeric: tabular-nums; }
    .badge-btn {
      background: rgba(255,255,255,0.15); border: 1px solid rgba(255,255,255,0.25);
      color: #fff; font-size: 11px; font-weight: 700; padding: 4px 10px;
      border-radius: 6px; cursor: pointer;
    }

    /* Center Overlay */
    .center-overlay {
      position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%);
      display: flex; align-items: center; gap: 40px; z-index: 15;
      pointer-events: none;
    }
    .big-btn {
      width: 58px; height: 58px; border-radius: 50%;
      background: rgba(0,0,0,0.65); border: 2px solid rgba(255,255,255,0.35);
      color: #fff; font-size: 28px; display: flex; align-items: center;
      justify-content: center; pointer-events: auto; cursor: pointer;
    }

    /* Spinner */
    .spinner {
      position: absolute; width: 54px; height: 54px;
      border: 4px solid rgba(255,255,255,0.2); border-top-color: #38bdf8;
      border-radius: 50%; animation: spin 1s infinite linear;
      z-index: 10; display: block;
    }
    @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }

    /* Touch Tap zones for 10s skip */
    .tap-zone {
      position: absolute; top: 0; bottom: 0; width: 35%; z-index: 5;
    }
    .tap-left { left: 0; }
    .tap-right { right: 0; }

    /* Controls Fade */
    .controls-fade { opacity: 1; transition: opacity 0.3s ease; }
    .controls-hide { opacity: 0; pointer-events: none; }

    /* Error Banner */
    #error-banner {
      position: absolute; top: 70px; left: 20px; right: 20px;
      background: rgba(225, 29, 72, 0.9); color: #fff; padding: 12px 16px;
      border-radius: 8px; font-size: 13px; z-index: 30; display: none;
    }
  </style>
</head>
<body>
  <div id="player-container">
    <video id="video" playsinline></video>
    <div id="spinner" class="spinner"></div>

    <div id="error-banner"></div>

    <!-- Tap zones -->
    <div class="tap-zone tap-left" id="tap-left"></div>
    <div class="tap-zone tap-right" id="tap-right"></div>

    <!-- Top Bar -->
    <div class="top-bar controls-fade" id="top-bar">
      <button class="back-btn" onclick="PlayerBridge.closePlayer()">&#10005;</button>
      <div class="title-box">
        <div class="video-title" id="ui-title"></div>
        <div class="video-subtitle" id="ui-subtitle"></div>
      </div>
      <button class="download-btn" onclick="PlayerBridge.onDownloadClicked()">
        <span>&#11015;</span> Download
      </button>
    </div>

    <!-- Center Overlay -->
    <div class="center-overlay controls-fade" id="center-overlay">
      <button class="big-btn" onclick="skipTime(-10)">&#8634; 10</button>
      <button class="big-btn" id="center-play-btn" onclick="togglePlay()">&#9658;</button>
      <button class="big-btn" onclick="skipTime(10)">10 &#8635;</button>
    </div>

    <!-- Bottom Controls -->
    <div class="bottom-bar controls-fade" id="bottom-bar">
      <div class="progress-container" id="progress-container">
        <div class="progress-bar">
          <div class="progress-buffer" id="progress-buffer"></div>
          <div class="progress-filled" id="progress-filled">
            <div class="progress-scrubber"></div>
          </div>
        </div>
      </div>

      <div class="controls-row">
        <div class="left-controls">
          <button class="icon-btn" id="bottom-play-btn" onclick="togglePlay()">&#9658;</button>
          <div class="time-text"><span id="time-current">00:00</span> / <span id="time-duration">00:00</span></div>
        </div>
        <div class="right-controls">
          <button class="badge-btn" id="speed-btn" onclick="cycleSpeed()">1.0x</button>
          <button class="badge-btn" id="quality-btn" onclick="cycleQuality()">Auto</button>
          <button class="icon-btn" onclick="PlayerBridge.toggleOrientation()">&#x26F6;</button>
        </div>
      </div>
    </div>
  </div>

  <script>
    const mpdUrl = $safeMpdUrl;
    const lectureTitle = $safeTitle;
    const subjectName = $safeSubject;
    const batchTitle = $safeBatch;
    const rawKeys = $keysJson;
    const referer = $safeReferer;

    document.getElementById('ui-title').innerText = lectureTitle;
    document.getElementById('ui-subtitle').innerText = subjectName + (batchTitle ? " • " + batchTitle : "");

    const video = document.getElementById('video');
    const spinner = document.getElementById('spinner');
    const centerPlayBtn = document.getElementById('center-play-btn');
    const bottomPlayBtn = document.getElementById('bottom-play-btn');
    const progressFilled = document.getElementById('progress-filled');
    const progressBuffer = document.getElementById('progress-buffer');
    const timeCurrent = document.getElementById('time-current');
    const timeDuration = document.getElementById('time-duration');
    const speedBtn = document.getElementById('speed-btn');
    const qualityBtn = document.getElementById('quality-btn');

    let controlsVisible = true;
    let hideTimer = null;
    let availableTracks = [];
    let currentTrackIdx = -1;

    function formatTime(sec) {
      if (isNaN(sec) || sec < 0) return "00:00";
      const h = Math.floor(sec / 3600);
      const m = Math.floor((sec % 3600) / 60);
      const s = Math.floor(sec % 60);
      if (h > 0) {
        return h + ":" + (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
      }
      return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    function togglePlay() {
      if (video.paused) {
        video.play();
      } else {
        video.pause();
      }
      resetHideTimer();
    }

    function skipTime(delta) {
      video.currentTime = Math.max(0, Math.min(video.duration || 0, video.currentTime + delta));
      resetHideTimer();
    }

    const speeds = [1.0, 1.25, 1.5, 1.75, 2.0, 0.75];
    let speedIdx = 0;
    function cycleSpeed() {
      speedIdx = (speedIdx + 1) % speeds.length;
      const spd = speeds[speedIdx];
      video.playbackRate = spd;
      speedBtn.innerText = spd + "x";
      resetHideTimer();
    }

    function cycleQuality() {
      if (!window.player || availableTracks.length === 0) return;
      currentTrackIdx = (currentTrackIdx + 1) % (availableTracks.length + 1);
      if (currentTrackIdx === availableTracks.length) {
        window.player.configure({abr: {enabled: true}});
        qualityBtn.innerText = "Auto";
      } else {
        const track = availableTracks[currentTrackIdx];
        window.player.configure({abr: {enabled: false}});
        window.player.selectVariantTrack(track, true);
        qualityBtn.innerText = (track.height ? track.height + "p" : "Manual");
      }
      resetHideTimer();
    }

    function resetHideTimer() {
      showControls();
      clearTimeout(hideTimer);
      if (!video.paused) {
        hideTimer = setTimeout(hideControls, 3500);
      }
    }

    function showControls() {
      controlsVisible = true;
      document.querySelectorAll('.controls-fade').forEach(el => el.classList.remove('controls-hide'));
    }

    function hideControls() {
      if (video.paused) return;
      controlsVisible = false;
      document.querySelectorAll('.controls-fade').forEach(el => el.classList.add('controls-hide'));
    }

    document.getElementById('player-container').addEventListener('click', (e) => {
      if (e.target.closest('button') || e.target.closest('#progress-container')) return;
      if (controlsVisible) {
        hideControls();
      } else {
        showControls();
        resetHideTimer();
      }
    });

    // Double tap skip
    let lastTapLeft = 0;
    document.getElementById('tap-left').addEventListener('click', () => {
      const now = Date.now();
      if (now - lastTapLeft < 300) {
        skipTime(-10);
      }
      lastTapLeft = now;
    });

    let lastTapRight = 0;
    document.getElementById('tap-right').addEventListener('click', () => {
      const now = Date.now();
      if (now - lastTapRight < 300) {
        skipTime(10);
      }
      lastTapRight = now;
    });

    // Scrubber click
    document.getElementById('progress-container').addEventListener('click', (e) => {
      const rect = e.currentTarget.getBoundingClientRect();
      const pos = (e.clientX - rect.left) / rect.width;
      if (video.duration) {
        video.currentTime = pos * video.duration;
      }
      resetHideTimer();
    });

    video.addEventListener('play', () => {
      centerPlayBtn.innerHTML = "&#10074;&#10074;";
      bottomPlayBtn.innerHTML = "&#10074;&#10074;";
      resetHideTimer();
    });

    video.addEventListener('pause', () => {
      centerPlayBtn.innerHTML = "&#9658;";
      bottomPlayBtn.innerHTML = "&#9658;";
      showControls();
      clearTimeout(hideTimer);
    });

    video.addEventListener('waiting', () => {
      spinner.style.display = 'block';
    });

    video.addEventListener('playing', () => {
      spinner.style.display = 'none';
    });

    video.addEventListener('timeupdate', () => {
      if (video.duration) {
        const perc = (video.currentTime / video.duration) * 100;
        progressFilled.style.width = perc + "%";
        timeCurrent.innerText = formatTime(video.currentTime);
        timeDuration.innerText = formatTime(video.duration);

        if (video.buffered.length > 0) {
          const bufEnd = video.buffered.end(video.buffered.length - 1);
          progressBuffer.style.width = ((bufEnd / video.duration) * 100) + "%";
        }
      }
    });

    function showError(msg) {
      spinner.style.display = 'none';
      const b = document.getElementById('error-banner');
      b.style.display = 'block';
      b.innerText = msg;
    }

    async function initShaka() {
      shaka.polyfill.installAll();
      if (!shaka.Player.isBrowserSupported()) {
        showError("MSE / ClearKey DRM is not supported on this device.");
        return;
      }

      const player = new shaka.Player(video);
      window.player = player;

      // ClearKey mapping
      const clearKeysMap = {};
      if (Array.isArray(rawKeys)) {
        rawKeys.forEach(k => {
          const p = k.split(':');
          if (p.length === 2) {
            clearKeysMap[p[0].trim()] = p[1].trim();
          }
        });
      }

      const config = {
        streaming: {
          bufferingGoal: 20,
          rebufferingGoal: 2,
          bufferBehind: 30
        }
      };

      if (Object.keys(clearKeysMap).length > 0) {
        config.drm = { clearKeys: clearKeysMap };
      }

      player.configure(config);

      player.getNetworkingEngine().registerRequestFilter((type, request) => {
        request.headers['Origin'] = 'https://rarestudy.testuk.org';
        if (referer) request.headers['Referer'] = referer;
      });

      player.addEventListener('error', (e) => {
        console.error('Shaka player error:', e.detail);
        showError("Stream error: " + (e.detail?.message || "Buffering issue"));
      });

      try {
        await player.load(mpdUrl);
        spinner.style.display = 'none';
        video.play().catch(() => {});
        availableTracks = player.getVariantTracks().filter(t => t.videoId != null);
      } catch (e) {
        console.error("Load failed:", e);
        showError("Failed to load stream: " + e.message);
      }
    }

    document.addEventListener('DOMContentLoaded', initShaka);
  </script>
</body>
</html>
        """.trimIndent()
    }

    class PlayerBridge(private val activity: PlayerActivity) {
        @JavascriptInterface
        fun closePlayer() {
            activity.finish()
        }

        @JavascriptInterface
        fun toggleOrientation() {
            activity.toggleOrientation()
        }

        @JavascriptInterface
        fun onDownloadClicked() {
            activity.showDownloadDialog()
        }
    }
}
