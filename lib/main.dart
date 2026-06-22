// lib/main.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/eval_screen.dart';
import 'screens/create_screen.dart';
import 'screens/feedback_screen.dart';
import 'screens/mypage_screen.dart';
import 'widgets/bottom_navigation.dart';
import 'widgets/desktop_device_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase Client
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  } catch (e) {
    debugPrint('Supabase initialization failed: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Future City',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const DesktopDeviceWrapper(
        child: AuthStateGate(),
      ),
    );
  }
}

class AuthStateGate extends StatefulWidget {
  const AuthStateGate({super.key});

  @override
  State<AuthStateGate> createState() => _AuthStateGateState();
}

class _AuthStateGateState extends State<AuthStateGate> {
  User? _user;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
    SupabaseService.onAuthStateChange.listen((data) {
      if (mounted) {
        setState(() {
          _user = data.session?.user;
          _loading = false;
        });
      }
    });
  }

  Future<void> _checkAuth() async {
    final session = SupabaseService.currentSession;
    setState(() {
      _user = session?.user;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppTheme.navy,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
      );
    }

    if (_user == null) {
      return const LoginScreen();
    }

    return const MainLayout();
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeScreen(),
      EvalScreen(onBack: () => _onNavigationTapped(0)),
      CreateScreen(onBack: () => _onNavigationTapped(0)),
      const FeedbackScreen(),
      const MyPageScreen(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DesktopDeviceWrapper.useLightStatusBar.value = (_currentIndex == 1);
    });
  }

  void _onNavigationTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    // Toggle mock status bar color: white text on Eval screen (index 1), dark text on others
    DesktopDeviceWrapper.useLightStatusBar.value = (index == 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _currentIndex == 1
          ? null
          : CustomBottomNavigation(
              currentIndex: _currentIndex,
              onTap: _onNavigationTapped,
            ),
    );
  }
}
