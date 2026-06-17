import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static final AdService instance = AdService._();
  AdService._();

  bool _isInitialized = false;

  // Configuration IDs
  static const String androidAppId = 'ca-app-pub-2073707860224174~9069029162';
  static const String iosAppId = 'ca-app-pub-2073707860224174~4694669882';

  // Android Test Fallbacks
  static const String androidTestBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const String androidTestRewarded = 'ca-app-pub-3940256099942544/5224354917';

  // iOS Test Fallbacks
  static const String iosTestBanner = 'ca-app-pub-3940256099942544/2934735716';
  static const String iosTestRewarded = 'ca-app-pub-3940256099942544/1712485313';

  // Placements configuration
  // Maps location tag -> Android ID / iOS ID
  final Map<String, Map<String, String>> _adUnits = {
    'home_banner': {
      'android': 'ca-app-pub-2073707860224174/3816702485',
      'ios': 'ca-app-pub-2073707860224174/3105085186',
    },
    'tools_banner': {
      'android': 'ca-app-pub-2073707860224174/2450479064',
      'ios': 'ca-app-pub-2073707860224174/1792003518',
    },
    'comment_banner': {
      'android': 'ca-app-pub-2073707860224174/1983575203',
      'ios': 'ca-app-pub-2073707860224174/8701321948',
    },
    'chart_banner': {
      'android': 'ca-app-pub-2073707860224174/1983575203',
      'ios': 'ca-app-pub-2073707860224174/8701321948',
    },
    'cosmic_oracle_banner': {
      'android': 'ca-app-pub-2073707860224174/1983575203',
      'ios': 'ca-app-pub-2073707860224174/8701321948',
    },
    'love_compatibility_banner': {
      'android': 'ca-app-pub-2073707860224174/1983575203',
      'ios': 'ca-app-pub-2073707860224174/8701321948',
    },
    'friend_compatibility_banner': {
      'android': 'ca-app-pub-2073707860224174/1983575203',
      'ios': 'ca-app-pub-2073707860224174/8701321948',
    },
    'partner_chart_banner': {
      'android': 'ca-app-pub-2073707860224174/1983575203',
      'ios': 'ca-app-pub-2073707860224174/8701321948',
    },
    'numerology_banner': {
      'android': 'ca-app-pub-2073707860224174/1983575203',
      'ios': 'ca-app-pub-2073707860224174/8701321948',
    },
    'partner_numerology_banner': {
      'android': 'ca-app-pub-2073707860224174/1983575203',
      'ios': 'ca-app-pub-2073707860224174/8701321948',
    },
    'who_am_i_banner': {
      'android': 'ca-app-pub-2073707860224174/1983575203',
      'ios': 'ca-app-pub-2073707860224174/8701321948',
    },
    'cosmic_oracle_rewarded': {
      'android': 'ca-app-pub-2073707860224174/8357411862',
      'ios': 'ca-app-pub-2073707860224174/8165840172',
    },
    'ai_tools_rewarded': {
      'android': 'ca-app-pub-2073707860224174/1190539142',
      'ios': 'ca-app-pub-2073707860224174/9998967459',
    },
  };

  String _getBannerAdUnitId(String placement) {
    if (kDebugMode) {
      return defaultTargetPlatform == TargetPlatform.iOS ? iosTestBanner : androidTestBanner;
    }
    final units = _adUnits[placement];
    if (units == null) {
      return defaultTargetPlatform == TargetPlatform.iOS ? iosTestBanner : androidTestBanner;
    }
    return defaultTargetPlatform == TargetPlatform.iOS
        ? (units['ios'] ?? iosTestBanner)
        : (units['android'] ?? androidTestBanner);
  }

  String _getRewardedAdUnitId(String placement) {
    if (kDebugMode) {
      return defaultTargetPlatform == TargetPlatform.iOS ? iosTestRewarded : androidTestRewarded;
    }
    final units = _adUnits[placement];
    if (units == null) {
      return defaultTargetPlatform == TargetPlatform.iOS ? iosTestRewarded : androidTestRewarded;
    }
    return defaultTargetPlatform == TargetPlatform.iOS
        ? (units['ios'] ?? iosTestRewarded)
        : (units['android'] ?? androidTestRewarded);
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      debugPrint('✅ Google Mobile Ads SDK initialized.');
    } catch (e) {
      debugPrint('⚠️ Google Mobile Ads SDK initialization error: $e');
    }
  }

  // Banner Widget Builder
  Widget getBannerAdWidget(String placement, {bool isPremium = false}) {
    if (isPremium) {
      return const SizedBox.shrink();
    }
    return BannerAdContainer(adUnitId: _getBannerAdUnitId(placement));
  }

  // Rewarded Ad helper
  void showRewardedAd({
    required String placement,
    required BuildContext context,
    required VoidCallback onRewardEarned,
    bool isPremium = false,
  }) {
    if (isPremium) {
      // If user is premium, trigger the action immediately without playing ads
      onRewardEarned();
      return;
    }

    final adUnitId = _getRewardedAdUnitId(placement);
    
    // Show a loading dialog first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
        ),
      ),
    );

    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          // Close the loading dialog
          Navigator.of(context).pop();
          
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              // Ad failed to show, fallback gracefully to trigger reward
              onRewardEarned();
            },
          );

          ad.show(
            onUserEarnedReward: (adWithoutPersonalizedAds, reward) {
              onRewardEarned();
            },
          );
        },
        onAdFailedToLoad: (error) {
          // Close the loading dialog
          Navigator.of(context).pop();
          debugPrint('⚠️ RewardedAd failed to load: $error');
          // Fallback: trigger reward immediately during test/failure
          onRewardEarned();
        },
      ),
    );
  }
}

// Banner Container Widget
class BannerAdContainer extends StatefulWidget {
  final String adUnitId;
  const BannerAdContainer({super.key, required this.adUnitId});

  @override
  State<BannerAdContainer> createState() => _BannerAdContainerState();
}

class _BannerAdContainerState extends State<BannerAdContainer> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: widget.adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('⚠️ BannerAd failed to load: $error');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }
    return Container(
      alignment: Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
