import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_session.dart';

class ApiService {
  static const String defaultCloudApiUrl = "https://rarestudy-api.mypresonal65.workers.dev";
  final String cloudApiUrl;
  
  Map<String, String> _headers = {};
  Map<String, String> _cookies = {};

  ApiService([String? url]) : cloudApiUrl = url ?? defaultCloudApiUrl;

  void updateHeadersAndCookies(Map<String, dynamic> config) {
    if (config['headers'] is Map) {
      _headers = Map<String, String>.from(
        (config['headers'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()))
      );
    }
    if (config['cookies'] is Map) {
      _cookies = Map<String, String>.from(
        (config['cookies'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()))
      );
    }
  }

  String get cookieHeaderString {
    return _cookies.entries.map((e) => "${e.key}=${e.value}").join("; ");
  }

  String get userAgent {
    return _headers['user-agent'] ?? 
      'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';
  }

  // --- 1. VERIFY LICENSE KEY ON CLOUDFLARE ---
  Future<Map<String, dynamic>> verifyLicenseKey({
    required String key,
    required String name,
    required String hwid,
  }) async {
    try {
      final res = await http.post(
        Uri.parse("$cloudApiUrl/api/verify"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "key": key.trim().toUpperCase(),
          "name": name.trim(),
          "hwid": hwid.trim(),
        }),
      ).timeout(const Duration(seconds: 12));

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        return {
          "success": true,
          "session": UserSession.fromJson(data),
        };
      } else {
        return {
          "success": false,
          "error": data['error'] ?? "Failed to activate license key.",
        };
      }
    } catch (e) {
      return {
        "success": false,
        "error": "Connection error: Could not reach Cloudflare API. ($e)",
      };
    }
  }

  // --- 2. CHECK SESSION ON APP STARTUP ---
  Future<Map<String, dynamic>> checkSession({
    String hwid = "",
    required String token,
  }) async {
    try {
      final res = await http.post(
        Uri.parse("$cloudApiUrl/api/check-session"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"hwid": hwid, "token": token}),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['valid'] == true) {
        return {
          "valid": true,
          "data": data,
        };
      } else {
        return {
          "valid": false,
          "error": data['error'] ?? "Session invalid or expired.",
        };
      }
    } catch (e) {
      return {
        "valid": false,
        "error": "Offline or connection timeout: $e",
      };
    }
  }

  // Helper checkSession with single string token
  Future<Map<String, dynamic>> checkSessionToken(String token, [String hwid = ""]) =>
      checkSession(token: token, hwid: hwid);

  // --- 3. FETCH CENTRALIZED HEADERS FROM CLOUD ---
  Future<bool> fetchRemoteHeaders() async {
    try {
      final res = await http.get(
        Uri.parse("$cloudApiUrl/api/headers"),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['headers_config'] != null) {
          updateHeadersAndCookies(data['headers_config']);
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  Future<bool> fetchCentralHeaders() => fetchRemoteHeaders();

  // --- 4. EXTRACT MEDIA TOKEN & DRM KEYS ---
  Future<Map<String, dynamic>> getVideoUrlDetails({
    required String batchId,
    required String subjectId,
    required String scheduleId,
  }) async {
    try {
      final step1Url = "https://rarestudy.testuk.org/schedule-details?batchId=$batchId&subjectId=$subjectId&scheduleId=$scheduleId&tap=video";
      final refererUrl = "https://rarestudy.testuk.org/stream?batchId=$batchId&subjectId=$subjectId";

      final headersMap = {
        "User-Agent": userAgent,
        "accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
        "referer": refererUrl,
        if (cookieHeaderString.isNotEmpty) "cookie": cookieHeaderString,
      };

      final step1Res = await http.get(Uri.parse(step1Url), headers: headersMap).timeout(const Duration(seconds: 15));
      
      final tokenMatch = RegExp(r'''MEDIA_TOKEN\s*=\s*["']([^"']+)["']''').firstMatch(step1Res.body);
      if (tokenMatch == null) {
        return {
          "success": false,
          "error": "MEDIA_TOKEN not found in HTML. Headers or cookies may be expired.",
        };
      }

      final mediaToken = tokenMatch.group(1);
      final step2Url = "https://rarestudy.testuk.org/v1/videos/video-url-details?mediaToken=$mediaToken&videoContainerType=DASH";

      final step2Headers = {
        "User-Agent": userAgent,
        "accept": "application/json,*/*",
        "referer": step1Url,
        if (cookieHeaderString.isNotEmpty) "cookie": cookieHeaderString,
      };

      final step2Res = await http.get(Uri.parse(step2Url), headers: step2Headers).timeout(const Duration(seconds: 15));
      final apiData = jsonDecode(step2Res.body);

      return apiData;
    } catch (e) {
      return {
        "success": false,
        "error": "Failed to resolve DRM details: $e",
      };
    }
  }

  // --- 5. PDF FALLBACK URL GENERATOR ---
  String getPdfDownloadUrl(String originalUrl) {
    if (originalUrl.isEmpty) return "";
    return "https://dragoapi.vercel.app/pdf/${Uri.encodeComponent(originalUrl)}";
  }
}
