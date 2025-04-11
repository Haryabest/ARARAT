import 'package:flutter/material.dart';
import 'package:ararat/constants/colors.dart';

/// Универсальная кнопка для использования в приложении
class CustomButton extends StatelessWidget {
  /// Текст на кнопке
  final String text;
  
  /// Показывать ли индикатор загрузки
  final bool isLoading;
  
  /// Действие при нажатии
  final VoidCallback onPressed;
  
  /// Цвет кнопки
  final Color? color;
  
  /// Цвет текста
  final Color? textColor;
  
  /// Конструктор класса CustomButton
  const CustomButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.color,
    this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? AppColors.primary,
        foregroundColor: textColor ?? Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        elevation: 0,
        minimumSize: const Size(double.infinity, 54),
        disabledBackgroundColor: (color ?? AppColors.primary).withOpacity(0.7),
      ),
      child: isLoading
        ? const SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          )
        : Text(
            text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor ?? Colors.white,
            ),
          ),
    );
  }
} 