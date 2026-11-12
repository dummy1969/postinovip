// Schermate dell'app con la casella d'esempio (V0 della tappa «Aspetto»). Non fa parte della suite: si lancia con
// `tools/schermate.sh`, che passa la cartella di destinazione e i caratteri da usare. Nessun core vero, nessuna rete.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/main.dart';
import 'package:postinovip/notify/window_presenter.dart';
import 'package:postinovip/settings/app_settings.dart';
import 'package:postinovip/state/calendar_model.dart';
import 'package:postinovip/state/reminder_model.dart';

import 'sample_core.dart';

final _env = Platform.environment;
final _out = Directory(_env['SCHERMATE_DIR'] ?? 'build/schermate');
final _warnings = <String>[];

class _NoWindow implements WindowPresenter {
  @override
  Future<void> present() async {}
}

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files.where((f) => f.isNotEmpty && File(f).existsSync())) {
    loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await loader.load();
}

/// Cartella di un pacchetto, letta da `.dart_tool/package_config.json`.
String _package(String name) {
  final config = jsonDecode(File('.dart_tool/package_config.json').readAsStringSync()) as Map<String, dynamic>;
  final entry = (config['packages'] as List).cast<Map<String, dynamic>>().firstWhere((p) => p['name'] == name);
  return Uri.parse('${entry['rootUri']}/').resolve(entry['packageUri'] as String).toFilePath();
}

/// Caratteri veri al posto di quello dei test (che disegna rettangoli): Inter dagli asset dell'app (come su Linux e
/// macOS dalla V1 della tappa «Aspetto»), il carattere di sistema per «sans-serif» (passato dallo script) sotto il
/// nome predefinito di Material, le icone di Material e quelle Fluent. Un testo che esce a rettangoli ha uno stile
/// senza carattere: nell'app vera prenderebbe quello predefinito del motore invece di Inter.
Future<void> _loadFonts() async {
  const inter = 'assets/fonts/inter/Inter-';
  await _font('Inter', [
    for (final w in ['Regular', 'Italic', 'Medium', 'SemiBold', 'Bold', 'BoldItalic']) '$inter$w.ttf',
  ]);
  final text = [
    for (final k in ['SCHERMATE_FONT_REGULAR', 'SCHERMATE_FONT_MEDIUM', 'SCHERMATE_FONT_BOLD']) _env[k] ?? '',
  ];
  await _font('Roboto', text);
  final flutter = _env['FLUTTER_ROOT'] ?? '';
  await _font('MaterialIcons', ['$flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
  final fluent = '${_package('fluentui_system_icons')}fonts/';
  await _font('packages/fluentui_system_icons/FluentSystemIcons-Regular', ['${fluent}FluentSystemIcons-Regular.ttf']);
  await _font('packages/fluentui_system_icons/FluentSystemIcons-Filled', ['${fluent}FluentSystemIcons-Filled.ttf']);
}

/// Avvia l'app con la casella d'esempio in una finestra di [size] punti, a densità 2 (schermate nitide).
Future<SampleCore> _start(
  WidgetTester tester, {
  Size size = const Size(1440, 900),
  AppTheme theme = AppTheme.colorful,
  ModuleBarPosition moduleBar = ModuleBarPosition.left,
  RibbonLayout ribbon = RibbonLayout.classic,
}) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.linux; // come sul desktop: barre di scorrimento, scorciatoie
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = size * 2;
  addTearDown(tester.view.reset);
  await tester.runAsync(_loadFonts);
  final now = DateTime.now();
  CalendarModel.now = () => DateTime(now.year, now.month, now.day, 10);
  addTearDown(() => CalendarModel.now = DateTime.now);
  final core = SampleCore(now);
  // Lettura manuale: aprire una mail non la segna come letta (sarebbe una scrittura).
  final settings = AppSettings(MemorySettingsStore())
    ..theme = theme
    ..moduleBar = moduleBar
    ..ribbonLayout = ribbon
    ..readMode = ReadMode.manual;
  // I trabocchi (testo più largo del suo spazio) non fermano la schermata: si annotano in avvisi.txt.
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (!text.contains('overflowed')) return previous?.call(details);
    final where = RegExp(r'lib/[\w/]+\.dart:\d+').firstMatch(details.toString())?.group(0) ?? '';
    _warnings.add('${tester.testDescription}: ${text.split('\n').first} ($where)');
  };
  addTearDown(() => FlutterError.onError = previous);
  await tester.pumpWidget(
    PostinoVipApp(
      api: ApiClient(httpClient: core.client),
      settings: settings,
      windowPresenter: _NoWindow(),
    ),
  );
  await tester.pumpAndSettle();
  return core;
}

/// Testi disegnati senza un carattere (uno stile che ha sostituito quello del tema): nell'app vera userebbero il
/// carattere predefinito del motore invece di Inter. Finiscono negli avvisi.
void _checkFonts(WidgetTester tester, String name) {
  final found = <String>{};
  void visit(RenderObject o) {
    if (o is RenderParagraph && o.text.style?.fontFamily == null) {
      final text = o.text.toPlainText().trim();
      if (text.isNotEmpty) found.add(text.length > 40 ? '${text.substring(0, 40)}…' : text);
    }
    o.visitChildren(visit);
  }

  for (final view in tester.binding.renderViews) {
    visit(view);
  }
  for (final text in found) {
    _warnings.add('$name: testo senza carattere: «$text»');
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  _checkFonts(tester, name);
  await tester.runAsync(() async {
    final image = await captureImage(tester.element(find.byType(PostinoVipApp)));
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    _out.createSync(recursive: true);
    File('${_out.path}/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
  // ignore: avoid_print
  print('schermata: ${_out.path}/$name.png');
}

Future<void> _finish(WidgetTester tester, SampleCore core) async {
  expect(core.writes, isEmpty, reason: 'le schermate non devono scrivere niente');
  await core.sse.close();
  debugDefaultTargetPlatformOverride = null;
}

Future<void> _openMain(WidgetTester tester) async {
  await tester.tap(find.text('Bozze della home page, terzo giro'));
  await tester.pumpAndSettle();
}

void main() {
  ReminderModel.enabled = false; // nessun promemoria che si apre sopra le schermate
  tearDownAll(() {
    _out.createSync(recursive: true);
    File('${_out.path}/avvisi.txt').writeAsStringSync(_warnings.isEmpty ? '' : '${_warnings.join('\n')}\n');
  });

  testWidgets('posta, tema chiaro', (tester) async {
    final core = await _start(tester);
    await _openMain(tester);
    await _shot(tester, '1-posta-chiaro');
    await _finish(tester, core);
  });

  testWidgets('posta, tema scuro', (tester) async {
    final core = await _start(tester, theme: AppTheme.black);
    await _openMain(tester);
    await _shot(tester, '2-posta-scuro');
    await _finish(tester, core);
  });

  testWidgets('nuovo messaggio', (tester) async {
    final core = await _start(tester);
    await tester.tap(find.text('Nuovo messaggio'));
    await _shot(tester, '3-nuovo-messaggio');
    await _finish(tester, core);
  });

  testWidgets('calendario, settimana lavorativa', (tester) async {
    final core = await _start(tester);
    await tester.tap(find.byKey(const Key('module-calendar')));
    await _shot(tester, '4-calendario');
    await _finish(tester, core);
  });

  testWidgets('posta, finestra piccola 640×480', (tester) async {
    final core = await _start(tester, size: const Size(640, 480));
    await _openMain(tester);
    await _shot(tester, '5-posta-640x480');
    await _finish(tester, core);
  });

  testWidgets('posta, barra dei moduli in basso, 640×480', (tester) async {
    final core = await _start(tester, size: const Size(640, 480), moduleBar: ModuleBarPosition.bottom);
    await _openMain(tester);
    await _shot(tester, '6-moduli-in-basso-640x480');
    await _finish(tester, core);
  });

  testWidgets('posta, barra semplificata', (tester) async {
    final core = await _start(tester, ribbon: RibbonLayout.simplified);
    await _openMain(tester);
    await _shot(tester, '7-barra-semplificata');
    await _finish(tester, core);
  });

  testWidgets('nuovo messaggio, barra semplificata', (tester) async {
    final core = await _start(tester, ribbon: RibbonLayout.simplified);
    await tester.tap(find.text('Nuovo messaggio'));
    await _shot(tester, '8-nuovo-messaggio-semplificata');
    await _finish(tester, core);
  });

  testWidgets('finestra Opzioni', (tester) async {
    final core = await _start(tester);
    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Opzioni'));
    await _shot(tester, '9-opzioni');
    await _finish(tester, core);
  });

  testWidgets('nuovo appuntamento', (tester) async {
    final core = await _start(tester);
    await tester.tap(find.byKey(const Key('module-calendar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nuovo appuntamento'));
    await _shot(tester, '10-appuntamento');
    await _finish(tester, core);
  });
}
