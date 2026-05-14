import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/timetable_screen.dart';
import 'screens/reminder_screen.dart';
import 'screens/more_screen.dart';
import 'services/database_service.dart';
import 'utils/constants.dart';

/// 不忘课表 - Main App Widget
class BuwangApp extends StatefulWidget {
  const BuwangApp({super.key});

  static final GlobalKey<_BuwangAppState> appKey = GlobalKey<_BuwangAppState>();

  @override
  State<BuwangApp> createState() => _BuwangAppState();
}

class _BuwangAppState extends State<BuwangApp> {
  AppThemeColor _themeColor = AppThemeColor.blue;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final db = DatabaseService.instance;
    final value = await db.getSetting(AppConstants.keyThemeColor);
    if (value != null && mounted) {
      setState(() {
        _themeColor = AppThemeColor.fromIndex(int.tryParse(value) ?? 0);
      });
    }
  }

  void setThemeColor(AppThemeColor color) {
    setState(() => _themeColor = color);
    DatabaseService.instance.setSetting(AppConstants.keyThemeColor, color.index.toString());
  }

  AppThemeColor get themeColor => _themeColor;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '不忘课表',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(_themeColor),
      darkTheme: AppTheme.darkTheme(_themeColor),
      themeMode: ThemeMode.system,
      home: const MainShell(),
    );
  }
}

/// Main shell with bottom navigation bar.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  static const List<Widget> _screens = [
    HomeScreen(),
    TimetableScreen(),
    ReminderScreen(),
    MoreScreen(),
  ];

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    final brightness = Theme.of(context).brightness;
    AppTheme.setSystemUIOverlay(brightness);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabTapped,
        animationDuration: const Duration(milliseconds: 300),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '今日',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_view_week_outlined),
            selectedIcon: Icon(Icons.calendar_view_week),
            label: '课表',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: '提醒',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '更多',
          ),
        ],
      ),
    );
  }
}
