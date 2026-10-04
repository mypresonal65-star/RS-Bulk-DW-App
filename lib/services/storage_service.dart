import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/user_session.dart';
import '../models/batch_model.dart';

class StorageService {
  static const String _keySession = "study_pro_enc_session";
  static const String _keyLastBatch = "study_pro_last_batch";

  // --- 1. GET UNIQUE HWID FOR ANDROID ---
  Future<String> getUniqueDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        String id = androidInfo.id;
        if (id.isNotEmpty) {
          return "MOB-${id.toUpperCase()}";
        }
      }
    } catch (_) {}
    return "MOB-${DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase()}";
  }

  // --- 2. PERSIST USER SESSION SAFELY ---
  Future<void> saveSession(UserSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(session.toJson());
    final encoded = base64Encode(utf8.encode(jsonStr));
    await prefs.setString(_keySession, encoded);
  }

  Future<UserSession?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_keySession);
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final decoded = utf8.decode(base64Decode(encoded));
      final map = jsonDecode(decoded);
      return UserSession.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySession);
  }

  // --- 3. REQUEST ALL REQUIRED STORAGE PERMISSIONS ---
  Future<bool> requestAllPermissions() async {
    if (Platform.isAndroid) {
      // Android 11+ (API 30+) All Files Access
      if (await Permission.manageExternalStorage.isRestricted ||
          !await Permission.manageExternalStorage.isGranted) {
        await Permission.manageExternalStorage.request();
      }

      await [
        Permission.storage,
        Permission.notification,
        Permission.mediaLibrary,
      ].request();

      return true;
    }
    return true;
  }

  // --- 4. GET DOWNLOAD FOLDER PATH ---
  Future<Directory> getDownloadDirectory() async {
    if (Platform.isAndroid) {
      final extDownload = Directory('/storage/emulated/0/Download/Study_Pro');
      if (!await extDownload.exists()) {
        try {
          await extDownload.create(recursive: true);
          return extDownload;
        } catch (_) {}
      } else {
        return extDownload;
      }
    }
    final appDir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory("${appDir.path}/Study_Pro_Downloads");
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return downloadDir;
  }

  // --- 5. PARSE BATCH MANIFEST JSON ---
  BatchManifest? parseManifestString(String rawJson) {
    try {
      final map = jsonDecode(rawJson);
      return BatchManifest.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheLastBatch(String rawJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastBatch, rawJson);
  }

  Future<BatchManifest?> loadLastBatch() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyLastBatch);
    if (raw == null) return null;
    return parseManifestString(raw);
  }
}
