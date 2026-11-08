import 'package:flutter/material.dart';
import 'app_config.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'services/google_calendar_service.dart';
import 'services/widget_service.dart';
import 'screens/home_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/timeline_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';
import 'utils/user_message.dart';
import 'widgets/app_bottom_bar.dart';
import 'widgets/screen_status.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Open local storage before the first frame so saved settings (theme first of
  // all) are read from disk, not from defaults. Hive opens in well under a second.
  try {
    await StorageService().init();
  } catch (e) {
    debugPrint('Storage initialization error: $e');
  }

  runApp(const HapparooApp());

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

    // Catch up the Google calendar with anything changed while it was offline.
    GoogleCalendarService().syncInBackground();
  } catch (e) {
    debugPrint('Background initialization error: $e');
  }
}

Future<void> _initializeNotifications() async {
  try {
    final notificationService = NotificationService();
    await notificationService.init();

    // Ensure storage is initialized before reading settings.
    // Do not request notification permission here. Scheduling runs only
    // when the user has already allowed notifications.
    final storage = StorageService();
    await storage.init();

    if (storage.getNotificationsEnabled()) {
      try {
        final access = await notificationService.notificationAccess();
        if (access == NotificationAccess.granted) {
          await notificationService.scheduleDailyNotifications();
        }
      } catch (e) {
        debugPrint('Error scheduling reminders: $e');
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

class HapparooApp extends StatefulWidget {
  const HapparooApp({super.key});

  @override
  State<HapparooApp> createState() => _HapparooAppState();
}

class _HapparooAppState extends State<HapparooApp> with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadThemeMode();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationService().onAppResumed();
      GoogleCalendarService().syncInBackground();
    }
  }

  void _loadThemeMode() {
    final storage = StorageService();
    if (storage.isInitialized) {
      _themeMode = _themeModeFrom(storage.getSetting('themeMode', defaultValue: 'system'));
      return;
    }
    // Storage could not open before the first frame; apply the saved theme once it does.
    storage.init().then((_) {
      if (!mounted) return;
      setState(() {
        _themeMode = _themeModeFrom(storage.getSetting('themeMode', defaultValue: 'system'));
      });
    }).catchError((Object e) {
      debugPrint('Error loading theme mode: $e');
    });
  }

  static ThemeMode _themeModeFrom(Object? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
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
      title: kAppDisplayName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      home: MainScreen(
        onThemeModeChanged: updateThemeMode,
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
  bool _ready = false;
  bool _showOnboarding = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      await StorageService().init();
      final done = StorageService().isOnboardingComplete();
      if (!mounted) return;
      setState(() {
        _ready = true;
        _error = null;
        _showOnboarding = !done;
      });
    } catch (e) {
      debugPrint('Could not open storage: $e');
      if (!mounted) return;
      setState(() {
        _ready = true;
        _error = couldNot('open your events');
        _showOnboarding = false;
      });
    }
  }

  Future<void> _finishOnboarding() async {
    await StorageService().setOnboardingComplete();
    if (mounted) setState(() => _showOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: _BootLoading());
    }
    if (_error != null) {
      return Scaffold(
        body: ScreenStatus.error(title: _error!, onRetry: _prepare),
      );
    }
    if (_showOnboarding) {
      return OnboardingScreen(onDone: _finishOnboarding);
    }
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
      bottomNavigationBar: AppBottomBar(
        index: _currentIndex,
        onChanged: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

class _BootLoading extends StatelessWidget {
  const _BootLoading();

  @override
  Widget build(BuildContext context) {
    return ScreenStatus.loading();
  }
}
