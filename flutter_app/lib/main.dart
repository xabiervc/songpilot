import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/editor_screen.dart';
import 'screens/collab_screen.dart';
import 'screens/profile_screen.dart';

// TODO: replace with your real Supabase project URL and anon key before
// running. Get these from your Supabase project settings.
const supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
const supabaseAnonKey = 'YOUR_ANON_KEY';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  runApp(const ProviderScope(child: SongPilotApp()));
}

final supabase = Supabase.instance.client;

final GoRouter _router = GoRouter(
  initialLocation: '/auth',
  redirect: (context, state) {
    final loggedIn = supabase.auth.currentSession != null;
    final goingToAuth = state.matchedLocation == '/auth';

    if (!loggedIn && !goingToAuth) return '/auth';
    if (loggedIn && goingToAuth) return '/home';
    return null;
  },
  routes: [
    GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/editor/:projectId',
      builder: (context, state) => EditorScreen(
        projectId: state.pathParameters['projectId'] ?? 'new',
      ),
    ),
    GoRoute(path: '/collab', builder: (context, state) => const CollabScreen()),
    GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
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
