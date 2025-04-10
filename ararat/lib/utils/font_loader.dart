import 'package:flutter/services.dart';

class FontLoader {
  static Future<void> loadFonts() async {
    // Не нужно вручную загружать шрифты, так как они уже объявлены в pubspec.yaml
    // Flutter автоматически загрузит их при запуске приложения
    // Ждем немного для инициализации
    await Future.delayed(Duration(milliseconds: 100));
  }
} 