import 'package:flutter/material.dart';

/// Only stores [itemCount] as an extra.
class ExtendedPageController extends PageController {
  /// Creates a [ExtendedPageController] instance.
  ExtendedPageController({
    required this.itemCount,
    super.initialPage,
    super.keepPage,
    super.viewportFraction,
  });

  /// The number of items in the PageView.
  final int itemCount;
}
