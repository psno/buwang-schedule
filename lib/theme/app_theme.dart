import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 主题颜色枚举
enum AppThemeColor {
  blue(0, '默认蓝', Color(0xFF007AFF)),
  pink(1, '樱花粉', Color(0xFFFF6B9D)),
  mint(2, '薄荷绿', Color(0xFF34C759));

  final int id;
  final String label;
  final Color seedColor;
  const AppThemeColor(this.id, this.label, this.seedColor);

  static AppThemeColor fromIndex(int i) {
    return AppThemeColor.values.firstWhere(
      (e) => e.id == i,
      orElse: () => AppThemeColor.blue,
    );
  }
}

/// 不忘课表 - 主题配置
/// 默认 Apple 风格，粉色/绿色手动调色保证好看
class AppTheme {
  AppTheme._();

  // ─── Border Radius ───
  static const double _cardRadius = 16.0;
  static const double _buttonRadius = 12.0;
  static const double _inputRadius = 12.0;
  static const double _chipRadius = 20.0;
  static const double _dialogRadius = 20.0;
  static const double _bottomSheetRadius = 24.0;
  static const double _fabRadius = 16.0;

  // ─── 固定色 ───
  static const Color currentClassColor = Color(0xFF34C759);
  static const Color nextClassColor = Color(0xFFFF9500);

  // ═══════════════════════════════════════════════
  // 三套配色方案（手动调色，不依赖 fromSeed）
  // ═══════════════════════════════════════════════

  static ColorScheme _lightScheme(AppThemeColor t) {
    switch (t) {
      case AppThemeColor.blue:
        return const ColorScheme.light(
          primary: Color(0xFF007AFF), onPrimary: Colors.white,
          primaryContainer: Color(0xFFD1E4FF), onPrimaryContainer: Color(0xFF001D36),
          secondary: Color(0xFF5856D6), onSecondary: Colors.white,
          secondaryContainer: Color(0xFFE8E0FF), onSecondaryContainer: Color(0xFF1D1948),
          tertiary: Color(0xFFFF9500), onTertiary: Colors.white,
          tertiaryContainer: Color(0xFFFFDDB5), onTertiaryContainer: Color(0xFF2B1700),
          error: Color(0xFFFF3B30), onError: Colors.white,
          errorContainer: Color(0xFFFFDAD6), onErrorContainer: Color(0xFF410002),
          surface: Color(0xFFFFFFFF), onSurface: Color(0xFF1C1C1E),
          surfaceContainerHighest: Color(0xFFF2F2F7), onSurfaceVariant: Color(0xFF8E8E93),
          outline: Color(0xFFC6C6C8), outlineVariant: Color(0xFFE5E5EA),
        );
      case AppThemeColor.pink:
        return const ColorScheme.light(
          primary: Color(0xFFFF6B9D), onPrimary: Colors.white,
          primaryContainer: Color(0xFFFFD9E6), onPrimaryContainer: Color(0xFF3E0021),
          secondary: Color(0xFFC2185B), onSecondary: Colors.white,
          secondaryContainer: Color(0xFFFFD9E2), onSecondaryContainer: Color(0xFF3E001D),
          tertiary: Color(0xFFFF8A65), onTertiary: Colors.white,
          tertiaryContainer: Color(0xFFFFDBCF), onTertiaryContainer: Color(0xFF3B1000),
          error: Color(0xFFFF3B30), onError: Colors.white,
          errorContainer: Color(0xFFFFDAD6), onErrorContainer: Color(0xFF410002),
          surface: Color(0xFFFFFFFF), onSurface: Color(0xFF1C1C1E),
          surfaceContainerHighest: Color(0xFFFFF0F4), onSurfaceVariant: Color(0xFF8E8E93),
          outline: Color(0xFFE0B0C0), outlineVariant: Color(0xFFF5DDE5),
        );
      case AppThemeColor.mint:
        return const ColorScheme.light(
          primary: Color(0xFF34C759), onPrimary: Colors.white,
          primaryContainer: Color(0xFFB8F5CA), onPrimaryContainer: Color(0xFF002114),
          secondary: Color(0xFF00897B), onSecondary: Colors.white,
          secondaryContainer: Color(0xFFB2DFDB), onSecondaryContainer: Color(0xFF00251E),
          tertiary: Color(0xFF26A69A), onTertiary: Colors.white,
          tertiaryContainer: Color(0xFFB2DFDB), onTertiaryContainer: Color(0xFF00201C),
          error: Color(0xFFFF3B30), onError: Colors.white,
          errorContainer: Color(0xFFFFDAD6), onErrorContainer: Color(0xFF410002),
          surface: Color(0xFFFFFFFF), onSurface: Color(0xFF1C1C1E),
          surfaceContainerHighest: Color(0xFFEDFAF0), onSurfaceVariant: Color(0xFF8E8E93),
          outline: Color(0xFFA8DAB5), outlineVariant: Color(0xFFD5EFE0),
        );
    }
  }

  static ColorScheme _darkScheme(AppThemeColor t) {
    switch (t) {
      case AppThemeColor.blue:
        return const ColorScheme.dark(
          primary: Color(0xFF0A84FF), onPrimary: Colors.white,
          primaryContainer: Color(0xFF003A75), onPrimaryContainer: Color(0xFFD1E4FF),
          secondary: Color(0xFF5E5CE6), onSecondary: Colors.white,
          secondaryContainer: Color(0xFF2A2770), onSecondaryContainer: Color(0xFFE8E0FF),
          tertiary: Color(0xFFFF9F0A), onTertiary: Colors.white,
          tertiaryContainer: Color(0xFF5C3300), onTertiaryContainer: Color(0xFFFFDDB5),
          error: Color(0xFFFF453A), onError: Colors.white,
          errorContainer: Color(0xFF93000A), onErrorContainer: Color(0xFFFFDAD6),
          surface: Color(0xFF1C1C1E), onSurface: Color(0xFFE5E5EA),
          surfaceContainerHighest: Color(0xFF2C2C2E), onSurfaceVariant: Color(0xFF8E8E93),
          outline: Color(0xFF48484A), outlineVariant: Color(0xFF38383A),
        );
      case AppThemeColor.pink:
        return const ColorScheme.dark(
          primary: Color(0xFFFF85B3), onPrimary: Colors.white,
          primaryContainer: Color(0xFF7A003E), onPrimaryContainer: Color(0xFFFFD9E6),
          secondary: Color(0xFFFF80AB), onSecondary: Colors.white,
          secondaryContainer: Color(0xFF7A0036), onSecondaryContainer: Color(0xFFFFD9E2),
          tertiary: Color(0xFFFFAB91), onTertiary: Colors.white,
          tertiaryContainer: Color(0xFF7A2500), onTertiaryContainer: Color(0xFFFFDBCF),
          error: Color(0xFFFF453A), onError: Colors.white,
          errorContainer: Color(0xFF93000A), onErrorContainer: Color(0xFFFFDAD6),
          surface: Color(0xFF1C1C1E), onSurface: Color(0xFFE5E5EA),
          surfaceContainerHighest: Color(0xFF2E2228), onSurfaceVariant: Color(0xFF8E8E93),
          outline: Color(0xFF5C3848), outlineVariant: Color(0xFF3E2835),
        );
      case AppThemeColor.mint:
        return const ColorScheme.dark(
          primary: Color(0xFF4ADE80), onPrimary: Color(0xFF003921),
          primaryContainer: Color(0xFF00522A), onPrimaryContainer: Color(0xFFB8F5CA),
          secondary: Color(0xFF4DB6AC), onSecondary: Color(0xFF003731),
          secondaryContainer: Color(0xFF005048), onSecondaryContainer: Color(0xFFB2DFDB),
          tertiary: Color(0xFF80CBC4), onTertiary: Color(0xFF003733),
          tertiaryContainer: Color(0xFF00504A), onTertiaryContainer: Color(0xFFB2DFDB),
          error: Color(0xFFFF453A), onError: Colors.white,
          errorContainer: Color(0xFF93000A), onErrorContainer: Color(0xFFFFDAD6),
          surface: Color(0xFF1C1C1E), onSurface: Color(0xFFE5E5EA),
          surfaceContainerHighest: Color(0xFF1E2E24), onSurfaceVariant: Color(0xFF8E8E93),
          outline: Color(0xFF3E5545), outlineVariant: Color(0xFF2E3E34),
        );
    }
  }

  // ─── 主题生成 ───
  static ThemeData lightTheme([AppThemeColor themeColor = AppThemeColor.blue]) {
    return _buildTheme(_lightScheme(themeColor), Brightness.light);
  }

  static ThemeData darkTheme([AppThemeColor themeColor = AppThemeColor.blue]) {
    return _buildTheme(_darkScheme(themeColor), Brightness.dark);
  }

  // ─── System UI ───
  static void setSystemUIOverlay(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));
  }

  // ─── Theme Builder ───
  static ThemeData _buildTheme(ColorScheme cs, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final textTheme = _buildTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: cs,
      textTheme: textTheme,
      scaffoldBackgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      canvasColor: isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
      cardColor: cs.surface,
      dividerColor: cs.outlineVariant,
      disabledColor: cs.onSurface.withOpacity(0.38),

      appBarTheme: AppBarTheme(
        elevation: 0, scrolledUnderElevation: 0.5, centerTitle: true,
        backgroundColor: cs.surface, foregroundColor: cs.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: cs.onSurface, fontWeight: FontWeight.w600, fontSize: 18,
        ),
        iconTheme: IconThemeData(color: cs.primary, size: 22),
        actionsIconTheme: IconThemeData(color: cs.primary, size: 22),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: cs.surface,
                systemNavigationBarIconBrightness: Brightness.light,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: cs.surface,
                systemNavigationBarIconBrightness: Brightness.dark,
              ),
      ),

      cardTheme: CardTheme(
        elevation: 0, color: cs.surface, surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardRadius),
          side: BorderSide(color: cs.outlineVariant, width: 0.5),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0, backgroundColor: cs.primary, foregroundColor: cs.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_buttonRadius)),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_buttonRadius)),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_buttonRadius)),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_buttonRadius)),
          side: BorderSide(color: cs.outline),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary, foregroundColor: cs.onPrimary,
        elevation: 2, highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_fabRadius)),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? cs.surfaceContainerHighest : cs.surfaceContainerHighest.withOpacity(0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_inputRadius),
          borderSide: BorderSide(color: cs.outline, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_inputRadius),
          borderSide: BorderSide(color: cs.outline, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_inputRadius),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_inputRadius),
          borderSide: BorderSide(color: cs.error, width: 0.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_inputRadius),
          borderSide: BorderSide(color: cs.error, width: 1.5),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        labelStyle: textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        floatingLabelStyle: textTheme.bodySmall?.copyWith(color: cs.primary),
      ),

      chipTheme: ChipThemeData(
        elevation: 0, pressElevation: 0,
        backgroundColor: cs.surfaceContainerHighest,
        selectedColor: cs.primary.withOpacity(0.15),
        disabledColor: cs.onSurface.withOpacity(0.12),
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_chipRadius), side: BorderSide.none),
      ),

      dialogTheme: DialogTheme(
        elevation: 3, backgroundColor: cs.surface, surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_dialogRadius)),
        titleTextStyle: textTheme.titleLarge?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w600),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        elevation: 3, backgroundColor: cs.surface, surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(_bottomSheetRadius)),
        ),
        modalElevation: 3, modalBackgroundColor: cs.surface,
      ),

      navigationBarTheme: NavigationBarThemeData(
        elevation: 0, height: 64,
        backgroundColor: cs.surface, surfaceTintColor: Colors.transparent,
        indicatorColor: cs.primary.withOpacity(0.15),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return IconThemeData(color: cs.primary, size: 24);
          return IconThemeData(color: cs.onSurfaceVariant, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w600);
          }
          return textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant);
        }),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        elevation: 0, backgroundColor: cs.surface,
        selectedItemColor: cs.primary, unselectedItemColor: cs.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: textTheme.labelSmall,
      ),

      tabBarTheme: TabBarTheme(
        labelColor: cs.primary, unselectedLabelColor: cs.onSurfaceVariant,
        indicatorColor: cs.primary, indicatorSize: TabBarIndicatorSize.label,
        labelStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: textTheme.titleSmall,
        dividerColor: Colors.transparent,
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_buttonRadius)),
        titleTextStyle: textTheme.bodyLarge?.copyWith(color: cs.onSurface),
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        iconColor: cs.onSurfaceVariant,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return cs.onPrimary;
          return cs.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return cs.primary;
          return cs.surfaceContainerHighest;
        }),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return cs.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(cs.onPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide(color: cs.outline, width: 1.5),
      ),

      dividerTheme: DividerThemeData(color: cs.outlineVariant, thickness: 0.5, space: 1),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? cs.surfaceContainerHighest : cs.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: isDark ? cs.onSurfaceVariant : cs.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_buttonRadius)),
        elevation: 3,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? cs.surfaceContainerHighest : cs.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: isDark ? cs.onSurfaceVariant : cs.onInverseSurface,
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        elevation: 3, color: cs.surface, surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)),
        textStyle: textTheme.bodyMedium?.copyWith(color: cs.onSurface),
      ),

      timePickerTheme: TimePickerThemeData(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_dialogRadius)),
        hourMinuteShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_buttonRadius)),
        dayPeriodShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_buttonRadius)),
        dayPeriodColor: cs.surfaceContainerHighest,
        dayPeriodTextColor: cs.onSurface,
        hourMinuteColor: cs.surfaceContainerHighest,
        hourMinuteTextColor: cs.onSurface,
        dialHandColor: cs.primary,
        dialBackgroundColor: cs.surfaceContainerHighest,
        dialTextColor: cs.onSurface,
        entryModeIconColor: cs.primary,
      ),

      datePickerTheme: DatePickerThemeData(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_dialogRadius)),
        headerBackgroundColor: cs.primary,
        headerForegroundColor: cs.onPrimary,
        todayBackgroundColor: WidgetStateProperty.all(cs.primary.withOpacity(0.1)),
        todayForegroundColor: WidgetStateProperty.all(cs.primary),
        todayBorder: BorderSide(color: cs.primary, width: 1),
        weekdayStyle: textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
      ),
    );
  }

  // ─── Text Theme ───
  static TextTheme _buildTextTheme() {
    return const TextTheme(
      displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w400, letterSpacing: -0.25, height: 1.12),
      displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w400, letterSpacing: 0, height: 1.16),
      displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w400, letterSpacing: 0, height: 1.22),
      headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w600, letterSpacing: 0, height: 1.25),
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, letterSpacing: 0, height: 1.29),
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: 0, height: 1.33),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: 0, height: 1.27),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.15, height: 1.5),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1, height: 1.43),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5, height: 1.5),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25, height: 1.43),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4, height: 1.33),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1, height: 1.43),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5, height: 1.33),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5, height: 1.45),
    );
  }
}
