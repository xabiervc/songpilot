import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/editor_screen.dart';
import 'screens/collab_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_screen.dart';

// TODO: replace with your real Supabase project URL and publishable key before
// running. Get these from your Supabase project settings.
const supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
const supabasePublishableKey = 'YOUR_ANON_KEY';

const _onboardingDoneKey = 'onboarding_done';

/// Whether the first-run introduction has been completed. Set in `main()`
/// before [runApp] so other screens can assume it is initialized.
late final bool onboardingDone;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  onboardingDone = prefs.getBool(_onboardingDoneKey) ?? false;

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );

  runApp(const ProviderScope(child: SongPilotApp()));
}

final supabase = Supabase.instance.client;

final GoRouter _router = GoRouter(
  initialLocation: onboardingDone ? '/home' : '/onboarding',
  redirect: (context, state) {
    final loggedIn = supabase.auth.currentSession != null;
    final loc = state.matchedLocation;

    if (!onboardingDone) {
      return loc == '/onboarding' ? null : '/onboarding';
    }
    if (loc == '/onboarding') {
      return loggedIn ? '/home' : '/auth';
    }
    if (!loggedIn && loc != '/auth') {
      return '/auth';
    }
    if (loggedIn && loc == '/auth') {
      return '/home';
    }
    return null;
  },
  routes: [
    GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen()),
    GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/editor/:projectId',
      builder: (context, state) => EditorScreen(
        projectId: state.pathParameters['projectId'] ?? 'new',
      ),
    ),
    GoRoute(
        path: '/collab', builder: (context, state) => const CollabScreen()),
    GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen()),
  ],
);

class SongPilotApp extends StatelessWidget {
  const SongPilotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SongPilot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFFFF6200),
        scaffoldBackgroundColor: const Color(0xFF0F1419),
      ),
      routerConfig: _router,
    );
  }
}
