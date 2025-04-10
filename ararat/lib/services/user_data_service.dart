import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ararat/screens/main/tabs/home_tab.dart';

/// Сервис для работы с пользовательскими данными в Firestore
class UserDataService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Получить ID текущего пользователя
  String? get _userId => _auth.currentUser?.uid;
  
  // Проверка аутентификации
  bool get isAuthenticated => _auth.currentUser != null;
  
  // Ссылка на коллекцию пользовательских данных
  CollectionReference get _usersCollection => _firestore.collection('users');
  
  // Ссылка на документ текущего пользователя
  DocumentReference? get _userDocument => 
      _userId != null ? _usersCollection.doc(_userId) : null;
  
  /// Сохраняет корзину пользователя в Firestore
  Future<void> saveCart(List<Map<String, dynamic>> cartItems) async {
    if (!isAuthenticated || _userDocument == null) return;
    
    try {
      await _userDocument!.set({
        'cart': cartItems.map((item) => _convertToFirestoreData(item)).toList(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Ошибка при сохранении корзины: $e');
      rethrow;
    }
  }
  
  /// Загружает корзину пользователя из Firestore
  Future<List<Map<String, dynamic>>> loadCart() async {
    if (!isAuthenticated || _userDocument == null) return [];
    
    try {
      DocumentSnapshot doc = await _userDocument!.get();
      if (doc.exists && doc.data() is Map<String, dynamic>) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('cart') && data['cart'] is List) {
          final List<dynamic> cartData = data['cart'] as List<dynamic>;
          return cartData.map((item) => item as Map<String, dynamic>).toList();
        }
      }
      return [];
    } catch (e) {
      print('Ошибка при загрузке корзины: $e');
      return [];
    }
  }
  
  /// Сохраняет избранное пользователя в Firestore
  Future<void> saveFavorites(List<Map<String, dynamic>> favorites) async {
    if (!isAuthenticated || _userDocument == null) return;
    
    try {
      await _userDocument!.set({
        'favorites': favorites.map((item) => _convertToFirestoreData(item)).toList(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Ошибка при сохранении избранного: $e');
      rethrow;
    }
  }
  
  /// Загружает избранное пользователя из Firestore
  Future<List<Map<String, dynamic>>> loadFavorites() async {
    if (!isAuthenticated || _userDocument == null) return [];
    
    try {
      DocumentSnapshot doc = await _userDocument!.get();
      if (doc.exists && doc.data() is Map<String, dynamic>) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('favorites') && data['favorites'] is List) {
          final List<dynamic> favoritesData = data['favorites'] as List<dynamic>;
          return favoritesData.map((item) => item as Map<String, dynamic>).toList();
        }
      }
      return [];
    } catch (e) {
      print('Ошибка при загрузке избранного: $e');
      return [];
    }
  }
  
  /// Сохраняет историю заказов пользователя в Firestore
  Future<void> saveOrderHistory(List<Map<String, dynamic>> orders) async {
    if (!isAuthenticated || _userDocument == null) return;
    
    try {
      await _userDocument!.set({
        'orderHistory': orders.map((item) => _convertToFirestoreData(item)).toList(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Ошибка при сохранении истории заказов: $e');
      rethrow;
    }
  }
  
  /// Загружает историю заказов пользователя из Firestore
  Future<List<Map<String, dynamic>>> loadOrderHistory() async {
    if (!isAuthenticated || _userDocument == null) return [];
    
    try {
      DocumentSnapshot doc = await _userDocument!.get();
      if (doc.exists && doc.data() is Map<String, dynamic>) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('orderHistory') && data['orderHistory'] is List) {
          final List<dynamic> historyData = data['orderHistory'] as List<dynamic>;
          return historyData.map((item) => item as Map<String, dynamic>).toList();
        }
      }
      return [];
    } catch (e) {
      print('Ошибка при загрузке истории заказов: $e');
      return [];
    }
  }
  
  /// Конвертирует Map в формат, подходящий для Firestore
  Map<String, dynamic> _convertToFirestoreData(Map<String, dynamic> data) {
    // Создаем копию для безопасности
    Map<String, dynamic> result = Map<String, dynamic>.from(data);
    
    // Преобразуем все числовые типы к double для единообразия
    if (result.containsKey('price') && result['price'] is int) {
      result['price'] = (result['price'] as int).toDouble();
    }
    
    return result;
  }
} 