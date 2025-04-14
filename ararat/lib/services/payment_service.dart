import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:firebase_core/firebase_core.dart';

class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Uuid _uuid = Uuid();
  
  // Коллекции в Firestore
  CollectionReference get _paymentsCollection => _firestore.collection('payments');
  CollectionReference get _ordersCollection => _firestore.collection('orders');
  
  /// Создает запись платежа в Firestore и возвращает данные для QR-кода
  /// [orderId] - идентификатор заказа
  /// [amount] - сумма платежа
  /// [userId] - идентификатор пользователя
  Future<Map<String, dynamic>> createPayment(String orderId, double amount, String userId) async {
    try {
      // Создаем уникальный ID для платежа
      final paymentId = _paymentsCollection.doc().id;
      
      // Создаем документ платежа
      final paymentData = {
        'id': paymentId,
        'orderId': orderId,
        'userId': userId,
        'amount': amount,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isScanned': false,  // Добавляем поле для отслеживания сканирования
        'scanTime': null,    // Время сканирования
        'paymentMethod': 'qr',
      };
      
      // Записываем в Firestore
      await _paymentsCollection.doc(paymentId).set(paymentData);
      
      // Генерируем данные для QR-кода
      final qrData = generateQrData(paymentId, orderId, amount);
      
      return {
        'paymentId': paymentId,
        'qrData': qrData,
        'amount': amount,
      };
    } catch (e) {
      print('Ошибка при создании платежа: $e');
      rethrow;
    }
  }
  
  // Генерация уникального идентификатора QR-кода
  String _generateUniqueQrId() {
    // В реальной реализации СБП уникальные QR_ID предоставляются банком
    // Создаем строку фиксированной длины для QR_ID (20-25 символов)
    final String prefix = 'AD';
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(0, 8);
    final String random = _uuid.v4().replaceAll('-', '').substring(0, 10);
    
    // Соединяем части и обеспечиваем, что длина не превышает 25 символов
    String result = '$prefix$timestamp$random';
    if (result.length > 25) {
      result = result.substring(0, 25);
    }
    
    return result;
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
    try {
      // Обновляем статус платежа в БД
      await _paymentsCollection.doc(paymentId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Если платеж успешен, обновляем статус заказа
      if (status == 'completed') {
        await _updateOrderStatus(paymentId);
      }
    } catch (e) {
      print('Ошибка при обновлении статуса платежа: $e');
      throw Exception('Не удалось обновить статус платежа: $e');
    }
  }
  
  // Обновление статуса заказа после успешной оплаты
  Future<void> _updateOrderStatus(String paymentId) async {
    try {
      // Получаем платеж
      final DocumentSnapshot paymentDoc = await _paymentsCollection.doc(paymentId).get();
      
      if (!paymentDoc.exists) {
        throw Exception('Платеж не найден');
      }
      
      final paymentData = paymentDoc.data() as Map<String, dynamic>;
      final String orderId = paymentData['orderId'] as String;
      
      // Получаем и обновляем заказ
      final orderDoc = await _ordersCollection.doc(orderId).get();
      
      if (!orderDoc.exists) {
        throw Exception('Заказ не найден');
      }
      
      // Обновляем статус заказа на "оплачен"
      await _ordersCollection.doc(orderId).update({
        'status': 'оплачен',
        'paymentStatus': 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('Заказ $orderId успешно обновлен - статус: оплачен');
      return;
    } catch (e) {
      print('Ошибка при обновлении статуса заказа: $e');
      throw Exception('Не удалось обновить статус заказа: $e');
    }
  }
  
  // Отмена платежа
  Future<void> cancelPayment(String paymentId) async {
    await _paymentsCollection.doc(paymentId).update({
      'status': 'cancelled',
      'updatedAt': DateTime.now(),
    });
  }

  /// Отмечает QR-код как отсканированный
  /// Вызывается при первом открытии ссылки из QR-кода
  Future<bool> markQrAsScanned(String paymentId) async {
    try {
      // Проверяем, существует ли платеж
      final paymentDoc = await _paymentsCollection.doc(paymentId).get();
      if (!paymentDoc.exists) {
        print('Платеж не найден при попытке отметить как отсканированный: $paymentId');
        return false;
      }
      
      // Получаем текущее состояние платежа
      final paymentData = paymentDoc.data() as Map<String, dynamic>;
      
      // Проверяем, не был ли QR-код уже отсканирован
      if (paymentData['isScanned'] == true) {
        print('QR-код для платежа $paymentId уже был отмечен как отсканированный');
        return true;
      }
      
      // Обновляем статус в Firestore
      await _paymentsCollection.doc(paymentId).update({
        'isScanned': true,
        'scanTime': FieldValue.serverTimestamp(),
        'status': 'processing', // переход в статус "обрабатывается"
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('QR-код для платежа $paymentId успешно отмечен как отсканированный');
      return true;
    } catch (e) {
      print('Ошибка при отметке QR-кода как отсканированного: $e');
      return false;
    }
  }

  /// Проверяет, был ли QR-код отсканирован
  Future<bool> isQrCodeScanned(String paymentId) async {
    try {
      final paymentDoc = await _firestore.collection('payments').doc(paymentId).get();
      
      if (!paymentDoc.exists) {
        return false;
      }
      
      final paymentData = paymentDoc.data() as Map<String, dynamic>;
      return paymentData['isScanned'] == true;
    } catch (e) {
      print('Ошибка при проверке статуса сканирования QR-кода: $e');
      return false;
    }
  }

  /// Получает время сканирования QR-кода
  Future<DateTime?> getQrCodeScanTime(String paymentId) async {
    try {
      final paymentDoc = await _firestore.collection('payments').doc(paymentId).get();
      
      if (!paymentDoc.exists) {
        return null;
      }
      
      final paymentData = paymentDoc.data() as Map<String, dynamic>;
      final scanTime = paymentData['scanTime'];
      
      if (scanTime == null) {
        return null;
      }
      
      return (scanTime as Timestamp).toDate();
    } catch (e) {
      print('Ошибка при получении времени сканирования QR-кода: $e');
      return null;
    }
  }

  /// Обработка оплаты по ссылке
  /// Вызывается, когда пользователь переходит по ссылке из QR-кода
  Future<Map<String, dynamic>> confirmPaymentByUrl(String url) async {
    try {
      // Разбираем URL для извлечения параметров
      final uri = Uri.parse(url);
      final params = uri.queryParameters;
      
      // Извлекаем параметры
      final String? paymentId = params['paymentId'];
      final String? orderId = params['orderId'];
      final String? amountStr = params['amount'];
      
      // Проверяем параметры
      if (paymentId == null || orderId == null || amountStr == null) {
        print('Неверный формат URL: $url');
        return {
          'success': false,
          'error': 'Неверный формат URL платежа',
        };
      }
      
      // Преобразуем строку суммы в число
      final double amount;
      try {
        amount = double.parse(amountStr);
      } catch (e) {
        print('Ошибка преобразования суммы: $amountStr');
        return {
          'success': false,
          'error': 'Неверный формат суммы',
        };
      }
      
      print('Запрос на подтверждение платежа: ID=$paymentId, Заказ=$orderId, Сумма=$amount');
      
      // Получаем информацию о платеже из Firestore
      final paymentDoc = await _paymentsCollection.doc(paymentId).get();
      
      if (!paymentDoc.exists) {
        print('Платеж не найден: $paymentId');
        return {
          'success': false,
          'error': 'Платеж не найден',
        };
      }
      
      final paymentData = paymentDoc.data() as Map<String, dynamic>;
      
      // Проверяем соответствие данных
      final storedOrderId = paymentData['orderId'] as String;
      final storedAmount = (paymentData['amount'] as num).toDouble();
      
      if (storedOrderId != orderId) {
        print('Несоответствие ID заказа: $storedOrderId != $orderId');
        return {
          'success': false,
          'error': 'Несоответствие ID заказа',
        };
      }
      
      if ((storedAmount - amount).abs() > 0.01) {
        print('Несоответствие суммы: $storedAmount != $amount');
        return {
          'success': false,
          'error': 'Несоответствие суммы платежа',
        };
      }
      
      // Если платеж уже подтвержден, возвращаем true
      if (paymentData['status'] == 'completed') {
        print('Платеж уже был ранее подтвержден');
        return {
          'success': true,
          'paymentId': paymentId,
          'status': 'completed',
          'message': 'Платеж уже подтвержден',
        };
      }
      
      // Сначала отмечаем QR как отсканированный, если это еще не сделано
      if (paymentData['isScanned'] != true) {
        await markQrAsScanned(paymentId);
        print('QR-код отмечен как отсканированный');
        
        // Имитация задержки обработки платежа в банке
        await Future.delayed(Duration(seconds: 2));
      }
      
      // Обновляем статус платежа на "completed"
      await _paymentsCollection.doc(paymentId).update({
        'status': 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('Статус платежа обновлен на "completed"');
      
      // Обновляем статус заказа
      await _ordersCollection.doc(orderId).update({
        'status': 'оплачен',
        'paymentStatus': 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('Статус заказа $orderId обновлен на "оплачен"');
      return {
        'success': true,
        'paymentId': paymentId,
        'status': 'completed',
        'message': 'Платеж успешно обработан',
      };
    } catch (e) {
      print('Ошибка при подтверждении платежа: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Генерирует данные для QR-кода оплаты
  String generateQrData(String paymentId, String orderId, double amount) {
    // Создаем ссылку для подтверждения платежа
    // Используем Firebase хостинг приложения для обработки QR-кода
    final confirmationLink = 'https://arara-efa6f.web.app/payment-confirm?paymentId=$paymentId&orderId=$orderId&amount=$amount';
    
    // Для отладки можно использовать также локальный URL
    // final localTestLink = 'http://localhost:5001/ararat-80efa/us-central1/paymentConfirm?paymentId=$paymentId&orderId=$orderId&amount=$amount';
    
    print('Сгенерирована ссылка для QR-кода: $confirmationLink');
    return confirmationLink;
    
    /* Закомментированный код создания QR по формату СБП
    return 'ST00012|'
        'Name=ООО АРАРАТ|'
        'PersonalAcc=40702810138000001234|'
        'BankName=ПАО СБЕРБАНК|'
        'BIC=044525225|'
        'CorrespAcc=30101810400000000225|'
        'Sum=$amount|'
        'Purpose=Оплата заказа $orderId|'
        'PayeeINN=7730001234|'
        'KPP=770001001|'
        'CBC=18210301000010000110|'
        'OKTMO=45334000';
    */
  }

  /// Создает HTML страницу для подтверждения платежа
  /// Эта страница будет показана, когда пользователь сканирует QR-код и переходит по ссылке
  String generatePaymentConfirmationHtml(Map<String, dynamic> paymentData) {
    final String status = paymentData['success'] ? 'Успешно' : 'Ошибка';
    final String message = paymentData['message'] ?? paymentData['error'] ?? '';
    final String statusColor = paymentData['success'] ? 'green' : 'red';
    
    return '''
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Подтверждение платежа</title>
      <style>
        body {
          font-family: Arial, sans-serif;
          margin: 0;
          padding: 20px;
          background-color: #f5f5f5;
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          min-height: 100vh;
          text-align: center;
        }
        .payment-card {
          background-color: white;
          border-radius: 10px;
          box-shadow: 0 4px 8px rgba(0,0,0,0.1);
          padding: 30px;
          max-width: 400px;
          width: 100%;
        }
        .status {
          font-size: 24px;
          margin-bottom: 20px;
          color: ${statusColor};
          font-weight: bold;
        }
        .logo {
          margin-bottom: 20px;
          font-size: 28px;
          font-weight: bold;
          color: #663300;
        }
        .message {
          margin-bottom: 20px;
          color: #555;
        }
        .button {
          background-color: #663300;
          color: white;
          border: none;
          padding: 12px 24px;
          border-radius: 5px;
          cursor: pointer;
          font-size: 16px;
          transition: background-color 0.3s;
        }
        .button:hover {
          background-color: #8B4513;
        }
      </style>
    </head>
    <body>
      <div class="payment-card">
        <div class="logo">АРАРАТ</div>
        <div class="status">${status}</div>
        <div class="message">${message}</div>
        <p>Вы можете закрыть эту страницу и вернуться в приложение.</p>
        <button class="button" onclick="window.close()">Закрыть</button>
      </div>
    </body>
    </html>
    ''';
  }

  /// Создает Cloud Function для обработки платежных callbacks
  /// Это пример кода, который должен быть размещен в Firebase Functions
  /// 
  /// ```
  /// exports.handlePaymentCallback = functions.https.onRequest(async (req, res) => {
  ///   try {
  ///     const url = req.url;
  ///     
  ///     // Создаем экземпляр PaymentService
  ///     const paymentService = new PaymentService();
  ///     
  ///     // Обрабатываем платеж
  ///     const result = await paymentService.confirmPaymentByUrl(url);
  ///     
  ///     // Генерируем HTML страницу с ответом
  ///     const html = paymentService.generatePaymentConfirmationHtml(result);
  ///     
  ///     // Отправляем HTML в ответ
  ///     res.set('Content-Type', 'text/html');
  ///     res.send(html);
  ///   } catch (error) {
  ///     console.error('Ошибка при обработке платежа:', error);
  ///     res.status(500).send('Произошла ошибка при обработке платежа');
  ///   }
  /// });
  /// ```
} 