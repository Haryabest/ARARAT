import 'package:flutter/material.dart';
import 'package:ararat/core/theme/app_typography.dart';
import 'package:ararat/widgets/custom_form_field.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ararat/utils/firebase_error_translator.dart';
import 'package:ararat/services/auth_service.dart';
import 'package:ararat/screens/main/main_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  
  final _authService = AuthService();

  @override
  void dispose() {
    _loginController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      try {
        // Сохраняем логин для дальнейшего использования
        final String login = _loginController.text.trim();
        final String email = _emailController.text.trim();
        final String password = _passwordController.text.trim();
        
        // Создаем пользователя в Firebase
        final userCredential = await _authService.registerWithEmailAndPassword(
          email,
          password,
        );
        
        // Добавляем отображаемое имя (логин) в Firebase Auth и Firestore
        await _authService.updateDisplayName(login);
        
        // Reload user data to ensure everything is updated
        await _authService.currentUser?.reload();
        
        // Переход на главный экран после успешной регистрации
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/main');
        }
      } on FirebaseAuthException catch (e) {
        setState(() {
          _errorMessage = FirebaseErrorTranslator.getErrorMessage(e);
        });
      } catch (e) {
        setState(() {
          _errorMessage = FirebaseErrorTranslator.getGeneralErrorMessage(e);
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Определяем цвета согласно дизайну
    const backgroundColor = Color(0xFFFAF6F1);
    const buttonColor = Color(0xFF50321B);
    
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 80),
                  Column(
                    children: [
                      Image.asset(
                        'assets/logo/logo-ararat-final.png',
                        height: 130,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'ADMINS',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF50321B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 60),
                  
                  // Логин поле
                  CustomFormField(
                    controller: _loginController,
                    label: 'Логин',
                    isAuthScreen: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Обязательное поле';
                      }
                      if (RegExp(r'[а-яА-ЯёЁ]').hasMatch(value)) {
                        return 'Используйте латинские буквы';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // Почта поле
                  CustomFormField(
                    controller: _emailController,
                    label: 'Почта',
                    isAuthScreen: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Обязательное поле';
                      }
                      if (RegExp(r'[а-яА-ЯёЁ]').hasMatch(value)) {
                        return 'Русские символы не разрешены';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Пожалуйста, введите корректный email';
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
                      if (value.length < 6) {
                        return 'Пароль должен быть не менее 6 символов';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // Сообщение об ошибке
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  
                  const SizedBox(height: 20),
                  
                  // Кнопка Зарегистрироваться
                  ElevatedButton(
                    onPressed: _isLoading ? null : _register,
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
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Зарегистрироваться',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                  
                  // Есть аккаунт? Войти
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Есть аккаунт? ',
                        style: AppTypography.smallText,
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Войти',
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 