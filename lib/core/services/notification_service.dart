import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Bildirim Servisini başlatır
  Future<void> init() async {
    if (_initialized) return;

    // 1. Saat Dilimlerini Yükle
    tz_data.initializeTimeZones();
    
    // 2. Yerel Saat Dilimini Ayarla
    try {
      final String timeZoneName = DateTime.now().timeZoneName;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      final int offsetInSeconds = DateTime.now().timeZoneOffset.inSeconds;
      final location = tz.Location('Local', [0], [0], [
        tz.TimeZone(offsetInSeconds, isDst: false, abbreviation: 'LOC')
      ]);
      tz.setLocalLocation(location);
    }

    // 3. Platform Ayarları
    const AndroidInitializationSettings initAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: initAndroid,
      iOS: initIOS,
    );

    await _notificationsPlugin.initialize(initSettings);

    // 4. İzin İste
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();

    _initialized = true;
    
    // 5. Günlük 04:00 Bildirimini Kur
    await scheduleDaily4AmNotification();
  }

  /// Her sabah 04:00'da tetiklenecek bildirim kurar
  Future<void> scheduleDaily4AmNotification() async {
    // Eski zamanlı bildirimleri temizle (Çakışmayı önle)
    try {
      await _notificationsPlugin.cancel(400);
    } catch (_) {}

    const androidDetails = AndroidNotificationDetails(
      'daily_horoscope_channel',
      'Günlük Yorumlar',
      channelDescription: 'Günlük sabah yorum bildirimleri',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final scheduledTime = _nextInstanceOfTime(4, 0); // Sabah 04:00

    await _notificationsPlugin.zonedSchedule(
      400,
      '🌌 Gökyüzü Yorumun Hazır! ✨',
      'Bugünün kozmik enerjileri ve burç yorumun seni bekliyor. Hemen oku!',
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // Her gün aynı saatte tekrarlar
    );
    
    debugPrint('🔔 Günlük 04:00 Bildirimi Zamanlandı: ${scheduledTime.toString()}');
  }

  /// Günlük sabah bildirimini iptal eder
  Future<void> cancelDailyNotification() async {
    try {
      await _notificationsPlugin.cancel(400);
      debugPrint('🔔 Günlük 04:00 Bildirimi İptal Edildi.');
    } catch (_) {}
  }

  /// Belirtilen saat ve dakika için bir sonraki zaman dilimini hesaplar
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
