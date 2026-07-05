import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:horoscope/features/splash/splash_screen.dart';
import 'package:horoscope/features/onboarding/onboarding_screen.dart';
import 'package:horoscope/features/home/main_view.dart';
import 'package:horoscope/features/love_compatibility/love_compatibility_screen.dart';
import 'package:horoscope/features/friend_compatibility/friend_compatibility_screen.dart';
import 'package:horoscope/features/best_matches/best_matches_screen.dart';
import 'package:horoscope/features/tools/moon_phases/moon_phases_screen.dart';
import 'package:horoscope/features/tools/astro_calendar/astro_calendar_screen.dart';
import 'package:horoscope/features/tools/retrograde/retrograde_screen.dart';
import 'package:horoscope/features/tools/numerology/numerology_screen.dart';
import 'package:horoscope/features/tools/numerology/partner_numerology_screen.dart';
import 'package:horoscope/features/tools/partner_natal_chart/partner_natal_chart_screen.dart';
import 'package:horoscope/features/tools/cosmic_oracle/cosmic_oracle_screen.dart';
import 'package:horoscope/features/tools/cosmic_orb/cosmic_orb_screen.dart';
import 'package:horoscope/features/tarot/tarot_screen.dart';

class AppRouter {
  AppRouter._();

  static Page<dynamic> _buildPageWithTransition(GoRouterState state, Widget child) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.04), // Subtle slide up
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  static final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      // Splash
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => _buildPageWithTransition(state, const SplashScreen()),
      ),
      // Onboarding
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => _buildPageWithTransition(state, const OnboardingScreen()),
      ),
      // Home (Main Navigation view)
      GoRoute(
        path: '/home',
        pageBuilder: (context, state) => _buildPageWithTransition(state, const MainView()),
      ),
      // Love Compatibility
      GoRoute(
        path: '/love-compatibility',
        pageBuilder: (context, state) => _buildPageWithTransition(state, const LoveCompatibilityScreen()),
      ),
      // Friend Compatibility
      GoRoute(
        path: '/friend-compatibility',
        pageBuilder: (context, state) => _buildPageWithTransition(state, const FriendCompatibilityScreen()),
      ),
      // Best Matches
      GoRoute(
        path: '/best-matches',
        pageBuilder: (context, state) => _buildPageWithTransition(state, const BestMatchesScreen()),
      ),
      // Moon Phases
      GoRoute(
        path: '/moon-phases',
        pageBuilder: (context, state) => _buildPageWithTransition(state, const MoonPhasesScreen()),
      ),
      // Astro Calendar
      GoRoute(
        path: '/astro-calendar',
        pageBuilder: (context, state) => _buildPageWithTransition(state, const AstroCalendarScreen()),
      ),
      // Retrogrades
      GoRoute(
        path: '/retrograde',
        pageBuilder: (context, state) => _buildPageWithTransition(state, const RetrogradeScreen()),
      ),
      // Numerology
      GoRoute(
        path: '/numerology',
        pageBuilder: (context, state) => _buildPageWithTransition(state, const NumerologyScreen()),
      ),
      // Partner Numerology
      GoRoute(
        path: '/partner-numerology',
        pageBuilder: (context, state) => _buildPageWithTransition(state, const PartnerNumerologyScreen()),
      ),
      // Partner Natal Chart
      GoRoute(
        path: '/partner-natal-chart',
        pageBuilder: (context, state) => _buildPageWithTransition(state, const PartnerNatalChartScreen()),
      ),
      // Cosmic Oracle
      GoRoute(
        path: '/cosmic-oracle',
        pageBuilder: (context, state) => _buildPageWithTransition(state, const CosmicOracleScreen()),
      ),
      // Tarot
      GoRoute(
        path: '/tarot',
        pageBuilder: (context, state) => _buildPageWithTransition(state, const TarotScreen()),
      ),
      // Cosmic Orb
      GoRoute(
        path: '/cosmic-orb',
        pageBuilder: (context, state) => _buildPageWithTransition(state, const CosmicOrbScreen()),
      ),
    ],
  );
}
