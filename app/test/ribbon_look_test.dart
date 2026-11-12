import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postinovip/settings/app_settings.dart';
import 'package:postinovip/ui/ribbon_parts.dart';
import 'package:postinovip/ui/theme.dart';

import 'view_test.dart' show start;

// Tappa «Aspetto», V3: barra multifunzione come l'Outlook classico di oggi.

void main() {
  testWidgets('«File» è una scheda come le altre, sulla banda chiara (niente blocco blu)', (tester) async {
    final (fake, _, _) = await start(tester);
    final file = find.widgetWithText(RibbonTabLabel, 'File');
    final home = find.widgetWithText(RibbonTabLabel, 'Home');
    expect(file, findsOneWidget);
    expect(tester.getRect(file).height, tester.getRect(home).height);
    expect(tester.getCenter(file).dy, tester.getCenter(home).dy);
    final fileText = tester.widget<Text>(find.descendant(of: file, matching: find.text('File')));
    expect(fileText.style?.color, const Color(0xFF242424)); // testo come le schede non aperte
    final homeText = tester.widget<Text>(find.descendant(of: home, matching: find.text('Home')));
    expect(homeText.style?.color, OfficeTheme.brand); // la scheda aperta è blu
    // Il menu File si apre ancora.
    await tester.tap(find.text('File'));
    await tester.pumpAndSettle();
    expect(find.text('Opzioni'), findsOneWidget);
    await fake.core.sse.close();
  });

  testWidgets('comandi in un riquadro chiaro arrotondato e staccato dai bordi; icone grigie', (tester) async {
    final (fake, settings, _) = await start(tester);
    final panel = find.byKey(const ValueKey('ribbon-panel'));
    final box = tester.widget<Container>(panel).decoration! as BoxDecoration;
    expect(box.color, Colors.white);
    expect(box.borderRadius, const BorderRadius.all(Radius.circular(OfficeTheme.dialogRadius)));
    final rect = tester.getRect(panel);
    expect(rect.left, greaterThan(0));
    expect(rect.right, lessThan(tester.view.physicalSize.width / tester.view.devicePixelRatio));
    // Icona di «Nuovo messaggio»: grigia, non più blu.
    final icon = tester.widget<Icon>(find.byIcon(FluentIcons.mail_add_24_regular));
    expect(icon.color, isNot(OfficeTheme.brand));
    expect(icon.size, 24);

    // Compressa: niente riquadro.
    await settings.setRibbonCollapsed(true);
    await tester.pumpAndSettle();
    expect(panel, findsNothing);
    await settings.setRibbonCollapsed(false);
    await settings.setTheme(AppTheme.black);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.descendant(of: find.widgetWithText(RibbonTabLabel, 'File'), matching: find.text('File')))
          .style
          ?.color,
      isNot(OfficeTheme.brand),
    );
    await fake.core.sse.close();
  });
}
