import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ararat/services/auth_service.dart';
import 'package:ararat/screens/main/main_screen.dart';
import 'package:ararat/core/theme/app_typography.dart';
import 'package:ararat/screens/registration/registration_screen.dart';
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
  
  bool _isLoading = false;
  String _errorMessage = '';
  
  final _authService = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  void _resetError() {
    setState(() {
      _errorMessage = '';
    });
  }

  Future<void> _login() async {
    _resetError();
    
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        final email = _emailController.text.trim();
        final password = _passwordController.text.trim();
        
        // Вход с email и паролем
        await _authService.signInWithEmailAndPassword(email, password);
        
        // Обновление данных пользователя для получения актуальной информации
        User? user = _authService.currentUser;
        if (user != null) {
          await user.reload();
        }
        
        if (mounted) {
          // Переход на главный экран
          Navigator.pushReplacementNamed(context, '/main');
        }
      } on FirebaseAuthException catch (e) {
        String message;
        
        switch (e.code) {
          case 'user-not-found':
            message = 'Пользователь с таким email не найден';
            break;
          case 'wrong-password':
            message = 'Неверный пароль';
            break;
          case 'invalid-email':
            message = 'Некорректный email';
            break;
          case 'user-disabled':
            message = 'Аккаунт заблокирован';
            break;
          default:
            message = 'Ошибка входа: ${e.message}';
        }
        
        setState(() {
          _errorMessage = message;
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _errorMessage = 'Ошибка: $e';
          _isLoading = false;
        });
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
                  Image.asset(
                    'assets/logo/logo-ararat-final.png',
                    height: 130,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 60),
                  
                  // Email поле
                  CustomFormField(
                    controller: _emailController,
                    label: 'Email',
                    isAuthScreen: true,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Обязательное поле';
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
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // Сообщение об ошибке
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  
                  const SizedBox(height: 20),
                  
                  // Кнопка Войти
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
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
                            'Войти',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                  
                  // Нет аккаунта? Зарегистрироваться
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
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const RegistrationScreen()),
                          );
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 