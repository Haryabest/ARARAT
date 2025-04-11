import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/address_model.dart';

/// Сервис для работы с адресами пользователя
class AddressService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Получение коллекции адресов текущего пользователя
  CollectionReference<Map<String, dynamic>> get _addressesCollection {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('Пользователь не авторизован');
    }
    return _firestore.collection('users').doc(userId).collection('addresses');
  }

  /// Проверка авторизации пользователя
  bool get isUserAuthenticated => _auth.currentUser != null;

  /// Получение списка адресов пользователя
  Future<List<AddressModel>> getAddresses() async {
    if (!isUserAuthenticated) {
      return [];
    }

    try {
      final querySnapshot = await _addressesCollection.get();
      return querySnapshot.docs
          .map((doc) => AddressModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Ошибка при получении адресов: $e');
      return [];
    }
  }

  /// Добавление нового адреса
  Future<String?> addAddress(AddressModel address) async {
    if (!isUserAuthenticated) {
      throw Exception('Пользователь не авторизован');
    }

    try {
      // Если адрес помечен как "по умолчанию", сначала сбрасываем этот флаг для всех адресов
      if (address.isDefault) {
        await _resetDefaultAddress();
      }

      // Добавляем новый адрес
      final docRef = await _addressesCollection.add(address.toMap());
      return docRef.id;
    } catch (e) {
      print('Ошибка при добавлении адреса: $e');
      return null;
    }
  }

  /// Обновление существующего адреса
  Future<bool> updateAddress(AddressModel address) async {
    if (!isUserAuthenticated) {
      throw Exception('Пользователь не авторизован');
    }

    try {
      // Если адрес помечен как "по умолчанию", сначала сбрасываем этот флаг для всех адресов
      if (address.isDefault) {
        await _resetDefaultAddress();
      }

      // Обновляем адрес
      await _addressesCollection.doc(address.id).update(address.toMap());
      return true;
    } catch (e) {
      print('Ошибка при обновлении адреса: $e');
      return false;
    }
  }

  /// Удаление адреса
  Future<bool> deleteAddress(String addressId) async {
    if (!isUserAuthenticated) {
      throw Exception('Пользователь не авторизован');
    }

    try {
      await _addressesCollection.doc(addressId).delete();
      return true;
    } catch (e) {
      print('Ошибка при удалении адреса: $e');
      return false;
    }
  }

  /// Установка адреса по умолчанию
  Future<bool> setDefaultAddress(String addressId) async {
    if (!isUserAuthenticated) {
      throw Exception('Пользователь не авторизован');
    }

    try {
      // Сначала сбрасываем флаг "по умолчанию" для всех адресов
      await _resetDefaultAddress();

      // Устанавливаем флаг для выбранного адреса
      await _addressesCollection.doc(addressId).update({'isDefault': true});
      return true;
    } catch (e) {
      print('Ошибка при установке адреса по умолчанию: $e');
      return false;
    }
  }

  /// Получение адреса по умолчанию
  Future<AddressModel?> getDefaultAddress() async {
    if (!isUserAuthenticated) {
      return null;
    }

    try {
      final querySnapshot = await _addressesCollection
          .where('isDefault', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      final doc = querySnapshot.docs.first;
      return AddressModel.fromMap(doc.data(), doc.id);
    } catch (e) {
      print('Ошибка при получении адреса по умолчанию: $e');
      return null;
    }
  }

  /// Сброс флага "по умолчанию" для всех адресов
  Future<void> _resetDefaultAddress() async {
    final batch = _firestore.batch();
    final querySnapshot = await _addressesCollection
        .where('isDefault', isEqualTo: true)
        .get();

    for (var doc in querySnapshot.docs) {
      batch.update(doc.reference, {'isDefault': false});
    }

    await batch.commit();
  }
} 