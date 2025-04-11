import 'package:flutter/material.dart';

class AppTypography {
  // Цвета из дизайна
  static const Color textColor = Color(0xFF2F3036);
  static const Color accentColor = Color(0xFF50321B);
  static const Color errorColor = Color(0xFFC4302B);
  
  // Текстовые стили
  static const TextStyle heading = TextStyle(
    fontFamily: 'Inter',
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: textColor,
  );
  
  static const TextStyle inputLabel = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: textColor,
  );
  
  static const TextStyle inputText = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textColor,
  );
  
  static const TextStyle forgotPassword = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: accentColor,
  );
  
  static const TextStyle button = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Colors.white,
  );
  
  static const TextStyle smallText = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textColor,
  );
  
  static const TextStyle linkText = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: accentColor,
  );

  static const TextStyle errorText = TextStyle(
    fontFamily: 'Inter',
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: errorColor,
  );

  static InputDecoration getInputDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: textColor,
          width: 1.5,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: textColor,
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: Color(0xFF2F3036),
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16, 
        vertical: 16,
      ),
      errorStyle: const TextStyle(
        height: 0,
        color: Colors.transparent,
      ),
      errorMaxLines: 2,
    );
  }
} 