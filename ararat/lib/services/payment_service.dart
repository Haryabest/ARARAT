import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uuid/uuid.dart';

class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Uuid _uuid = Uuid();
  
  // Коллекция платежей в Firestore
  CollectionReference get _paymentsCollection => _firestore.collection('payments');
  
  // Создать запись о платеже в Firestore
  Future<Map<String, dynamic>> createPayment({
    required String orderId,
    required double amount,
    required String paymentMethod,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('Пользователь не авторизован');
    }
    
    final String paymentId = _uuid.v4();
    final DateTime now = DateTime.now();
    
    // Данные для формирования QR-кода СБП (Система Быстрых Платежей)
    // Это примерный формат - в реальности нужно использовать данные вашего банка
    final String qrData = _generateQrData(
      paymentId: paymentId,
      amount: amount,
      description: 'Оплата заказа №${orderId.substring(0, 8)}'
    );
    
    // Создаем запись о платеже
    final paymentData = {
      'id': paymentId,
      'userId': user.uid,
      'orderId': orderId,
      'amount': amount,
      'status': 'pending', // pending, completed, failed
      'paymentMethod': paymentMethod,
      'qrData': qrData,
      'createdAt': now,
      'updatedAt': now,
    };
    
    // Сохраняем запись в Firestore
    await _paymentsCollection.doc(paymentId).set(paymentData);
    
    return {
      'paymentId': paymentId,
      'qrData': qrData,
    };
  }
  
  // Генерация данных для QR-кода
  String _generateQrData({
    required String paymentId,
    required double amount,
    required String description,
  }) {
    // Формат для СБП (в реальном приложении используйте данные вашего банка!)
    // Примерный формат данных для QR-кода
    return 'ST00012|' +
           'Name=ООО АРАРАТ|' +
           'PersonalAcc=40702810000000000000|' +
           'BIC=044525000|' +
           'CorrespAcc=30101810000000000000|' +
           'PayeeINN=7712345678|' +
           'KPP=771201001|' +
           'Purpose=$description|' +
           'PaymentId=$paymentId|' +
           'Sum=${(amount * 100).toInt()}';
  }
  
  // Проверка статуса платежа
  Future<String> checkPaymentStatus(String paymentId) async {
    try {
      final DocumentSnapshot paymentDoc = await _paymentsCollection.doc(paymentId).get();
      
      if (!paymentDoc.exists) {
        return 'not_found';
      }
      
      final paymentData = paymentDoc.data() as Map<String, dynamic>;
      return paymentData['status'] as String? ?? 'unknown';
    } catch (e) {
      print('Ошибка при проверке статуса платежа: $e');
      return 'error';
    }
  }
  
  // Обновление статуса платежа (для демонстрации; в реальности статус должен меняться после подтверждения от банка)
  Future<void> updatePaymentStatus(String paymentId, String status) async {
    await _paymentsCollection.doc(paymentId).update({
      'status': status,
      'updatedAt': DateTime.now(),
    });
    
    // Если платеж успешен, обновляем статус заказа
    if (status == 'completed') {
      await _updateOrderStatus(paymentId);
    }
  }
  
  // Обновление статуса заказа после успешной оплаты
  Future<void> _updateOrderStatus(String paymentId) async {
    try {
      // Получаем платеж
      final DocumentSnapshot paymentDoc = await _paymentsCollection.doc(paymentId).get();
      
      if (!paymentDoc.exists) {
        return;
      }
      
      final paymentData = paymentDoc.data() as Map<String, dynamic>;
      final String orderId = paymentData['orderId'] as String;
      
      // Получаем и обновляем заказ
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      
      if (orderDoc.exists) {
        await _firestore.collection('orders').doc(orderId).update({
          'status': 'оплачен',
          'paymentStatus': 'completed',
          'updatedAt': DateTime.now(),
        });
      }
    } catch (e) {
      print('Ошибка при обновлении статуса заказа: $e');
    }
  }
  
  // Отмена платежа
  Future<void> cancelPayment(String paymentId) async {
    await _paymentsCollection.doc(paymentId).update({
      'status': 'cancelled',
      'updatedAt': DateTime.now(),
    });
  }
} 