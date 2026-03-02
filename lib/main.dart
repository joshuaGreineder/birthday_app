import 'package:flutter/material.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'services/widget_service.dart';
import 'screens/home_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/timeline_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Start the app immediately - initialize everything in background
  runApp(const EventTrackerApp());
  
  // Initialize all services in the background after app starts
  _initializeBackgroundServices();
}

// Initialize services that don't block the UI
Future<void> _initializeBackgroundServices() async {
  // Initialize storage first (critical)
  try {
    final storage = StorageService();
    await storage.init();
  } catch (e) {
    debugPrint('Storage initialization error: $e');
  }
  
  // Initialize other services in parallel
  try {
    // Initialize notification service
    unawaited(_initializeNotifications());
    
    // Initialize widgets
    unawaited(_initializeWidgets());
  } catch (e) {
    debugPrint('Background initialization error: $e');
  }
}

Future<void> _initializeNotifications() async {
  try {
    final notificationService = NotificationService();
    await notificationService.init();
    
    // Ensure storage is initialized before reading settings
    final storage = StorageService();
    await storage.init();
    
    // Request notification permissions if notifications are enabled
    if (storage.getNotificationsEnabled()) {
      try {
        final hasPermission = await notificationService.requestPermissions();
        if (hasPermission) {
          await notificationService.scheduleDailyNotifications();
        }
      } catch (e) {
        debugPrint('Error with notification permissions: $e');
      }
    }
  } catch (e) {
    debugPrint('Error initializing notification service: $e');
  }
}

Future<void> _initializeWidgets() async {
  try {
    await WidgetService.initialize();
    await WidgetService.updateWidgetData();
  } catch (e) {
    debugPrint('Error initializing widgets: $e');
  }
}

// Helper to run futures without awaiting
void unawaited(Future<void> future) {
  future.catchError((e) => debugPrint('Unawaited future error: $e'));
}

class EventTrackerApp extends StatefulWidget {
  const EventTrackerApp({super.key});

  @override
  State<EventTrackerApp> createState() => _EventTrackerAppState();
}

class _EventTrackerAppState extends State<EventTrackerApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  void _loadThemeMode() {
    // Load theme asynchronously to not block UI
    Future.microtask(() {
      try {
        final storage = StorageService();
        final themeModeString = storage.getSetting('themeMode', defaultValue: 'system') as String;
        if (mounted) {
          setState(() {
            switch (themeModeString) {
              case 'light':
                _themeMode = ThemeMode.light;
                break;
              case 'dark':
                _themeMode = ThemeMode.dark;
                break;
              default:
                _themeMode = ThemeMode.system;
            }
          });
        }
      } catch (e) {
        debugPrint('Error loading theme mode: $e');
      }
    });
  }

  void updateThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
    final storage = StorageService();
    final modeString = mode == ThemeMode.light 
        ? 'light' 
        : mode == ThemeMode.dark 
            ? 'dark' 
            : 'system';
    storage.saveSetting('themeMode', modeString);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Event Tracker',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: _themeMode,
      home: MainScreen(
        onThemeModeChanged: updateThemeMode,
      ),
    );
  }

  ThemeData _buildLightTheme() {
    const primaryColor = Color(0xFF6366F1);
    const secondaryColor = Color(0xFFF472B6);
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: const Color(0xFF10B981),
        surface: Colors.white,
        surfaceContainerHighest: const Color(0xFFF8FAFC),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: const Color(0xFF1E293B),
        outline: const Color(0xFF94A3B8),
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      fontFamily: 'Segoe UI',
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -1),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFF1E293B),
        titleTextStyle: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1E293B),
          letterSpacing: -0.5,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 70,
        backgroundColor: Colors.white,
        indicatorColor: primaryColor.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: primaryColor);
          }
          return const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8));
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primaryColor, size: 24);
          }
          return const IconThemeData(color: Color(0xFF94A3B8), size: 24);
        }),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    const primaryColor = Color(0xFF818CF8);
    const secondaryColor = Color(0xFFF472B6);
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: const Color(0xFF34D399),
        surface: const Color(0xFF1E293B),
        surfaceContainerHighest: const Color(0xFF0F172A),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: const Color(0xFFF1F5F9),
        outline: const Color(0xFF64748B),
      ),
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      fontFamily: 'Segoe UI',
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -1),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: const Color(0xFF1E293B),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFFF1F5F9),
        titleTextStyle: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: Color(0xFFF1F5F9),
          letterSpacing: -0.5,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 70,
        backgroundColor: const Color(0xFF1E293B),
        indicatorColor: primaryColor.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: primaryColor);
          }
          return const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF64748B));
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primaryColor, size: 24);
          }
          return const IconThemeData(color: Color(0xFF64748B), size: 24);
        }),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final Function(ThemeMode)? onThemeModeChanged;
  
  const MainScreen({super.key, this.onThemeModeChanged});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const HomeScreen(),
          const TimelineScreen(),
          const CalendarScreen(),
          SettingsScreen(onThemeModeChanged: widget.onThemeModeChanged),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.view_timeline_outlined),
              selectedIcon: Icon(Icons.view_timeline_rounded),
              label: 'Timeline',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month_rounded),
              label: 'Calendar',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
