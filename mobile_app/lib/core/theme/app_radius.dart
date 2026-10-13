import 'package:flutter/painting.dart';

class AppRadius {
  AppRadius._();

  /// Small covers (<= 56px), track rows, list items
  static const double coverSmall = 4.0;

  /// Cards, grid items, preview covers
  static const double card = 6.0;

  /// Large headers, hero artwork
  static const double header = 8.0;

  // Convenience BorderRadius instances
  static const BorderRadius smallBorderRadius = BorderRadius.all(Radius.circular(coverSmall));
  static const BorderRadius cardBorderRadius = BorderRadius.all(Radius.circular(card));
  static const BorderRadius headerBorderRadius = BorderRadius.all(Radius.circular(header));
}
