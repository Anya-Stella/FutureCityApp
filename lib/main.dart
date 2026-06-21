// lib/main.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
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
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        setState(() {
          _user = data.session?.user;
          _loading = false;
        });
      }
    });
  }

  Future<void> _checkAuth() async {
    final session = Supabase.instance.client.auth.currentSession;
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

  final List<Widget> _screens = [
    const HomeScreen(),
    const EvalScreen(),
    const Placeholder(), // Index 2 is "Create" triggers screen overlay
    const FeedbackScreen(),
    const MyPageScreen(),
  ];

  void _onNavigationTapped(int index) {
    if (index == 2) {
      // Open CreateScreen as a modal sheet
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const FractionallySizedBox(
          heightFactor: 0.92,
          child: CreateScreen(),
        ),
      );
    } else {
      setState(() {
        _currentIndex = index;
      });
      // Toggle mock status bar color: white text on Eval screen (index 1), dark text on others
      DesktopDeviceWrapper.useLightStatusBar.value = (index == 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex == 2 ? 0 : _currentIndex, // Fallback to Home when index is 2
        children: _screens,
      ),
      bottomNavigationBar: CustomBottomNavigation(
        currentIndex: _currentIndex,
        onTap: _onNavigationTapped,
      ),
    );
  }
}
