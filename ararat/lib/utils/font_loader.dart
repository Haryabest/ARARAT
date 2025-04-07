import 'package:flutter/services.dart';

class FontLoader {
  static Future<void> loadFonts() async {
    await rootBundle.load('fonts/Inter_18pt-Regular.ttf');
    await rootBundle.load('fonts/Inter_18pt-Medium.ttf');
    await rootBundle.load('fonts/Inter_18pt-SemiBold.ttf');
    await rootBundle.load('fonts/Inter_18pt-Bold.ttf');
  }
} 