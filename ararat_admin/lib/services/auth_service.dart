import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Константы ролей пользователей
  static const String ROLE_USER = 'user';
  static const String ROLE_ADMIN = 'admin';

  // Получить текущего пользователя
  User? get currentUser => _auth.currentUser;

  // Получить роль текущего пользователя
  Future<String> getUserRole() async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        // Сначала проверяем, есть ли пользователь в коллекции admins
        DocumentSnapshot adminDoc = await _firestore.collection('admins').doc(user.uid).get();
        if (adminDoc.exists) {
          return ROLE_ADMIN;
        }
        
        // Если нет в admins, проверяем общую коллекцию users
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          return data['role'] ?? ROLE_USER;
        }
      } catch (e) {
        print('Ошибка при получении роли пользователя: $e');
      }
    }
    return ROLE_USER;
  }

  // Проверка является ли пользователь администратором
  Future<bool> isAdmin() async {
    User? user = _auth.currentUser;
    if (user == null) return false;
    
    try {
      // Проверяем наличие в коллекции admins
      DocumentSnapshot adminDoc = await _firestore.collection('admins').doc(user.uid).get();
      return adminDoc.exists;
    } catch (e) {
      print('Ошибка при проверке статуса администратора: $e');
      return false;
    }
  }

  // Вход через Email и пароль с проверкой на роль admin
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    UserCredential userCredential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    
    // Проверяем, является ли пользователь администратором
    bool isAdminUser = await isAdmin();
    if (!isAdminUser) {
      // Если пользователь не админ, выходим и выбрасываем исключение
      await _auth.signOut();
      throw FirebaseAuthException(
        code: 'permission-denied',
        message: 'У вас нет прав доступа к админ-панели'
      );
    }
    
    return userCredential;
  }

  // Регистрация через Email и пароль
  Future<UserCredential> registerWithEmailAndPassword(String email, String password) async {
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    
    // Создаем запись о пользователе в Firestore с ролью по умолчанию
    await _saveUserDataToFirestore(userCredential.user!.uid, {
      'email': email.trim(),
      'role': ROLE_ADMIN, // Назначаем роль администратора по умолчанию
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    // Создаем запись в специальной коллекции admins
    await _saveAdminDataToFirestore(userCredential.user!.uid, {
      'email': email.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    return userCredential;
  }

  // Сохранение данных администратора в отдельную коллекцию
  Future<void> _saveAdminDataToFirestore(String userId, Map<String, dynamic> data) async {
    await _firestore.collection('admins').doc(userId).set(
      data,
      SetOptions(merge: true),
    );
  }

  // Обновление отображаемого имени пользователя
  Future<void> updateDisplayName(String displayName) async {
    User? user = _auth.currentUser;
    if (user != null) {
      // Обновляем displayName в Firebase Auth
      await user.updateDisplayName(displayName.trim());
      
      // Обновляем данные в Firestore (users и admins)
      final updateData = {
        'displayName': displayName.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      await _saveUserDataToFirestore(user.uid, updateData);
      
      // Проверяем, есть ли пользователь в коллекции admins
      DocumentSnapshot adminDoc = await _firestore.collection('admins').doc(user.uid).get();
      if (adminDoc.exists) {
        await _saveAdminDataToFirestore(user.uid, updateData);
      }
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
    try {
      // Очищаем локальные кэши и данные пользователя
      // перед выходом из аккаунта Firebase
      
      // Выполняем выход из Firebase Auth
      await _auth.signOut();
      
      print('Пользователь успешно вышел из системы');
    } catch (e) {
      print('Ошибка при выходе из системы: $e');
      rethrow; // Пробрасываем ошибку дальше для обработки в UI
    }
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
  
  // Обновление пароля пользователя
  Future<void> updatePassword(String newPassword) async {
    try {
      print('Начало обновления пароля, длина пароля: ${newPassword.length}');
      
      if (newPassword.trim().isEmpty) {
        throw 'Пароль не может быть пустым';
      }
      
      final user = FirebaseAuth.instance.currentUser;
      
      // Проверяем, авторизован ли пользователь
      if (user == null) {
        print('Ошибка: пользователь не авторизован');
        throw FirebaseAuthException(
          code: 'user-not-signed-in',
          message: 'Пользователь не авторизован'
        );
      }
      
      print('Текущий пользователь: ${user.email}, uid: ${user.uid}');
      
      // Проверяем анонимного пользователя
      if (user.isAnonymous) {
        print('Ошибка: анонимный пользователь');
        throw FirebaseAuthException(
          code: 'operation-not-allowed',
          message: 'Анонимные пользователи не могут менять пароль'
        );
      }
      
      // Проверяем наличие email
      if (user.email == null || user.email!.isEmpty) {
        print('Ошибка: email не найден');
        throw FirebaseAuthException(
          code: 'email-not-found',
          message: 'Email пользователя не найден'
        );
      }
      
      // Проверяем время последнего входа
      final metadata = user.metadata;
      final lastSignInTime = metadata.lastSignInTime;
      final now = DateTime.now();
      
      print('Время последнего входа: ${lastSignInTime?.toString() ?? "неизвестно"}');
      print('Текущее время: ${now.toString()}');
      
      if (lastSignInTime != null) {
        final diffMinutes = now.difference(lastSignInTime).inMinutes;
        print('Разница в минутах: $diffMinutes');
        
        // Сокращаем до 1 минуты для тестирования
        if (diffMinutes > 1) {
          print('Требуется повторная аутентификация');
          throw FirebaseAuthException(
            code: 'requires-recent-login',
            message: 'Требуется повторный вход в систему для обновления пароля'
          );
        }
      }
      
      // Обновляем пароль
      print('Начинаем непосредственное обновление пароля');
      await user.updatePassword(newPassword);
      
      // Записываем событие в Firestore для логирования
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'passwordUpdatedAt': FieldValue.serverTimestamp(),
        });
        print('Запись о смене пароля сохранена в Firestore');
      } catch (e) {
        // Ошибки при обновлении Firestore не считаем критичными
        print('Ошибка записи в Firestore: $e');
      }
      
      print('Пароль успешно обновлен');
      return;
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException при обновлении пароля: ${e.code} - ${e.message}');
      
      // Обработка конкретных ошибок Firebase
      switch (e.code) {
        case 'weak-password':
          throw 'Слишком простой пароль. Используйте не менее 6 символов';
        case 'requires-recent-login':
          throw 'Для смены пароля требуется повторный вход в систему. Пожалуйста, выйдите и войдите снова.';
        case 'user-not-found':
          throw 'Пользователь не найден';
        case 'user-disabled':
          throw 'Аккаунт пользователя отключен';
        case 'network-request-failed':
          throw 'Проверьте подключение к интернету';
        default:
          throw 'Ошибка обновления пароля: ${e.message ?? e.code}';
      }
    } catch (e) {
      print('Неизвестная ошибка при обновлении пароля: $e');
      throw 'Не удалось обновить пароль: $e';
    }
  }
  
  // Обновление данных пользователя
  Future<void> updateUserData(Map<String, dynamic> data) async {
    User? user = _auth.currentUser;
    if (user != null) {
      // Обновляем displayName в Firebase Auth, если он есть в данных
      if (data.containsKey('displayName')) {
        await user.updateDisplayName(data['displayName']);
      }
      
      // Обновляем данные в Firestore
      await _saveUserDataToFirestore(user.uid, {
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Изменение роли пользователя (только для администраторов)
  Future<void> updateUserRole(String userId, String newRole) async {
    // Проверяем, является ли текущий пользователь администратором
    if (!await isAdmin()) {
      throw 'Недостаточно прав для изменения роли пользователя';
    }

    // Проверяем валидность новой роли
    if (newRole != ROLE_USER && newRole != ROLE_ADMIN) {
      throw 'Недопустимая роль пользователя';
    }

    try {
      await _firestore.collection('users').doc(userId).update({
        'role': newRole,
        'roleUpdatedAt': FieldValue.serverTimestamp(),
        'roleUpdatedBy': _auth.currentUser?.uid,
      });
    } catch (e) {
      print('Ошибка при обновлении роли пользователя: $e');
      throw 'Не удалось обновить роль пользователя';
    }
  }
} 