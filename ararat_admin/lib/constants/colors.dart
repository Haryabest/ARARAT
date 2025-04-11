import 'package:flutter/material.dart';

/// Цветовая палитра приложения
class AppColors {
  /// Основной цвет приложения
  static const Color primary = Color(0xFF50321B);
  
  /// Цвет фона приложения
  static const Color background = Color(0xFFFAF6F1);
  
  /// Цвет текста
  static const Color textMain = Color(0xFF2F3036);
  
  /// Цвет неактивных элементов
  static const Color inactive = Color(0xFFBDBDBD);
  
  /// Цвет кнопки с тёмным фоном
  static const Color darkButton = Color(0xFF424242);
  
  /// Цвет для элементов с повышенным вниманием
  static const Color attention = Color(0xFFE53935);
  
  /// Цвет успешного действия
  static const Color success = Color(0xFF43A047);
  
  // Запрещаем создание экземпляра класса
  AppColors._();
} 