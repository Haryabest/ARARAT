import 'package:flutter/material.dart';
import 'package:ararat/core/theme/app_typography.dart';
import 'package:ararat/widgets/custom_form_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Определяем цвета согласно дизайну
    const backgroundColor = Color(0xFFFAF6F1);
    const buttonColor = Color(0xFF50321B);
    
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 120),
              const Text(
                'ЛОГО ARARAT',
                style: TextStyle(
                  fontFamily: 'Inter',
                  package: null,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2F3036),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 80),
              
              // Логин/Почта поле
              CustomFormField(
                controller: _emailController,
                label: 'Логин/Почта',
                isAuthScreen: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Обязательное поле';
                  }
                  if (RegExp(r'[а-яА-ЯёЁ]').hasMatch(value)) {
                    return 'Русские символы не разрешены';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              
              // Пароль поле
              CustomFormField(
                controller: _passwordController,
                label: 'Пароль',
                obscureText: true,
                isAuthScreen: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Обязательное поле';
                  }
                  if (RegExp(r'[а-яА-ЯёЁ]').hasMatch(value)) {
                    return 'Русские символы не разрешены';
                  }
                  return null;
                },
              ),
              
              // Забыли пароль (с отступом вниз)
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () {
                    // Обработка нажатия "Забыли пароль?"
                  },
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(
                      'Забыли пароль?',
                      style: AppTypography.forgotPassword,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Кнопка Войти
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState?.validate() ?? false) {
                    // Переход на главный экран после успешной авторизации
                    Navigator.pushReplacementNamed(context, '/main');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 54),
                ),
                child: const Text(
                  'Войти',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              
              // Нет аккаунта
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Нет аккаунта? ',
                    style: AppTypography.smallText,
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacementNamed(context, '/registration');
                    },
                    child: const Text(
                      'Зарегистрироваться',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF50321B),
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xFF50321B),
                      ),
                    ),
                  ),
                ],
              ),
              
              // Разделитель
              const SizedBox(height: 40),
              const Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: Color(0xFF000000),
                      thickness: 1,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Войти с помощью',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF000000),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: Color(0xFF000000),
                      thickness: 1,
                    ),
                  ),
                ],
              ),
              
              // Социальные кнопки
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _socialButton('гугл', const Color(0xFF2E3139)),
                  _socialButton('эпл', const Color(0xFF2E3139)),
                  _socialButton('плей\nмаркет', const Color(0xFF2E3139)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _socialButton(String text, Color color) {
    return Container(
      height: 42,
      width: 80,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Text(
          text,
          style: AppTypography.smallText.copyWith(
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
} 