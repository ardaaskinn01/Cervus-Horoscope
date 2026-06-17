import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/constants/app_theme.dart';
import 'core/providers/language_provider.dart';
import 'core/services/dashboard_service.dart';
import 'core/services/notification_service.dart';
import 'shared/router/app_router.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/services/ad_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('⚠️ .env dosyası yüklenemedi: $e');
  }
  
  // AdMob reklam motorunu başlat
  await AdService.instance.initialize();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Dashboard servisini gecikmeli başlat
    await DashboardService().init();
    
    // Bildirim motorunu başlat (04:00 zamanlaması dahil)
    await NotificationService().init();
  } catch (e) {
    debugPrint('⚠️ Firebase/Servis Başlatma Hatası (Çevrimdışı Demo Modu): $e');
  }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(languageProvider);

    return MaterialApp.router(
      title: 'Mistik Burçlar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      locale: locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr'),
        Locale('en'),
      ],
      routerConfig: AppRouter.router,
    );
  }
}
