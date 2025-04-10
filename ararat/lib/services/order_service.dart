import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ararat/widgets/checkout_form.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class Order {
  final String id;
  final String userId;
  final List<OrderItem> items;
  final double subtotal;
  final double deliveryCost;
  final double total;
  final String paymentMethod;
  final String deliveryType;
  final String status;
  final Map<String, dynamic> deliveryAddress;
  final String? phoneNumber;
  final String? comment;
  final bool leaveAtDoor;
  final DateTime createdAt;

  Order({
    required this.id,
    required this.userId,
    required this.items,
    required this.subtotal,
    required this.deliveryCost,
    required this.total,
    required this.paymentMethod,
    required this.deliveryType,
    required this.status,
    required this.deliveryAddress,
    required this.phoneNumber,
    required this.comment,
    required this.leaveAtDoor,
    required this.createdAt,
  });

  // Конвертация в Map для сохранения в Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'deliveryCost': deliveryCost,
      'total': total,
      'paymentMethod': paymentMethod,
      'deliveryType': deliveryType,
      'status': status,
      'deliveryAddress': deliveryAddress,
      'phoneNumber': phoneNumber,
      'comment': comment,
      'leaveAtDoor': leaveAtDoor,
      'createdAt': createdAt,
    };
  }

  // Создание объекта Order из данных Firestore
  factory Order.fromMap(Map<String, dynamic> map) {
    try {
      // Обработка списка товаров с проверкой на null
      List<OrderItem> itemsList = [];
      if (map['items'] != null) {
        try {
          final itemsData = map['items'] as List<dynamic>;
          for (var item in itemsData) {
            try {
              itemsList.add(orderItemFromMap(item as Map<String, dynamic>));
            } catch (e) {
              print('Ошибка при конвертации элемента заказа: $e');
            }
          }
        } catch (e) {
          print('Ошибка при обработке списка товаров: $e');
        }
      }
      
      // Безопасное преобразование чисел
      double subtotal = 0.0;
      if (map['subtotal'] != null) {
        subtotal = (map['subtotal'] is int) 
            ? (map['subtotal'] as int).toDouble()
            : (map['subtotal'] as num).toDouble();
      }
      
      double deliveryCost = 0.0;
      if (map['deliveryCost'] != null) {
        deliveryCost = (map['deliveryCost'] is int)
            ? (map['deliveryCost'] as int).toDouble()
            : (map['deliveryCost'] as num).toDouble();
      }
      
      double total = 0.0;
      if (map['total'] != null) {
        total = (map['total'] is int) 
            ? (map['total'] as int).toDouble()
            : (map['total'] as num).toDouble();
      }
      
      // Преобразование даты
      DateTime createdAt = DateTime.now();
      if (map['createdAt'] != null) {
        if (map['createdAt'] is Timestamp) {
          createdAt = (map['createdAt'] as Timestamp).toDate();
        } else if (map['createdAt'] is DateTime) {
          createdAt = map['createdAt'] as DateTime;
        }
      }

      return Order(
        id: map['id'] ?? '',
        userId: map['userId'] ?? '',
        items: itemsList,
        subtotal: subtotal,
        deliveryCost: deliveryCost,
        total: total,
        paymentMethod: map['paymentMethod'] ?? 'cash',
        deliveryType: map['deliveryType'] ?? 'standard',
        status: map['status'] ?? 'новый',
        deliveryAddress: map['deliveryAddress'] as Map<String, dynamic>? ?? {},
        phoneNumber: map['phoneNumber'] as String?,
        comment: map['comment'] as String?,
        leaveAtDoor: map['leaveAtDoor'] as bool? ?? false,
        createdAt: createdAt,
      );
    } catch (e) {
      print('Ошибка при создании Order из Map: $e');
      print('Данные: $map');
      rethrow;
    }
  }
}

// Класс для OrderItem, расширенный для сохранения в Firestore
extension OrderItemExtension on OrderItem {
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'quantity': quantity,
      'imageUrl': imageUrl,
    };
  }
}

// Вспомогательный метод для создания OrderItem из Map
OrderItem orderItemFromMap(Map<String, dynamic> map) {
  try {
    double price = 0.0;
    if (map['price'] != null) {
      if (map['price'] is int) {
        price = (map['price'] as int).toDouble();
      } else if (map['price'] is double) {
        price = map['price'] as double;
      } else if (map['price'] is num) {
        price = (map['price'] as num).toDouble();
      }
    }

    int quantity = 1;
    if (map['quantity'] != null) {
      if (map['quantity'] is int) {
        quantity = map['quantity'] as int;
      } else if (map['quantity'] is double) {
        quantity = (map['quantity'] as double).toInt();
      } else if (map['quantity'] is num) {
        quantity = (map['quantity'] as num).toInt();
      }
    }

    return OrderItem(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Товар',
      price: price,
      quantity: quantity,
      imageUrl: map['imageUrl'] as String?,
    );
  } catch (e) {
    print('Ошибка при создании OrderItem из Map: $e');
    print('Данные: $map');
    
    // Возвращаем базовый товар, чтобы не прерывать выполнение
    return OrderItem(
      id: '0',
      name: 'Ошибка загрузки товара',
      price: 0.0,
      quantity: 1,
    );
  }
}

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Uuid _uuid = Uuid();

  // Коллекция заказов в Firestore
  CollectionReference get _ordersCollection => _firestore.collection('orders');

  // Создание нового заказа
  Future<String> createOrder({
    required List<OrderItem> items,
    required double subtotal,
    required double deliveryCost,
    required String paymentMethod,
    required String deliveryType,
    required Map<String, dynamic> deliveryAddress,
    required String phoneNumber,
    String? comment,
    required bool leaveAtDoor,
    Map<String, dynamic>? metadata,
  }) async {
    User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('Пользователь не авторизован');
    }

    print('Создание заказа для пользователя: ${user.uid}');
    print('Email пользователя: ${user.email}');
    print('Аутентификация: ${user.isAnonymous ? "анонимная" : "с учетной записью"}');

    // Генерируем уникальный ID для заказа
    final String orderId = _uuid.v4();
    final double total = subtotal + deliveryCost;

    print('Сгенерирован ID заказа: $orderId');
    print('Общая сумма заказа: $total руб.');

    final Order order = Order(
      id: orderId,
      userId: user.uid,
      items: items,
      subtotal: subtotal,
      deliveryCost: deliveryCost,
      total: total,
      paymentMethod: paymentMethod,
      deliveryType: deliveryType,
      status: 'новый', // Начальный статус заказа
      deliveryAddress: deliveryAddress,
      phoneNumber: phoneNumber,
      comment: comment,
      leaveAtDoor: leaveAtDoor,
      createdAt: DateTime.now(),
    );

    try {
      // Подготавливаем подробную информацию о товарах
      final List<Map<String, dynamic>> detailedItems = order.items.map((item) => {
        'id': item.id,
        'name': item.name,
        'price': item.price,
        'quantity': item.quantity,
        'totalPrice': item.price * item.quantity,
        'imageUrl': item.imageUrl,
      }).toList();
      
      // Создаем улучшенную структуру данных заказа с подробностями
      final Map<String, dynamic> detailedOrderData = {
        'id': order.id,
        'userId': order.userId,
        'userEmail': user.email ?? 'Анонимный пользователь',
        'userDisplayName': user.displayName ?? 'Клиент',
        'isAnonymous': user.isAnonymous,
        
        // Подробные данные о товарах
        'items': detailedItems,
        'itemsCount': order.items.length,
        
        // Финансовая информация
        'subtotal': order.subtotal,
        'deliveryCost': order.deliveryCost,
        'total': order.total,
        
        // Информация о доставке
        'deliveryType': order.deliveryType,
        'deliveryAddress': order.deliveryAddress,
        'leaveAtDoor': order.leaveAtDoor,
        
        // Контактная информация
        'phoneNumber': order.phoneNumber,
        
        // Комментарий к заказу
        'comment': order.comment,
        
        // Метод оплаты
        'paymentMethod': order.paymentMethod,
        
        // Статус и время
        'status': order.status,
        'createdAt': Timestamp.fromDate(order.createdAt),
        'lastUpdatedAt': Timestamp.fromDate(order.createdAt),
        
        // Дополнительные метки
        'paymentStatus': 'не оплачен',
        'isCancelled': false,
        'source': 'mobile_app',
      };
      
      // Добавляем метаданные в данные заказа, если они предоставлены
      if (metadata != null) {
        detailedOrderData['metadata'] = metadata;
      }
      
      // Сохраняем детальный заказ в основную коллекцию orders
      await _firestore.collection('orders').doc(orderId).set(detailedOrderData);
      
      print('Заказ успешно сохранен в коллекцию orders с подробными данными');
      
      // Добавляем ссылку на заказ в коллекцию пользователя с расширенной информацией
      final Map<String, dynamic> userOrderRef = {
        'orderId': orderId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'status': 'новый',
        'paymentStatus': 'не оплачен',
        'total': total,
        'items': detailedItems,
        'itemsCount': order.items.length,
        'deliveryType': order.deliveryType,
        'deliveryAddress': {
          'address': order.deliveryAddress['address'],
          'isApartment': order.deliveryAddress['isApartment']
        },
        'phoneNumber': order.phoneNumber,
      };
      
      print('Сохранение ссылки на заказ в профиле пользователя...');
      
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('orders')
          .doc(orderId)
          .set(userOrderRef);
      
      // Также сохраняем заказ в основном профиле пользователя для облегчения поиска
      final userDocRef = _firestore.collection('users').doc(user.uid);
      
      // Проверяем существование документа пользователя
      final userDoc = await userDocRef.get();
      if (!userDoc.exists) {
        // Создаем документ пользователя, если он не существует
        await userDocRef.set({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
          'createdAt': FieldValue.serverTimestamp(),
          'lastActiveAt': FieldValue.serverTimestamp(),
          'isAnonymous': user.isAnonymous,
          'orders': [orderId],
        });
        print('Создан новый профиль пользователя с заказом');
      } else {
        // Обновляем существующий документ
        await userDocRef.update({
          'lastActiveAt': FieldValue.serverTimestamp(),
          'orders': FieldValue.arrayUnion([orderId]),
        });
        print('Обновлен профиль пользователя с новым заказом');
      }

      print('Заказ успешно создан: $orderId');
      return orderId;
    } catch (e) {
      print('Ошибка при создании заказа: $e');
      // Добавляем информацию о контексте ошибки
      print('Детали заказа:');
      print('ID: $orderId');
      print('Пользователь: ${user.uid}');
      print('Сумма: $total руб.');
      
      throw Exception('Не удалось создать заказ: ${e.toString()}');
    }
  }

  // Получение всех заказов текущего пользователя
  Future<List<Order>> getUserOrders() async {
    User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('Пользователь не авторизован');
    }

    try {
      print('Начинаем загрузку заказов для пользователя: ${user.uid}');
      
      // Получаем ID всех заказов пользователя
      final orderRefs = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .get();

      // Если у пользователя нет заказов
      if (orderRefs.docs.isEmpty) {
        print('У пользователя нет заказов');
        return [];
      }

      print('Найдено заказов: ${orderRefs.docs.length}');
      
      // Получаем данные по каждому заказу
      List<Order> orders = [];
      for (var doc in orderRefs.docs) {
        try {
          final String? orderId = doc.data()['orderId'] as String?;
          if (orderId == null) {
            print('Ошибка: orderId отсутствует в документе ${doc.id}');
            continue;
          }
          
          print('Загрузка заказа с ID: $orderId');
          final orderDoc = await _ordersCollection.doc(orderId).get();
          
          if (!orderDoc.exists) {
            print('Заказ с ID $orderId не найден в коллекции orders');
            continue;
          }
          
          final orderData = orderDoc.data() as Map<String, dynamic>?;
          if (orderData == null) {
            print('Данные заказа $orderId пусты');
            continue;
          }
          
          try {
            orders.add(Order.fromMap(orderData));
            print('Заказ $orderId успешно загружен');
          } catch (e) {
            print('Ошибка при преобразовании заказа $orderId: $e');
            // Печатаем данные заказа для отладки
            print('Данные заказа: $orderData');
          }
        } catch (e) {
          print('Ошибка при обработке документа ${doc.id}: $e');
        }
      }

      print('Успешно загружено заказов: ${orders.length}');
      return orders;
    } catch (e) {
      print('Ошибка при получении заказов пользователя: $e');
      throw Exception('Не удалось загрузить заказы: ${e.toString()}');
    }
  }

  // Получение статуса заказа
  Future<String> getOrderStatus(String orderId) async {
    try {
      final orderDoc = await _ordersCollection.doc(orderId).get();
      if (orderDoc.exists) {
        return (orderDoc.data() as Map<String, dynamic>)['status'];
      }
      throw Exception('Заказ не найден');
    } catch (e) {
      print('Ошибка при получении статуса заказа: $e');
      throw e;
    }
  }

  // Отмена заказа
  Future<void> cancelOrder(String orderId) async {
    User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('Пользователь не авторизован');
    }

    try {
      // Проверяем, что заказ принадлежит пользователю
      final orderDoc = await _ordersCollection.doc(orderId).get();
      if (!orderDoc.exists) {
        throw Exception('Заказ не найден');
      }

      final orderData = orderDoc.data() as Map<String, dynamic>;
      if (orderData['userId'] != user.uid) {
        throw Exception('Доступ запрещен');
      }

      // Обновляем статус заказа
      await _ordersCollection.doc(orderId).update({
        'status': 'отменен',
      });

      print('Заказ успешно отменен: $orderId');
    } catch (e) {
      print('Ошибка при отмене заказа: $e');
      throw e;
    }
  }
  
  // Получение данных заказа по ID
  Future<Order> getOrderById(String orderId) async {
    User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('Пользователь не авторизован');
    }

    try {
      final orderDoc = await _ordersCollection.doc(orderId).get();
      if (!orderDoc.exists) {
        throw Exception('Заказ не найден');
      }

      final orderData = orderDoc.data() as Map<String, dynamic>;
      // Проверяем, принадлежит ли заказ текущему пользователю
      if (orderData['userId'] != user.uid) {
        throw Exception('Доступ запрещен');
      }

      return Order.fromMap(orderData);
    } catch (e) {
      print('Ошибка при получении заказа: $e');
      throw e;
    }
  }
  
  // Обновление заказа
  Future<void> updateOrder({
    required String orderId,
    String? paymentMethod,
    String? phoneNumber,
    String? comment,
    bool? leaveAtDoor,
    Map<String, dynamic>? deliveryAddress,
  }) async {
    User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('Пользователь не авторизован');
    }

    try {
      // Проверяем, что заказ существует и принадлежит пользователю
      final orderDoc = await _ordersCollection.doc(orderId).get();
      if (!orderDoc.exists) {
        throw Exception('Заказ не найден');
      }

      final orderData = orderDoc.data() as Map<String, dynamic>;
      if (orderData['userId'] != user.uid) {
        throw Exception('Доступ запрещен');
      }
      
      // Проверяем статус заказа - можно редактировать только новые заказы
      final String status = orderData['status'];
      if (status != 'новый') {
        throw Exception('Нельзя редактировать заказ со статусом "$status"');
      }

      // Собираем поля для обновления
      Map<String, dynamic> updateData = {};
      
      if (paymentMethod != null) {
        updateData['paymentMethod'] = paymentMethod;
      }
      
      if (phoneNumber != null) {
        updateData['phoneNumber'] = phoneNumber;
      }
      
      if (comment != null) {
        updateData['comment'] = comment;
      }
      
      if (leaveAtDoor != null) {
        updateData['leaveAtDoor'] = leaveAtDoor;
      }
      
      if (deliveryAddress != null) {
        updateData['deliveryAddress'] = deliveryAddress;
      }
      
      // Если нечего обновлять, прекращаем выполнение
      if (updateData.isEmpty) {
        return;
      }
      
      // Обновляем заказ
      await _ordersCollection.doc(orderId).update(updateData);
      
      print('Заказ успешно обновлен: $orderId');
    } catch (e) {
      print('Ошибка при обновлении заказа: $e');
      throw e;
    }
  }

  // Метод для диагностики соединения с Firebase
  Future<bool> checkFirebaseConnection() async {
    try {
      print('Проверка соединения с Firebase...');
      
      User? user = _auth.currentUser;
      if (user == null) {
        print('Ошибка: Пользователь не авторизован');
        return false;
      }
      
      print('Текущий пользователь: ${user.uid}');
      
      // Пробуем получить данные из Firestore
      final testDoc = await _firestore.collection('system').doc('connection_test').get();
      
      if (!testDoc.exists) {
        // Если документ не существует, создаем его
        await _firestore.collection('system').doc('connection_test').set({
          'lastChecked': FieldValue.serverTimestamp(),
          'checkedBy': user.uid,
          'status': 'online',
        });
        print('Соединение с Firestore установлено, тестовый документ создан');
      } else {
        // Обновляем существующий документ
        await _firestore.collection('system').doc('connection_test').update({
          'lastChecked': FieldValue.serverTimestamp(),
          'checkedBy': user.uid,
          'status': 'online',
        });
        print('Соединение с Firestore установлено, тестовый документ обновлен');
      }
      
      return true;
    } catch (e) {
      print('Ошибка при проверке соединения с Firebase: $e');
      return false;
    }
  }

  // Получение подробной информации о заказе по ID
  Future<Map<String, dynamic>> getOrderDetails(String orderId) async {
    User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('Пользователь не авторизован');
    }

    try {
      print('Получение подробной информации о заказе: $orderId');
      
      final orderDoc = await _ordersCollection.doc(orderId).get();
      if (!orderDoc.exists) {
        throw Exception('Заказ не найден');
      }

      final orderData = orderDoc.data() as Map<String, dynamic>;
      
      // Проверяем, принадлежит ли заказ текущему пользователю
      if (orderData['userId'] != user.uid) {
        print('Доступ запрещен: заказ не принадлежит текущему пользователю');
        throw Exception('Доступ запрещен');
      }
      
      // Получаем подробную информацию о товарах, если доступна
      List<Map<String, dynamic>> detailedItems = [];
      if (orderData['items'] != null) {
        final items = orderData['items'] as List<dynamic>;
        for (var item in items) {
          detailedItems.add(item as Map<String, dynamic>);
        }
      }
      
      // Получаем данные о доставке
      Map<String, dynamic> deliveryInfo = {
        'address': orderData['deliveryAddress']?['fullAddress'] ?? orderData['deliveryAddress']?['address'] ?? 'Адрес не указан',
        'type': _getDeliveryTypeText(orderData['deliveryType'] ?? 'standard'),
        'cost': orderData['deliveryCost'] ?? 0.0,
      };
      
      // Получаем данные о плательщике
      Map<String, dynamic> paymentInfo = {
        'method': _getPaymentMethodText(orderData['paymentMethod'] ?? 'cash'),
        'status': orderData['paymentStatus'] ?? 'не оплачен',
        'total': orderData['total'] ?? 0.0,
      };
      
      // Статус и время
      String status = orderData['status'] ?? 'новый';
      DateTime createdAt = (orderData['createdAt'] as Timestamp).toDate();
      DateTime? updatedAt = orderData['lastUpdatedAt'] != null 
          ? (orderData['lastUpdatedAt'] as Timestamp).toDate() 
          : null;
      
      // Формируем подробную информацию о заказе
      Map<String, dynamic> orderDetails = {
        'id': orderId,
        'itemsCount': orderData['itemsCount'] ?? detailedItems.length,
        'items': detailedItems,
        'delivery': deliveryInfo,
        'payment': paymentInfo,
        'status': status,
        'statusColor': _getStatusColor(status),
        'created': createdAt,
        'updated': updatedAt,
        'formattedDate': DateFormat('dd.MM.yyyy в HH:mm').format(createdAt),
        'comment': orderData['comment'],
        'phoneNumber': orderData['phoneNumber'],
        'isCancellable': status.toLowerCase() == 'новый' || status.toLowerCase() == 'в обработке',
      };
      
      print('Подробная информация о заказе успешно получена');
      return orderDetails;
    } catch (e) {
      print('Ошибка при получении подробной информации о заказе: $e');
      throw Exception('Не удалось получить информацию о заказе: ${e.toString()}');
    }
  }
  
  // Вспомогательный метод для получения текста типа доставки
  String _getDeliveryTypeText(String type) {
    switch (type.toLowerCase()) {
      case 'fast':
        return 'Срочная';
      case 'scheduled':
        return 'По расписанию';
      case 'standard':
      default:
        return 'Стандартная';
    }
  }
  
  // Вспомогательный метод для получения текста способа оплаты
  String _getPaymentMethodText(String method) {
    switch (method.toLowerCase()) {
      case 'qr':
        return 'QR-код';
      case 'cash':
      default:
        return 'Наличными';
    }
  }
  
  // Вспомогательный метод для получения цвета статуса
  String _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'новый':
        return '#2196F3'; // Blue
      case 'в обработке':
        return '#FF9800'; // Orange
      case 'доставляется':
        return '#9C27B0'; // Purple
      case 'выполнен':
        return '#4CAF50'; // Green
      case 'отменен':
        return '#F44336'; // Red
      default:
        return '#9E9E9E'; // Grey
    }
  }
} 