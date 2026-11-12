import 'package:flutter/material.dart';

/// Mittente di una mail diviso in nome e indirizzo: `Marta Conti <marta@x.it>` → (Marta Conti, marta@x.it);
/// `"Conti, Marta" <marta@x.it>` → (Conti, Marta, …); solo indirizzo → (indirizzo, indirizzo).
({String name, String address}) splitSender(String from) {
  final match = RegExp(r'^\s*(.*?)\s*<([^<>]+)>\s*$').firstMatch(from);
  if (match == null) return (name: from.trim(), address: from.trim());
  var name = match.group(1)!.trim();
  if (name.length >= 2 && name.startsWith('"') && name.endsWith('"')) name = name.substring(1, name.length - 1).trim();
  final address = match.group(2)!.trim();
  return (name: name.isEmpty ? address : name, address: address);
}

/// Iniziali del nome, come Outlook: le prime lettere delle prime due parole («Marta Conti» → «MC»); con un solo
/// nome o un indirizzo la prima lettera («laura.bianchi@…» → «L»). Vuoto se non c'è una lettera o una cifra.
String senderInitials(String name) {
  final words = name
      .split(RegExp(r'[\s,]+'))
      .map((w) => w.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), ''))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '';
  if (words.length == 1 || name.contains('@')) return words.first.characters.first.toUpperCase();
  return (words[0].characters.first + words[1].characters.first).toUpperCase();
}

/// Cerchio con le iniziali del mittente (tappa «Aspetto», V5), come il riquadro di lettura dell'Outlook di oggi.
/// Il colore viene dall'indirizzo: lo stesso mittente ha sempre lo stesso colore. Coppie fondo/testo prese dai colori
/// degli avatar di Fluent 2 (versione chiara; nei temi scuri fondo scuro e testo chiaro).
class SenderAvatar extends StatelessWidget {
  const SenderAvatar({super.key, required this.from, this.size = 40});

  final String from;
  final double size;

  static const _light = [
    (Color(0xFFF6D1D5), Color(0xFF750B1C)), // rosso scuro
    (Color(0xFFFDCFB4), Color(0xFF8A3707)), // zucca
    (Color(0xFFF2E6C3), Color(0xFF6B5E15)), // oro
    (Color(0xFFBDE5BE), Color(0xFF094509)), // foresta
    (Color(0xFFA6E9ED), Color(0xFF00666D)), // verde acqua
    (Color(0xFFCFE4FA), Color(0xFF0F548C)), // blu
    (Color(0xFFD7DAF7), Color(0xFF2F3487)), // blu reale
    (Color(0xFFE5D3F5), Color(0xFF461B6E)), // viola
    (Color(0xFFF7C0E3), Color(0xFF6D0F4A)), // magenta
    (Color(0xFFDDD5D0), Color(0xFF4D291C)), // visone
  ];

  /// Indice del colore: somma dei caratteri dell'indirizzo, stabile tra un avvio e l'altro (non `hashCode`).
  static int colorIndex(String address) =>
      address.toLowerCase().codeUnits.fold<int>(0, (sum, c) => (sum * 31 + c) & 0x7fffffff) % _light.length;

  @override
  Widget build(BuildContext context) {
    final sender = splitSender(from);
    final (bg, fg) = _light[colorIndex(sender.address)];
    final dark = Theme.of(context).brightness == Brightness.dark;
    final initials = senderInitials(sender.name);
    return Container(
      key: const Key('sender-avatar'),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: dark ? fg : bg, shape: BoxShape.circle),
      child: initials.isEmpty
          ? Icon(Icons.person_outline, size: size * 0.55, color: dark ? bg : fg)
          : Text(
              initials,
              style: Theme.of(context).textTheme.bodyMedium!
                  .copyWith(fontSize: size * 0.38, fontWeight: FontWeight.w600, color: dark ? bg : fg),
            ),
    );
  }
}
