import 'package:firebase_auth/firebase_auth.dart';

/// Класс для перевода ошибок Firebase Authentication на русский язык
class FirebaseErrorTranslator {
  /// Переводит ошибку FirebaseAuthException на русский язык
  static String getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      // Ошибки при входе
      case 'invalid-email':
        return 'Некорректный формат электронной почты';
      case 'user-disabled':
        return 'Данная учетная запись отключена';
      case 'user-not-found':
        return 'Пользователь с такой почтой не найден';
      case 'wrong-password':
        return 'Неверный пароль';
      case 'invalid-credential':
        return 'Недействительные учетные данные';
      
      // Ошибки при регистрации
      case 'email-already-in-use':
        return 'Пользователь с такой почтой уже существует';
      case 'operation-not-allowed':
        return 'Данная операция не разрешена';
      case 'weak-password':
        return 'Слишком слабый пароль. Используйте более сложный пароль';
      
      // Ошибки при восстановлении пароля
      case 'expired-action-code':
        return 'Срок действия кода истек';
      case 'invalid-action-code':
        return 'Недействительный код действия';
      
      // Общие ошибки
      case 'network-request-failed':
        return 'Ошибка сети. Проверьте подключение к интернету';
      case 'too-many-requests':
        return 'Слишком много попыток входа. Пожалуйста, попробуйте позже';
      case 'captcha-check-failed':
        return 'Ошибка проверки captcha';
        
      // Если код ошибки не найден в списке
      default:
        if (e.message != null) {
          return 'Ошибка: ${e.message}';
        }
        return 'Произошла неизвестная ошибка';
    }
  }

  /// Переводит общую ошибку на русский язык
  static String getGeneralErrorMessage(Object e) {
    if (e is FirebaseAuthException) {
      return getErrorMessage(e);
    }
    return 'Произошла ошибка: $e';
  }
} 