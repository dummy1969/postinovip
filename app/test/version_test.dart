import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:postinovip/app_info.dart';

/// La versione sta in tre punti da aggiornare insieme a ogni commit: qui si controlla che coincidano.
void main() {
  test('stessa versione in app_info.dart, pubspec.yaml e core/Directory.Build.props', () {
    final pubspec = RegExp(
      r'^version: (\S+)\+(\d+)$',
      multiLine: true,
    ).firstMatch(File('pubspec.yaml').readAsStringSync())!;
    final core = RegExp(r'<Version>([^<]+)</Version>')
        .firstMatch(File('../core/Directory.Build.props').readAsStringSync())!;

    expect(appVersion, matches(RegExp(r'^0\.0\.\d+$')));
    expect(pubspec[1], appVersion);
    expect(pubspec[2], appVersion.split('.').last, reason: 'numero di build = N di 0.0.N');
    expect(core[1], appVersion);
  });

  test('licenza mostrata nell\'app uguale al LICENSE del repository', () {
    expect(File('assets/licenses/AGPL-3.0.txt').readAsStringSync(), File('../LICENSE').readAsStringSync());
  });
}
