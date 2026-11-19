import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

/// Lingua dell'interfaccia (tappa «Lingua», scelta 1a del 16/11/2026): come il sistema (predefinita) o scelta in
/// File → Opzioni → Generale. I nomi delle lingue si scrivono nella lingua stessa, come fanno i sistemi operativi.
/// Spagnolo, francese e tedesco aggiunti il 17/11/2026 (scelte 1a 2a 3a 4a).
enum AppLanguage {
  system,
  italian,
  english,
  spanish,
  french,
  german;

  /// Lingua fissata dall'utente; null = quella del sistema, risolta da [resolveLocale].
  Locale? get locale => switch (this) {
    AppLanguage.system => null,
    AppLanguage.italian => const Locale('it'),
    AppLanguage.english => const Locale('en'),
    AppLanguage.spanish => const Locale('es'),
    AppLanguage.french => const Locale('fr'),
    AppLanguage.german => const Locale('de'),
  };

  String label(AppLocalizations l) => switch (this) {
    AppLanguage.system => l.languageSystem,
    AppLanguage.italian => 'Italiano',
    AppLanguage.english => 'English',
    AppLanguage.spanish => 'Español',
    AppLanguage.french => 'Français',
    AppLanguage.german => 'Deutsch',
  };
}

/// Lingua quando si segue il sistema: la prima delle lingue preferite del sistema che l'app ha (it_CH → it, en_GB →
/// en); se non ce n'è nessuna, l'inglese (decisione di dettaglio da confermare).
Locale resolveLocale(List<Locale>? preferred) {
  for (final locale in preferred ?? const <Locale>[]) {
    for (final supported in AppLocalizations.supportedLocales) {
      if (supported.languageCode == locale.languageCode) return supported;
    }
  }
  return const Locale('en');
}

/// Testi nella lingua dell'interfaccia per il codice che non ha un `BuildContext` (notifiche, promemoria): stessa regola
/// del MaterialApp, con le lingue del sistema lette dal binding (nei test quelle finte del sistema dei test).
AppLocalizations l10nFor(AppLanguage language) =>
    lookupAppLocalizations(language.locale ?? resolveLocale(WidgetsBinding.instance.platformDispatcher.locales));

/// Frase con caselle dentro (finestra della ricorrenza): [template] tradotto con i segnaposto tra parentesi quadre
/// («Ogni [day] [month]», in inglese «Every [month] [day]»), [parts] le caselle per nome. L'ordine lo decide la lingua.
List<Widget> fillTemplate(String template, Map<String, Widget> parts) {
  final out = <Widget>[];
  var last = 0;
  for (final match in RegExp(r'\[(\w+)\]').allMatches(template)) {
    if (match.start > last) out.add(Text(template.substring(last, match.start)));
    out.add(parts[match.group(1)] ?? Text(match.group(0)!));
    last = match.end;
  }
  if (last < template.length) out.add(Text(template.substring(last)));
  return out;
}

/// Scorciatoia per i testi tradotti: `context.l10n.optionsTitle` invece di `AppLocalizations.of(context).optionsTitle`.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
