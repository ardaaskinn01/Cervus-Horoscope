import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

/// 🚀 DASHBOARD SERVICE (REST EDITION)
/// Bu servis, ikincil Firebase projesine Flutter SDK'si yerine doğrudan Google Cloud REST API
/// üzerinden bağlanır. Böylece SDK çakışmaları ve iOS tarafındaki çökme riskleri önlenir.
class DashboardService with WidgetsBindingObserver {
  static final DashboardService _instance = DashboardService._internal();
  factory DashboardService() => _instance;
  DashboardService._internal();

  bool _isInitialized = false;
  
  // TODO: Replace with real Dashboard Firebase Project ID if needed
  final String _projectId = "dashboard-baf3f";
  
  // Oturum takibi değişkenleri
  DateTime? _sessionStartTime;
  String? _currentUserId;
  String? _currentVisitId;
  int _totalSecondsThisSession = 0;
  Timer? _heartbeatTimer;

  Future<void> init() async {
    if (_isInitialized) return;
    
    // UI thread'i engellememek için hafif gecikmeli başlatılır
    await Future.delayed(const Duration(seconds: 2));
    
    _isInitialized = true;
    WidgetsBinding.instance.addObserver(this);
    debugPrint('✅ Dashboard REST API Servisi Hazır (ID: $_projectId)');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _stopHeartbeat();
      _updateCurrentSessionDuration();
    } else if (state == AppLifecycleState.resumed) {
      _sessionStartTime = DateTime.now();
      _startHeartbeat();
    }
  }

  // Ziyaret oturumunu başlatır
  void startSession(String userId, String visitId) {
    _currentUserId = userId;
    _currentVisitId = visitId;
    _sessionStartTime = DateTime.now();
    _totalSecondsThisSession = 0;
    _startHeartbeat();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _updateCurrentSessionDuration();
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Firestore REST API üzerinden süre verisini günceller
  Future<void> _updateCurrentSessionDuration() async {
    if (_currentUserId == null || _currentVisitId == null || _sessionStartTime == null) return;

    final now = DateTime.now();
    final int elapsedSeconds = now.difference(_sessionStartTime!).inSeconds;
    
    if (elapsedSeconds > 0) {
      _totalSecondsThisSession += elapsedSeconds;
      _sessionStartTime = now;
    }

    final String url = "https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/users/$_currentUserId/visits/$_currentVisitId?updateMask.fieldPaths=durationSeconds&updateMask.fieldPaths=lastUpdate";

    try {
      final response = await http.patch(
        Uri.parse(url),
        body: jsonEncode({
          "fields": {
            "durationSeconds": {"integerValue": _totalSecondsThisSession.toString()},
            "lastUpdate": {"timestampValue": DateTime.now().toUtc().toIso8601String()}
          }
        }),
      );
      if (response.statusCode == 200) {
        debugPrint('📈 Dashboard Session Duration Updated: $_totalSecondsThisSession s');
      }
    } catch (e) {
      debugPrint('⚠️ Dashboard REST Süre Güncelleme Hatası: $e');
    }
  }

  /// Firestore REST API üzerinden kullanıcı kaydı oluşturur/günceller
  Future<void> syncExistingUser(String userId, Map<String, dynamic> userData) async {
    try {
      final String url = "https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/users/$userId";
      
      // Önce kullanıcının varlığını kontrol et
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 404) {
        // Kullanıcı yoksa oluştur
        await http.patch(
          Uri.parse(url),
          body: jsonEncode({
            "fields": {
              "originalName": {"stringValue": userData['name'] ?? "Anonymous"},
              "gender": {"stringValue": userData['gender'] ?? ""},
              "platform": {"stringValue": Platform.isIOS ? 'iOS' : 'Android'},
              "appId": {"stringValue": 'horoscope'},
              "isMigrated": {"booleanValue": true},
              "migratedAt": {"timestampValue": DateTime.now().toUtc().toIso8601String()},
              "createdAt": {"timestampValue": DateTime.now().toUtc().toIso8601String()},
            }
          }),
        );
        debugPrint('✅ Yeni kullanıcı Dashboard REST API ile kaydedildi.');
      }
    } catch (e) {
      debugPrint('⚠️ Dashboard REST Kullanıcı Eşitleme Hatası: $e');
    }
  }

  /// Dashboard projesine doğrudan ziyaret kaydı atar
  Future<void> logVisit({
    required String userId,
    required String visitId,
    required String appVersion,
    required String platform,
    required String time,
    required String date,
  }) async {
    final String url = "https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents/users/$userId/visits/$visitId";

    try {
      final response = await http.patch(
        Uri.parse(url),
        body: jsonEncode({
          "fields": {
            "appVersion": {"stringValue": appVersion},
            "platform": {"stringValue": platform},
            "time": {"stringValue": time},
            "date": {"stringValue": date},
            "appId": {"stringValue": 'horoscope'},
            "timestamp": {"timestampValue": DateTime.now().toUtc().toIso8601String()},
          }
        }),
      );
      if (response.statusCode == 200) {
        debugPrint('✅ Dashboard Visit Logged successfully for: $userId');
      }
    } catch (e) {
      debugPrint('⚠️ Dashboard REST Ziyaret Kayıt Hatası: $e');
    }
  }
}
