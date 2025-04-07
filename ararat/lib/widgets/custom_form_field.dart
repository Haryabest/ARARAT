import 'package:flutter/material.dart';
import 'package:ararat/core/theme/app_typography.dart';

class CustomFormField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final String? Function(String?)? validator;

  const CustomFormField({
    super.key,
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.validator,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: AppTypography.inputLabel,
        ),
        const SizedBox(height: 6),
        Stack(
          clipBehavior: Clip.none,
          children: [
            TextFormField(
              key: _formFieldKey,
              controller: widget.controller,
              obscureText: widget.obscureText,
              decoration: AppTypography.getInputDecoration(),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2F3036),
              ),
              validator: (value) {
                // Обновляем состояние _userInteracted на первую валидацию
                _userInteracted = true;
                return widget.validator?.call(value);
              },
              onChanged: (value) {
                _userInteracted = true;
                _validateInput(value);
              },
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
            if (_errorText != null)
              Positioned(
                bottom: -7,
                left: 0,
                child: Text(
                  _errorText!,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTypography.errorColor,
                  ),
                ),
              ),
          ],
        ),
        // Дополнительное пространство, когда есть ошибка
        SizedBox(height: _errorText != null ? 16 : 0),
      ],
    );
  }
} 