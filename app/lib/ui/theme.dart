import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../settings/app_settings.dart';

/// Aspetto in stile Outlook classico di Microsoft 365 (tappa «Aspetto», scelta 1a): i temi di Office (Colorato,
/// Bianco, Grigio scuro, Nero, o quello del sistema), un solo accento blu, grigi neutri della palette Fluent 2
/// (pubblica), angoli di 4 px, nessuna onda al clic. Componenti Material ridisegnati (scelta 4a della fase 3): niente
/// colori o caratteri proprietari. Carattere (scelta 2b): Segoe UI del sistema su Windows, Inter (OFL, incluso
/// nell'app) altrove.
class OfficeTheme {
  OfficeTheme._();

  /// Accento blu (temi chiari) e la sua variante leggibile su fondo scuro.
  static const brand = Color(0xFF0F6CBD);
  static const brandOnDark = Color(0xFF479EF5);

  /// Angoli: comandi, caselle, menu e suggerimenti (4) e finestre di dialogo (8), come Fluent 2.
  static const radius = 4.0;
  static const dialogRadius = 8.0;

  /// Carattere dell'interfaccia: su Windows quello del sistema (non ridistribuibile), altrove Inter incluso.
  static String get fontFamily => defaultTargetPlatform == TargetPlatform.windows ? 'Segoe UI' : 'Inter';

  /// Tema chiaro di serie (Colorato) e scuro di serie (Nero): quelli di «Usa impostazione di sistema».
  static ThemeData light() => of(AppTheme.colorful);
  static ThemeData dark() => of(AppTheme.black);

  static final _cache = <AppTheme, ThemeData>{};

  /// I dati del tema, costruiti una volta sola (così ridisegnare l'app non crea temi «nuovi»).
  static ThemeData of(AppTheme theme) => _cache.putIfAbsent(theme, () => _create(theme));

  /// Le tre cose che servono a MaterialApp per il tema scelto.
  static ({ThemeData theme, ThemeData darkTheme, ThemeMode mode}) forApp(AppTheme choice) => switch (choice) {
    AppTheme.system => (theme: light(), darkTheme: dark(), mode: ThemeMode.system),
    AppTheme.colorful || AppTheme.white => (theme: of(choice), darkTheme: of(choice), mode: ThemeMode.light),
    AppTheme.darkGray || AppTheme.black => (theme: of(choice), darkTheme: of(choice), mode: ThemeMode.dark),
  };

  static ThemeData _create(AppTheme theme) => switch (theme) {
    // Colorato: il blu sta nella barra in alto (V2, come l'Outlook di oggi), la banda delle schede è chiara.
    AppTheme.system || AppTheme.colorful => _build(
      _lightScheme(ribbon: const Color(0xFFF3F3F3), folders: const Color(0xFFFAFAFA)),
      const OfficeChrome(
        titleBar: brand,
        onTitleBar: Colors.white,
        tabBar: Color(0xFFF3F3F3),
        onTabBar: Color(0xFF242424),
        selectedTab: brand,
      ),
    ),
    AppTheme.white => () {
      final scheme = _lightScheme(ribbon: Colors.white, folders: Colors.white);
      return _build(
        scheme,
        OfficeChrome(
          titleBar: Colors.white,
          onTitleBar: scheme.onSurface,
          tabBar: Colors.white,
          onTabBar: scheme.onSurface,
          selectedTab: brand,
        ),
      );
    }(),
    AppTheme.darkGray => _darkTheme(
      surface: const Color(0xFF363636),
      lowest: const Color(0xFF2E2E2E),
      low: const Color(0xFF3B3B3B),
      container: const Color(0xFF474747),
      high: const Color(0xFF515151),
      outline: const Color(0xFF5A5A5A),
      selection: const Color(0xFF1F4B78),
    ),
    AppTheme.black => _darkTheme(
      surface: const Color(0xFF242424),
      lowest: const Color(0xFF1B1B1B),
      low: const Color(0xFF202020),
      container: const Color(0xFF2B2B2B),
      high: const Color(0xFF333333),
      outline: const Color(0xFF3D3D3D),
      selection: const Color(0xFF16395C),
    ),
  };

  /// Schema chiaro scritto colore per colore (niente `ColorScheme.fromSeed`, che tinge di blu i fondi e i grigi).
  static ColorScheme _lightScheme({required Color ribbon, required Color folders}) => ColorScheme(
    brightness: Brightness.light,
    primary: brand,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFEBF3FC),
    onPrimaryContainer: const Color(0xFF0F548C),
    secondary: const Color(0xFF616161),
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFFCFE4FA), // selezione nelle liste
    onSecondaryContainer: const Color(0xFF242424),
    tertiary: const Color(0xFF0F548C),
    onTertiary: Colors.white,
    error: const Color(0xFFC50F1F),
    onError: Colors.white,
    errorContainer: const Color(0xFFFDF3F4),
    onErrorContainer: const Color(0xFFB10E1C),
    surface: Colors.white,
    onSurface: const Color(0xFF242424),
    onSurfaceVariant: const Color(0xFF616161),
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: folders, // riquadro cartelle
    surfaceContainer: ribbon, // barra multifunzione e barra di stato
    surfaceContainerHigh: const Color(0xFFEBEBEB),
    surfaceContainerHighest: const Color(0xFFE0E0E0),
    outline: const Color(0xFFD1D1D1),
    outlineVariant: const Color(0xFFE0E0E0),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: const Color(0xFF292929),
    onInverseSurface: Colors.white,
    inversePrimary: brandOnDark,
    surfaceTint: Colors.transparent, // niente velo colorato sui fondi rialzati (menu, finestre)
  );

  static ThemeData _darkTheme({
    required Color surface,
    required Color lowest,
    required Color low,
    required Color container,
    required Color high,
    required Color outline,
    required Color selection,
  }) {
    final scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: brandOnDark,
      onPrimary: const Color(0xFF0A2540),
      primaryContainer: const Color(0xFF082338),
      onPrimaryContainer: const Color(0xFFB4D6FA),
      secondary: const Color(0xFFADADAD),
      onSecondary: const Color(0xFF242424),
      secondaryContainer: selection,
      onSecondaryContainer: Colors.white,
      tertiary: const Color(0xFF77B7F7),
      onTertiary: const Color(0xFF0A2540),
      error: const Color(0xFFDC626D),
      onError: const Color(0xFF240000),
      errorContainer: const Color(0xFF3B0509),
      onErrorContainer: const Color(0xFFF1BBBC),
      surface: surface,
      onSurface: Colors.white,
      onSurfaceVariant: const Color(0xFFADADAD),
      surfaceContainerLowest: lowest,
      surfaceContainerLow: low,
      surfaceContainer: container,
      surfaceContainerHigh: high,
      surfaceContainerHighest: Color.lerp(high, Colors.white, 0.06)!,
      outline: const Color(0xFF666666),
      outlineVariant: outline,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: const Color(0xFFF5F5F5),
      onInverseSurface: const Color(0xFF242424),
      inversePrimary: brand,
      surfaceTint: Colors.transparent,
    );
    return _build(
      scheme,
      OfficeChrome(
        titleBar: lowest,
        onTitleBar: scheme.onSurface,
        tabBar: container,
        onTabBar: scheme.onSurface,
        selectedTab: brandOnDark,
      ),
    );
  }

  static ThemeData _build(ColorScheme scheme, OfficeChrome chrome) {
    final dark = scheme.brightness == Brightness.dark;
    const small = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(radius)));
    // Passaggio del mouse e pressione come i pulsanti «subtle» di Fluent: un grigio leggero, nessuna onda.
    final hover = scheme.onSurface.withValues(alpha: dark ? 0.08 : 0.04);
    final pressed = scheme.onSurface.withValues(alpha: dark ? 0.14 : 0.10);
    // Gli stili dati ai componenti sostituiscono quello del tema: il carattere va scritto anche qui, altrimenti il
    // testo prende quello predefinito del motore (trovato con le schermate del V2).
    final family = fontFamily;
    final buttonText = TextStyle(fontFamily: family, fontSize: 14, fontWeight: FontWeight.w600);
    const buttonPadding = EdgeInsets.symmetric(horizontal: 12);
    final flyoutBorder = BorderSide(color: scheme.outlineVariant);

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: fontFamily,
      // Scala dei caratteri di Office (Fluent 2, tappa «Aspetto», V6): il testo normale è a 14. Material usa 16 per
      // `bodyLarge` (righe degli elenchi, caselle di testo, menu a tendina), che sembrava più grande di Outlook.
      // `titleMedium` (16, medio) è anche il testo dei menu a tendina di Material: a 14 normale come le altre caselle; i
      // titoletti che lo usavano ora scrivono il loro stile (`titleSmall` a 16, cioè lo stesso di prima).
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 14, height: 1.43, letterSpacing: 0.1),
        titleMedium: TextStyle(fontSize: 14, height: 1.43, fontWeight: FontWeight.w400, letterSpacing: 0.1),
      ),
      // Caselle di testo basse come in Office (circa 36 px invece dei 56 di Material). Il bordo resta quello che sceglie
      // ogni casella: dato qui, incorniciava anche le righe sottolineate della composizione (A, Cc, Oggetto).
      inputDecorationTheme: const InputDecorationTheme(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      visualDensity: VisualDensity.compact,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      splashFactory: NoSplash.splashFactory,
      hoverColor: hover,
      highlightColor: pressed,
      focusColor: hover,
      splashColor: Colors.transparent,
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1, thickness: 1),
      // Selezione nelle liste come in Outlook: sfondo azzurro tenue, testo normale.
      listTileTheme: ListTileThemeData(
        selectedTileColor: scheme.secondaryContainer,
        selectedColor: scheme.onSurface,
        iconColor: scheme.onSurfaceVariant,
        shape: small,
      ),
      // Pulsanti rettangolari con angoli di 4 px (non «a pillola»), testo semigrassetto, altezza 32.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: small,
          textStyle: buttonText,
          padding: buttonPadding,
          minimumSize: const Size(64, 32),
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: small,
          textStyle: buttonText,
          padding: buttonPadding,
          minimumSize: const Size(64, 32),
          elevation: 0,
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: small,
          textStyle: buttonText,
          padding: buttonPadding,
          minimumSize: const Size(64, 32),
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: small,
          textStyle: buttonText,
          padding: buttonPadding,
          minimumSize: const Size(48, 32),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(shape: small)),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: small,
          textStyle: buttonText,
          side: BorderSide(color: scheme.outline),
          selectedBackgroundColor: scheme.primaryContainer,
          selectedForegroundColor: dark ? Colors.white : scheme.onPrimaryContainer,
        ),
      ),
      toggleButtonsTheme: const ToggleButtonsThemeData(borderRadius: BorderRadius.all(Radius.circular(radius))),
      // Caselle di spunta quadrate con angoli di 2 px, come Fluent.
      checkboxTheme: CheckboxThemeData(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(2))),
        side: BorderSide(color: scheme.onSurfaceVariant),
      ),
      // Finestre di dialogo sul fondo della finestra (Material 3 le farebbe grigie), angoli di 8 px.
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(dialogRadius))),
        titleTextStyle: TextStyle(
          fontFamily: family,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      // Menu come i riquadri a comparsa di Fluent: fondo della finestra, bordo sottile, ombra leggera.
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(scheme.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(4),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: const BorderRadius.all(Radius.circular(radius)), side: flyoutBorder),
          ),
        ),
      ),
      menuButtonTheme: MenuButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(small),
          overlayColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.pressed)
                ? pressed
                : (s.contains(WidgetState.hovered) || s.contains(WidgetState.focused) ? hover : null),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(radius)),
          side: flyoutBorder,
        ),
      ),
      cardTheme: CardThemeData(color: scheme.surface, surfaceTintColor: Colors.transparent, shape: small),
      // Suggerimenti chiari con bordo, come in Office (Material li fa grigio scuro).
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.all(Radius.circular(radius)),
          border: Border.fromBorderSide(flyoutBorder),
          boxShadow: const [BoxShadow(color: Color(0x24000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        textStyle: TextStyle(fontFamily: family, fontSize: 12, color: scheme.onSurface),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: small,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(fontFamily: family, fontSize: 14, color: scheme.onInverseSurface),
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(radius),
        thumbColor: WidgetStatePropertyAll(scheme.onSurface.withValues(alpha: 0.35)),
      ),
      extensions: [chrome],
    );
  }
}

/// Colori della barra in alto (blu nel tema Colorato) e della banda delle schede della barra multifunzione (anche il
/// fondo intorno al riquadro dei comandi, V3).
@immutable
class OfficeChrome extends ThemeExtension<OfficeChrome> {
  const OfficeChrome({
    required this.titleBar,
    required this.onTitleBar,
    required this.tabBar,
    required this.onTabBar,
    required this.selectedTab,
  });

  /// Barra in alto (ricerca, Invia/ricevi) e il colore di testo e icone sopra di essa.
  final Color titleBar;
  final Color onTitleBar;
  final Color tabBar;
  final Color onTabBar;

  /// Testo e sottolineatura della scheda aperta.
  final Color selectedTab;

  /// Quelli del tema attuale; con un tema senza estensione (test, finestre a sé) i colori dello schema.
  static OfficeChrome of(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return theme.extension<OfficeChrome>() ??
        OfficeChrome(
          titleBar: scheme.surfaceContainer,
          onTitleBar: scheme.onSurface,
          tabBar: scheme.surfaceContainer,
          onTabBar: scheme.onSurface,
          selectedTab: scheme.primary,
        );
  }

  @override
  OfficeChrome copyWith({Color? titleBar, Color? onTitleBar, Color? tabBar, Color? onTabBar, Color? selectedTab}) =>
      OfficeChrome(
        titleBar: titleBar ?? this.titleBar,
        onTitleBar: onTitleBar ?? this.onTitleBar,
        tabBar: tabBar ?? this.tabBar,
        onTabBar: onTabBar ?? this.onTabBar,
        selectedTab: selectedTab ?? this.selectedTab,
      );

  @override
  OfficeChrome lerp(OfficeChrome? other, double t) {
    if (other == null) return this;
    return OfficeChrome(
      titleBar: Color.lerp(titleBar, other.titleBar, t)!,
      onTitleBar: Color.lerp(onTitleBar, other.onTitleBar, t)!,
      tabBar: Color.lerp(tabBar, other.tabBar, t)!,
      onTabBar: Color.lerp(onTabBar, other.onTabBar, t)!,
      selectedTab: Color.lerp(selectedTab, other.selectedTab, t)!,
    );
  }
}

/// Fondo del testo di una mail (scelta 2b dei temi): sempre bianco con testo scuro, anche con un tema scuro,
/// perché molte mail HTML hanno colori propri pensati per il fondo bianco.
class MessageSurface extends StatelessWidget {
  const MessageSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Theme(
    data: OfficeTheme.of(AppTheme.white),
    child: Material(key: const ValueKey('message-surface'), color: Colors.white, child: child),
  );
}
