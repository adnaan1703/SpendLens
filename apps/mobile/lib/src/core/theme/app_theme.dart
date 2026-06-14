import 'package:flutter/material.dart';

class AppThemeTokens {
  const AppThemeTokens._();

  static const primary = Color(0xFF9FE870);
  static const onPrimary = Color(0xFF0E0F0C);
  static const primaryActive = Color(0xFFCDFFAD);
  static const primaryNeutral = Color(0xFFC5EDAB);
  static const primaryPale = Color(0xFFE2F6D5);

  static const sageCanvas = Color(0xFFE8EBE6);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF0E0F0C);
  static const inkDeep = Color(0xFF163300);
  static const bodyText = Color(0xFF454745);
  static const mutedText = Color(0xFF868685);

  static const positive = Color(0xFF2EAD4B);
  static const positiveDeep = Color(0xFF054D28);
  static const warning = Color(0xFFFFD11A);
  static const warningDeep = Color(0xFFB86700);
  static const warningContent = Color(0xFF4A3B1C);
  static const negative = Color(0xFFD03238);
  static const negativeDeep = Color(0xFFA72027);
  static const negativeDarkest = Color(0xFFA7000D);
  static const negativeBackground = Color(0xFF320707);

  static const accentOrange = Color(0xFFFFC091);
  static const accentCyan = Color(0xFF38C8FF);

  static const darkCanvas = Color(0xFF0E0F0C);
  static const darkSurface = Color(0xFF171A14);
  static const darkCard = Color(0xFF20251D);
  static const darkElevatedSurface = Color(0xFF2D3229);
  static const darkInk = Color(0xFFF4F8EF);
  static const darkBodyText = Color(0xFFDDE7D5);
  static const darkMutedText = Color(0xFFACB7A5);

  static const cardRadius = 24.0;
  static const buttonRadius = 12.0;
  static const inputRadius = 12.0;
}

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.positive,
    required this.onPositive,
    required this.positiveContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.negative,
    required this.onNegative,
    required this.negativeContainer,
  });

  final Color positive;
  final Color onPositive;
  final Color positiveContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color negative;
  final Color onNegative;
  final Color negativeContainer;

  static const light = AppSemanticColors(
    positive: AppThemeTokens.positive,
    onPositive: AppThemeTokens.card,
    positiveContainer: AppThemeTokens.primaryPale,
    warning: AppThemeTokens.warning,
    onWarning: AppThemeTokens.warningContent,
    warningContainer: Color(0xFFFFF4BF),
    negative: AppThemeTokens.negative,
    onNegative: AppThemeTokens.card,
    negativeContainer: Color(0xFFFFDAD6),
  );

  static const dark = AppSemanticColors(
    positive: Color(0xFF82DD93),
    onPositive: AppThemeTokens.onPrimary,
    positiveContainer: Color(0xFF133D22),
    warning: Color(0xFFFFDE68),
    onWarning: AppThemeTokens.onPrimary,
    warningContainer: Color(0xFF4A3B1C),
    negative: Color(0xFFFF999D),
    onNegative: AppThemeTokens.onPrimary,
    negativeContainer: AppThemeTokens.negativeBackground,
  );

  @override
  AppSemanticColors copyWith({
    Color? positive,
    Color? onPositive,
    Color? positiveContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? negative,
    Color? onNegative,
    Color? negativeContainer,
  }) {
    return AppSemanticColors(
      positive: positive ?? this.positive,
      onPositive: onPositive ?? this.onPositive,
      positiveContainer: positiveContainer ?? this.positiveContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      negative: negative ?? this.negative,
      onNegative: onNegative ?? this.onNegative,
      negativeContainer: negativeContainer ?? this.negativeContainer,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) {
      return this;
    }

    return AppSemanticColors(
      positive: Color.lerp(positive, other.positive, t)!,
      onPositive: Color.lerp(onPositive, other.onPositive, t)!,
      positiveContainer: Color.lerp(
        positiveContainer,
        other.positiveContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      negative: Color.lerp(negative, other.negative, t)!,
      onNegative: Color.lerp(onNegative, other.onNegative, t)!,
      negativeContainer: Color.lerp(
        negativeContainer,
        other.negativeContainer,
        t,
      )!,
    );
  }
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    const colorScheme = ColorScheme.light(
      primary: AppThemeTokens.primary,
      onPrimary: AppThemeTokens.onPrimary,
      primaryContainer: AppThemeTokens.primaryPale,
      onPrimaryContainer: AppThemeTokens.inkDeep,
      secondary: AppThemeTokens.primaryNeutral,
      onSecondary: AppThemeTokens.ink,
      secondaryContainer: AppThemeTokens.sageCanvas,
      onSecondaryContainer: AppThemeTokens.ink,
      tertiary: AppThemeTokens.accentCyan,
      onTertiary: AppThemeTokens.ink,
      tertiaryContainer: AppThemeTokens.accentOrange,
      onTertiaryContainer: AppThemeTokens.ink,
      error: AppThemeTokens.negative,
      onError: AppThemeTokens.card,
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: AppThemeTokens.negativeDarkest,
      surface: AppThemeTokens.card,
      onSurface: AppThemeTokens.ink,
      onSurfaceVariant: AppThemeTokens.bodyText,
      outline: AppThemeTokens.mutedText,
      outlineVariant: Color(0xFFC1CAB5),
      inverseSurface: Color(0xFF2D3229),
      onInverseSurface: Color(0xFFEEF2E5),
      inversePrimary: Color(0xFF91D963),
      surfaceTint: AppThemeTokens.primary,
      surfaceContainerLowest: AppThemeTokens.card,
      surfaceContainerLow: Color(0xFFF1F5E8),
      surfaceContainer: Color(0xFFECF0E2),
      surfaceContainerHigh: Color(0xFFE6EADC),
      surfaceContainerHighest: Color(0xFFE0E4D7),
    );

    return _build(
      colorScheme: colorScheme,
      scaffoldBackground: AppThemeTokens.sageCanvas,
      cardColor: AppThemeTokens.card,
      textColor: AppThemeTokens.ink,
      bodyTextColor: AppThemeTokens.bodyText,
      mutedTextColor: AppThemeTokens.mutedText,
      semanticColors: AppSemanticColors.light,
    );
  }

  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      primary: AppThemeTokens.primary,
      onPrimary: AppThemeTokens.onPrimary,
      primaryContainer: Color(0xFF254D16),
      onPrimaryContainer: AppThemeTokens.primaryActive,
      secondary: AppThemeTokens.primaryNeutral,
      onSecondary: AppThemeTokens.onPrimary,
      secondaryContainer: Color(0xFF34452A),
      onSecondaryContainer: AppThemeTokens.primaryPale,
      tertiary: AppThemeTokens.accentCyan,
      onTertiary: AppThemeTokens.onPrimary,
      tertiaryContainer: Color(0xFF24495A),
      onTertiaryContainer: Color(0xFFC9F0FF),
      error: Color(0xFFFF999D),
      onError: AppThemeTokens.onPrimary,
      errorContainer: AppThemeTokens.negativeBackground,
      onErrorContainer: Color(0xFFFFDAD6),
      surface: AppThemeTokens.darkCard,
      onSurface: AppThemeTokens.darkInk,
      onSurfaceVariant: AppThemeTokens.darkBodyText,
      outline: AppThemeTokens.darkMutedText,
      outlineVariant: Color(0xFF4B5546),
      inverseSurface: AppThemeTokens.sageCanvas,
      onInverseSurface: AppThemeTokens.ink,
      inversePrimary: Color(0xFF2F6C00),
      surfaceTint: AppThemeTokens.primary,
      surfaceContainerLowest: AppThemeTokens.darkCanvas,
      surfaceContainerLow: AppThemeTokens.darkSurface,
      surfaceContainer: AppThemeTokens.darkCard,
      surfaceContainerHigh: Color(0xFF293026),
      surfaceContainerHighest: AppThemeTokens.darkElevatedSurface,
    );

    return _build(
      colorScheme: colorScheme,
      scaffoldBackground: AppThemeTokens.darkCanvas,
      cardColor: AppThemeTokens.darkCard,
      textColor: AppThemeTokens.darkInk,
      bodyTextColor: AppThemeTokens.darkBodyText,
      mutedTextColor: AppThemeTokens.darkMutedText,
      semanticColors: AppSemanticColors.dark,
    );
  }

  static ThemeData _build({
    required ColorScheme colorScheme,
    required Color scaffoldBackground,
    required Color cardColor,
    required Color textColor,
    required Color bodyTextColor,
    required Color mutedTextColor,
    required AppSemanticColors semanticColors,
  }) {
    final textTheme = _textTheme(
      textColor: textColor,
      bodyTextColor: bodyTextColor,
      mutedTextColor: mutedTextColor,
    );

    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppThemeTokens.cardRadius),
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppThemeTokens.buttonRadius),
    );
    final inputShape = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppThemeTokens.inputRadius),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      canvasColor: scaffoldBackground,
      cardColor: cardColor,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scaffoldBackground,
        foregroundColor: textColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardColor,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: cardShape,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: cardShape,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        modalBackgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppThemeTokens.cardRadius),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppThemeTokens.primary,
          foregroundColor: AppThemeTokens.onPrimary,
          disabledBackgroundColor: colorScheme.surfaceContainerHighest,
          disabledForegroundColor: mutedTextColor,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cardColor,
          foregroundColor: textColor,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor,
          side: BorderSide(color: colorScheme.outline),
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textColor,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        labelStyle: textTheme.bodyMedium?.copyWith(color: mutedTextColor),
        hintStyle: textTheme.bodyMedium?.copyWith(color: mutedTextColor),
        border: inputShape,
        enabledBorder: inputShape.copyWith(
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: inputShape.copyWith(
          borderSide: const BorderSide(color: AppThemeTokens.primary, width: 2),
        ),
        errorBorder: inputShape.copyWith(
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: inputShape.copyWith(
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: textTheme.bodyMedium?.copyWith(color: textColor),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll<Color>(cardColor),
          side: WidgetStatePropertyAll<BorderSide>(
            BorderSide(color: colorScheme.outlineVariant),
          ),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppThemeTokens.inputRadius),
            ),
          ),
          elevation: const WidgetStatePropertyAll<double>(4),
          surfaceTintColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        textStyle: textTheme.bodyMedium?.copyWith(color: textColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppThemeTokens.inputRadius),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        disabledColor: colorScheme.surfaceContainerHighest,
        selectedColor: colorScheme.primaryContainer,
        secondarySelectedColor: colorScheme.primaryContainer,
        labelStyle: textTheme.bodySmall,
        secondaryLabelStyle: textTheme.bodySmall,
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppThemeTokens.buttonRadius),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: cardColor,
        indicatorColor: colorScheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? textColor
              : mutedTextColor;
          return textTheme.labelSmall?.copyWith(color: color);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? textColor
              : mutedTextColor;
          return IconThemeData(color: color);
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppThemeTokens.primary,
        circularTrackColor: AppThemeTokens.primaryPale,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: textTheme.bodySmall?.copyWith(
          color: colorScheme.onInverseSurface,
          fontWeight: FontWeight.w600,
        ),
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppThemeTokens.cardRadius),
        ),
      ),
      extensions: [semanticColors],
    );
  }

  static TextTheme _textTheme({
    required Color textColor,
    required Color bodyTextColor,
    required Color mutedTextColor,
  }) {
    final base = Typography.material2021().black.apply(
      bodyColor: bodyTextColor,
      displayColor: textColor,
    );

    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w900,
      ),
      displayMedium: base.displayMedium?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w900,
      ),
      displaySmall: base.displaySmall?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: base.titleLarge?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: base.titleMedium?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: base.titleSmall?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.bodyLarge?.copyWith(color: bodyTextColor),
      bodyMedium: base.bodyMedium?.copyWith(color: bodyTextColor),
      bodySmall: base.bodySmall?.copyWith(color: mutedTextColor),
      labelLarge: base.labelLarge?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: base.labelMedium?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: base.labelSmall?.copyWith(
        color: mutedTextColor,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
