import 'package:flutter/material.dart';
import 'package:ararat/core/theme/app_typography.dart';

class CustomFormField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputType keyboardType;
  final int? maxLines;
  final int? minLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final String? hintText;
  final bool enabled;
  final FocusNode? focusNode;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool autofocus;
  final EdgeInsetsGeometry? contentPadding;
  final BoxConstraints? constraints;
  final Color? fillColor;
  final Color? textColor;
  final Color? labelColor;
  final Color? hintColor;
  final double? fontSize;
  final FontWeight? fontWeight;
  final String? errorText;
  final bool isRequired;
  final bool isAuthScreen;

  const CustomFormField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.minLines,
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
    this.prefixIcon,
    this.hintText,
    this.enabled = true,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.contentPadding,
    this.constraints,
    this.fillColor,
    this.textColor,
    this.labelColor,
    this.hintColor,
    this.fontSize,
    this.fontWeight,
    this.errorText,
    this.isRequired = false,
    this.isAuthScreen = false,
  });

  @override
  State<CustomFormField> createState() => _CustomFormFieldState();
}

class _CustomFormFieldState extends State<CustomFormField> {
  String? _errorText;
  final _formFieldKey = GlobalKey<FormFieldState>();
  late final void Function() _textEditingListener;
  bool _userInteracted = false;

  void _validateInput(String? value) {
    if (!_userInteracted) return;
    
    final error = widget.validator?.call(value);
    if (_errorText != error) {
      setState(() {
        _errorText = error;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _textEditingListener = () {
      _validateInput(widget.controller.text);
    };
    widget.controller.addListener(_textEditingListener);
    // При инициализации НЕ выполняем валидацию
  }

  @override
  void dispose() {
    widget.controller.removeListener(_textEditingListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Выбираем стиль в зависимости от типа экрана
    final isAuth = widget.isAuthScreen;
    
    // Цвета для формы входа/регистрации
    final defaultLabelColor = isAuth ? const Color(0xFF2F3036) : Colors.white;
    final defaultTextColor = isAuth ? const Color(0xFF2F3036) : Colors.white;
    final defaultFillColor = isAuth ? Colors.white : const Color(0xFF6C4425);
    final defaultHintColor = isAuth 
        ? const Color(0xFF2F3036).withOpacity(0.5) 
        : Colors.white.withOpacity(0.5);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Метка поля (Label)
        Row(
          children: [
            Text(
              widget.label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: widget.labelColor ?? defaultLabelColor,
              ),
            ),
            if (widget.isRequired)
              const Text(
                ' *',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        
        // Поле ввода с обработкой ошибок
        Stack(
          clipBehavior: Clip.none,
          children: [
            TextFormField(
              key: _formFieldKey,
              controller: widget.controller,
              validator: (value) {
                _userInteracted = true;
                final error = widget.validator?.call(value);
                if (_errorText != error) {
                  setState(() {
                    _errorText = error;
                  });
                }
                return error;
              },
              obscureText: widget.obscureText,
              keyboardType: widget.keyboardType,
              maxLines: widget.maxLines,
              minLines: widget.minLines,
              readOnly: widget.readOnly,
              onTap: widget.onTap,
              enabled: widget.enabled,
              focusNode: widget.focusNode,
              onChanged: (value) {
                _userInteracted = true;
                _validateInput(value);
                widget.onChanged?.call(value);
              },
              onFieldSubmitted: widget.onSubmitted,
              textInputAction: widget.textInputAction,
              textCapitalization: widget.textCapitalization,
              autofocus: widget.autofocus,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: widget.fontSize ?? 14,
                fontWeight: widget.fontWeight ?? (isAuth ? FontWeight.w600 : FontWeight.normal),
                color: widget.textColor ?? defaultTextColor,
              ),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: TextStyle(
                  color: widget.hintColor ?? defaultHintColor,
                  fontFamily: 'Inter',
                  fontSize: widget.fontSize ?? 14,
                  fontWeight: isAuth ? FontWeight.w600 : FontWeight.normal,
                ),
                filled: false,
                contentPadding: widget.contentPadding ?? 
                    (isAuth 
                        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 16)
                        : const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                constraints: widget.constraints,
                suffixIcon: widget.suffixIcon,
                prefixIcon: widget.prefixIcon,
                errorStyle: const TextStyle(
                  height: 0,
                  fontSize: 0,
                  color: Colors.transparent,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: isAuth 
                      ? const BorderSide(color: Color(0xFF2F3036), width: 1.5)
                      : BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: isAuth 
                      ? const BorderSide(color: Color(0xFF2F3036), width: 1.5)
                      : BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: isAuth 
                      ? const BorderSide(color: Color(0xFF2F3036), width: 1.5)
                      : const BorderSide(color: Color(0xFF4B260A), width: 1),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red, width: 1),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.red, width: 1),
                ),
              ),
            ),
            // Отображение текста ошибки под полем
            if (_errorText != null)
              Positioned(
                bottom: -20,
                left: 0,
                child: Text(
                  _errorText!,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isAuth ? AppTypography.errorColor : Colors.red,
                  ),
                ),
              ),
          ],
        ),
        // Пространство для отображения ошибки
        SizedBox(height: _errorText != null ? 16 : 0),
      ],
    );
  }
} 