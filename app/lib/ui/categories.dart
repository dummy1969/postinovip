import 'package:flutter/material.dart';

/// Colori delle sei categorie (3.3), nell'ordine delle parole chiave del core ($CatRossa … $CatViola).
/// Tinte della palette condivisa di Fluent, leggibili sia sul tema chiaro sia su quello scuro.
class CategoryColors {
  CategoryColors._();

  static const colors = [
    Color(0xFFD13438), // rossa
    Color(0xFFF7630C), // arancione
    Color(0xFFFFB900), // gialla
    Color(0xFF13A10E), // verde
    Color(0xFF0078D4), // blu
    Color(0xFF8764B8), // viola
  ];

  static Color of(int number) => colors[number - 1];
}

/// Quadratino del colore di una categoria (lista, menu).
class CategorySwatch extends StatelessWidget {
  const CategorySwatch(this.number, {super.key, this.size = 12});

  final int number;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: CategoryColors.of(number), borderRadius: BorderRadius.circular(2)),
  );
}

/// Etichetta colorata con il nome della categoria (riquadro di lettura).
class CategoryChip extends StatelessWidget {
  const CategoryChip({super.key, required this.number, required this.name});

  final int number;
  final String name;

  @override
  Widget build(BuildContext context) {
    final color = CategoryColors.of(number);
    // Testo scuro sulle tinte chiare (gialla, arancione), bianco sulle altre.
    final onColor = ThemeData.estimateBrightnessForColor(color) == Brightness.light ? Colors.black : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      child: Text(name, style: TextStyle(fontSize: 12, color: onColor)),
    );
  }
}
