import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Получить текущего пользователя
  User? get currentUser => _auth.currentUser;

  // Вход через Email и пароль
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  // Регистрация через Email и пароль
  Future<UserCredential> registerWithEmailAndPassword(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  // Обновление отображаемого имени пользователя
  Future<void> updateDisplayName(String displayName) async {
    await _auth.currentUser?.updateDisplayName(displayName.trim());
  }

  // Выход из системы
  Future<void> signOut() async {
    return await _auth.signOut();
  }
  
  // Анонимная авторизация (быстрый вход без регистрации)
  Future<UserCredential> signInAnonymously() async {
    return await _auth.signInAnonymously();
  }
  
  // Вспомогательный метод для определения платформы
  bool isMobile() {
    return true; // В Flutter Mobile это всегда будет true
  }

  // Инициирование процесса входа по телефону
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      timeout: const Duration(seconds: 60),
    );
  }
  
  // Вход с использованием полученного кода подтверждения
  Future<UserCredential> signInWithPhoneCredential(PhoneAuthCredential credential) async {
    return await _auth.signInWithCredential(credential);
  }
} 