import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    
    // Создаем запись о пользователе в Firestore
    await _saveUserDataToFirestore(userCredential.user!.uid, {
      'email': email.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    return userCredential;
  }

  // Обновление отображаемого имени пользователя
  Future<void> updateDisplayName(String displayName) async {
    User? user = _auth.currentUser;
    if (user != null) {
      // Обновляем displayName в Firebase Auth
      await user.updateDisplayName(displayName.trim());
      
      // Обновляем данные в Firestore
      await _saveUserDataToFirestore(user.uid, {
        'displayName': displayName.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }
  
  // Метод для сохранения данных пользователя в Firestore
  Future<void> _saveUserDataToFirestore(String userId, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(userId).set(
      data,
      SetOptions(merge: true), // merge: true позволяет обновлять только указанные поля
    );
  }
  
  // Метод для получения данных пользователя из Firestore
  Future<Map<String, dynamic>?> getUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          return doc.data() as Map<String, dynamic>;
        }
      } catch (e) {
        print('Ошибка при получении данных пользователя: $e');
      }
    }
    return null;
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

  // Получение URL консоли Firebase для просмотра данных пользователя
  String getFirebaseConsoleUrl() {
    return 'https://console.firebase.google.com/';
  }
} 