import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ararat/constants/colors.dart';
import 'dart:math' as Math;

class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String _filterStatus = 'all'; // Фильтр по статусу заказа

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await _firestore.collection('orders').orderBy('createdAt', descending: true).get();
      
      final orders = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        
        // Подробное логирование данных заказа для отладки
        print('Заказ #${doc.id}:');
        print('Статус: ${data['status']}');
        print('isDeleted: ${data['isDeleted']}');
        print('isCancelled: ${data['isCancelled']}');
        print('displayName: ${data['displayName']}');
        print('username: ${data['username']}');
        print('userName: ${data['userName']}');
        print('user: ${data['user']}');
        
        if (data['user'] is Map) {
          print('user.displayName: ${data['user']['displayName']}');
          print('user.username: ${data['user']['username']}');
        }
        
        print('phoneNumber: ${data['phoneNumber']}');
        print('phone: ${data['phone']}');
        
        // Логирование всего заказа
        print('Полные данные заказа: ${data.toString()}');
        
        return data;
      }).toList();
      
      if (!mounted) return;
      
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при загрузке заказов: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getStatusText(String status) {
    print('Преобразование статуса: $status');
    
    switch (status) {
      case 'new':
        return 'Новый';
      case 'processing':
        return 'В обработке';
      case 'shipped':
        return 'Отправлен';
      case 'delivered':
        return 'Доставлен';
      case 'canceled':
        return 'Отменен';
      case 'новый':
        return 'Новый';
      case 'в обработке':
        return 'В обработке';
      case 'отправлен':
        return 'Отправлен';
      case 'доставлен':
        return 'Доставлен';
      case 'отменен':
        return 'Отменен';
      case '':
        return 'Новый'; // Пустой статус считаем как "Новый"
      case null:
        return 'Новый'; // null статус считаем как "Новый"
      default:
        if (status == null) {
          return 'Новый';
        }
        return status; // Если статус не распознан, используем его как есть
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'new':
      case 'новый':
        return Colors.blue;
      case 'processing':
      case 'в обработке':
        return Colors.orange;
      case 'shipped':
      case 'отправлен':
        return Colors.purple;
      case 'delivered':
      case 'доставлен':
        return Colors.green;
      case 'canceled':
      case 'отменен':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Определяет текст статуса заказа с учетом отмены/удаления
  String _getOrderStatusText(Map<String, dynamic> order) {
    // Подробное логирование для отладки статуса
    print('Проверка статуса заказа #${order['id']}:');
    print('isDeleted: ${order['isDeleted']}');
    print('isCancelled: ${order['isCancelled']}');
    print('status: ${order['status']}');
    print('orderStatus: ${order['orderStatus']}');
    
    // Проверяем сначала на удаление
    if (order['isDeleted'] == true) {
      return 'Удален';
    }
    
    // Проверяем активные статусы "новый" и "new" с приоритетом
    String? status = order['status'];
    if (status == 'новый' || status == 'new' || status == 'Новый') {
      return 'Новый';
    }
    
    // Затем на отмену (проверяем все возможные параметры)
    if (order['isCancelled'] == true || 
        status == 'canceled' || 
        status == 'отменен' ||
        status == 'Отменен') {
      return 'Отменен';
    }
    
    // Для активных заказов без явного статуса используем "Новый"
    return _getStatusText(order['status'] ?? order['orderStatus'] ?? 'новый');
  }

  // Определяет цвет статуса заказа с учетом отмены/удаления
  Color _getOrderStatusColor(Map<String, dynamic> order) {
    // Цвет для удаленных заказов
    if (order['isDeleted'] == true) {
      return Colors.red.shade900;
    }
    
    // Проверяем активные статусы "новый" и "new" с приоритетом
    String? status = order['status'];
    if (status == 'новый' || status == 'new' || status == 'Новый') {
      return Colors.blue;
    }
    
    // Цвет для отмененных заказов (в любой форме)
    if (order['isCancelled'] == true || 
        status == 'canceled' || 
        status == 'отменен' ||
        status == 'Отменен') {
      return Colors.red;
    }
    
    // Для остальных заказов
    return _getStatusColor(order['status'] ?? 'новый');
  }

  // Фильтрует заказы по выбранному статусу
  List<Map<String, dynamic>> _filterOrders(List<Map<String, dynamic>> orders) {
    if (_filterStatus == 'all') {
      return orders;
    } else if (_filterStatus == 'active') {
      // Активные - не удалены и не отменены, или имеют статус "Новый"
      return orders.where((order) {
        // Проверяем на удаление
        if (order['isDeleted'] == true) return false;
        
        // Проверяем статус "Новый" (такие всегда в активных)
        String? status = order['status'];
        if (status == 'новый' || status == 'new' || status == 'Новый') return true;
        
        // Проверяем на отмену
        if (order['isCancelled'] == true) return false;
        
        // Проверяем на статус "отменен"
        if (status == 'canceled' || status == 'отменен' || status == 'Отменен') return false;
        
        // Если прошли все проверки, заказ считается активным
        return true;
      }).toList();
    } else if (_filterStatus == 'cancelled') {
      // Отмененные - отменены (по полю isCancelled или status), но не удалены и не "Новый"
      return orders.where((order) {
        // Проверяем на удаление (исключаем удаленные)
        if (order['isDeleted'] == true) return false;
        
        // Исключаем заказы со статусом "Новый"
        String? status = order['status'];
        if (status == 'новый' || status == 'new' || status == 'Новый') return false;
        
        // Проверяем на отмену
        if (order['isCancelled'] == true) return true;
        
        // Проверяем на статус "отменен"
        return status == 'canceled' || status == 'отменен' || status == 'Отменен';
      }).toList();
    } else if (_filterStatus == 'deleted') {
      // Удаленные - только удаленные, независимо от других статусов
      return orders.where((order) => order['isDeleted'] == true).toList();
    }
    return orders;
  }

  @override
  Widget build(BuildContext context) {
    // Фильтрация заказов
    final filteredOrders = _filterOrders(_orders);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: _loadOrders,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.refresh),
      ),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Заказы'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Все', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Активные', 'active'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Отмененные', 'cancelled'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Удаленные', 'deleted'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredOrders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.shopping_bag_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Заказы отсутствуют',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loadOrders,
                        child: const Text('Обновить'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadOrders,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredOrders.length,
                    itemBuilder: (context, index) {
                      final order = filteredOrders[index];
                      final status = order['status'] ?? 'новый';
                      final timestamp = order['createdAt'] as Timestamp?;
                      final date = timestamp != null
                          ? DateTime.fromMillisecondsSinceEpoch(
                              timestamp.millisecondsSinceEpoch)
                          : DateTime.now();
                      final formattedDate =
                          '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';

                      // Получаем логин клиента, используя тот же метод, что и в деталях заказа
                      final customerName = _getCustomerName(order);
                      
                      // Логируем полученное имя клиента
                      print('Имя клиента для заказа #${order['id']}: $customerName');
                      
                      // Получаем сумму заказа
                      final totalAmount = order['totalAmount'] ?? 
                                          order['total'] ?? 
                                          order['amount'] ?? 
                                          (order['items'] != null ? _calculateTotal(order['items']) : 0);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 2,
                        child: InkWell(
                          onTap: () {
                            // Детальная информация о заказе
                            _showOrderDetails(order);
                          },
                          onLongPress: () {
                            // Показать диалог подтверждения удаления
                            _showDeleteConfirmation(order);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Заказ #${order['id'].substring(0, Math.min<int>(8, order['id'].length))}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getOrderStatusColor(order).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _getOrderStatusText(order),
                                        style: TextStyle(
                                          color: _getOrderStatusColor(order),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Дата: $formattedDate',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Клиент: $customerName',
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Сумма: $totalAmount руб.',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (order['paymentStatus'] != null)
                                  Text(
                                    'Статус оплаты: ${order['paymentStatus']}',
                                    style: TextStyle(
                                      color: order['paymentStatus'] == 'оплачен' ? Colors.green : Colors.orange,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                // Отображение миниатюр товаров
                                if (order['items'] != null && order['items'] is List && (order['items'] as List).isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          for (var item in order['items'])
                                            if (item is Map && item['imageUrl'] != null)
                                              Container(
                                                width: 50,
                                                height: 50,
                                                margin: const EdgeInsets.only(right: 8),
                                                decoration: BoxDecoration(
                                                  border: Border.all(color: Colors.grey.shade300),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(4),
                                                  child: Image.network(
                                                    item['imageUrl'],
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) => 
                                                      const Center(child: Icon(Icons.image_not_supported, size: 20, color: Colors.grey)),
                                                  ),
                                                ),
                                              ),
                                        ],
                                      ),
                                    ),
                                  ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    OutlinedButton(
                                      onPressed: () {
                                        _showOrderDetails(order);
                                      },
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: AppColors.primary),
                                      ),
                                      child: const Text('Подробнее'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        // Изменить статус заказа
                                        _changeOrderStatus(order);
                                      },
                                      child: const Text('Изменить статус'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
  
  // Метод для расчета общей суммы по товарам заказа
  double _calculateTotal(List<dynamic> items) {
    double total = 0;
    for (var item in items) {
      if (item is Map) {
        final price = item['price'] ?? 0;
        final quantity = item['quantity'] ?? 1;
        total += (price * quantity);
      }
    }
    return total;
  }
  
  // Метод для отображения деталей заказа
  void _showOrderDetails(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxWidth: 600,
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Заказ #${order['id'].substring(0, Math.min<int>(8, order['id'].length))}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getOrderStatusText(order),
                        style: TextStyle(
                          color: _getOrderStatusColor(order),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Информация о клиенте
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Информация о клиенте',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildDetailRow('Логин', _getCustomerName(order)),
                            _buildDetailRow('Email', order['customerEmail'] ?? 
                                                 order['customer']?['email'] ?? 
                                                 order['userEmail'] ?? 
                                                 order['user']?['email'] ?? 
                                                 'Не указан'),
                            _buildDetailRow('Телефон', order['phoneNumber'] ?? 
                                                 order['phone'] ?? 
                                                 order['customerPhone'] ?? 
                                                 order['customer']?['phone'] ?? 
                                                 order['userPhone'] ?? 
                                                 order['user']?['phone'] ?? 
                                                 'Не указан'),
                          ],
                        ),
                      ),
                      
                      // Информация о статусе заказа
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _getOrderStatusColor(order).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _getOrderStatusColor(order).withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Статус заказа',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: _getOrderStatusColor(order),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: _getOrderStatusColor(order),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _getOrderStatusText(order),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _getOrderStatusColor(order),
                                  ),
                                ),
                              ],
                            ),
                            if (order['isDeleted'] == true || order['isCancelled'] == true)
                              const SizedBox(height: 4),
                            if (order['isDeleted'] == true)
                              Text('Заказ удален из списка активных заказов'),
                            if (order['isCancelled'] == true)
                              Text('Заказ был отменен клиентом'),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Информация о доставке
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Информация о доставке',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildDetailRow('Адрес', 
                                (order['deliveryAddress'] is Map) 
                                ? (order['deliveryAddress']['fullAddress'] ?? 
                                   order['deliveryAddress']['address']) 
                                : (order['address'] ?? 'Не указан')),
                            _buildDetailRow('Комментарий', order['comment'] ?? order['customerComment'] ?? 'Нет'),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Информация об оплате
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Информация об оплате',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildDetailRow('Способ оплаты', order['paymentMethod'] ?? 'Не указан'),
                            _buildDetailRow('Сумма', '${order['totalAmount'] ?? order['total'] ?? 0} руб.'),
                            _buildDetailRow('Статус оплаты', order['paymentStatus'] ?? 'Неизвестно'),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Товары в заказе
                      if (order['items'] != null && order['items'] is List && (order['items'] as List).isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Товары в заказе:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._buildOrderItems(order['items']),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              // Кнопки управления
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade200,
                      offset: const Offset(0, -2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      child: const Text('Закрыть'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _changeOrderStatus(order);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      child: const Text('Изменить статус'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Строка с информацией о заказе
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
  
  // Список товаров в заказе
  List<Widget> _buildOrderItems(List<dynamic> items) {
    return items.map((item) {
      if (item is! Map) return const SizedBox();
      
      final name = item['name'] ?? item['productName'] ?? 'Неизвестный товар';
      final price = item['price'] ?? 0;
      final quantity = item['quantity'] ?? 1;
      final imageUrl = item['imageUrl'];
      
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Изображение товара
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade200,
              ),
              child: imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => 
                        const Center(child: Icon(Icons.image_not_supported, color: Colors.grey)),
                    ),
                  )
                : const Center(child: Icon(Icons.image_not_supported, color: Colors.grey)),
            ),
            const SizedBox(width: 12),
            // Информация о товаре
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$price руб. × $quantity',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // Итоговая цена
            Text(
              '${price * quantity} руб.',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
  
  // Метод для изменения статуса заказа
  void _changeOrderStatus(Map<String, dynamic> order) {
    final currentStatus = order['status'] ?? 'новый';
    String newStatus = currentStatus; // Инициализируем текущим статусом
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Изменить статус заказа'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    title: const Text('Новый'),
                    value: 'новый',
                    groupValue: newStatus,
                    onChanged: (value) {
                      setState(() {
                        newStatus = value!;
                      });
                    },
                    activeColor: AppColors.primary,
                  ),
                  RadioListTile<String>(
                    title: const Text('В обработке'),
                    value: 'в обработке',
                    groupValue: newStatus,
                    onChanged: (value) {
                      setState(() {
                        newStatus = value!;
                      });
                    },
                    activeColor: AppColors.primary,
                  ),
                  RadioListTile<String>(
                    title: const Text('Отправлен'),
                    value: 'отправлен',
                    groupValue: newStatus,
                    onChanged: (value) {
                      setState(() {
                        newStatus = value!;
                      });
                    },
                    activeColor: AppColors.primary,
                  ),
                  RadioListTile<String>(
                    title: const Text('Доставлен'),
                    value: 'доставлен',
                    groupValue: newStatus,
                    onChanged: (value) {
                      setState(() {
                        newStatus = value!;
                      });
                    },
                    activeColor: AppColors.primary,
                  ),
                  RadioListTile<String>(
                    title: const Text('Отменен'),
                    value: 'отменен',
                    groupValue: newStatus,
                    onChanged: (value) {
                      setState(() {
                        newStatus = value!;
                      });
                    },
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    if (newStatus != currentStatus) {
                      await _updateOrderStatus(order['id'], newStatus);
                    }
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            );
          }
        );
      },
    );
  }
  
  // Обновление статуса заказа в базе данных
  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    if (!mounted) return;
    
    try {
      // Показываем индикатор загрузки
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Обновление статуса...'),
          duration: Duration(seconds: 1),
        ),
      );
      
      // Получаем текущий заказ для синхронизации всех полей
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) {
        throw Exception('Заказ не найден');
      }
      
      final orderData = orderDoc.data() as Map<String, dynamic>;
      final String userId = orderData['userId'] ?? '';
      final bool isCurrentlyDeleted = orderData['isDeleted'] == true;
      
      // Текущее время для обновления
      final now = FieldValue.serverTimestamp();
      
      // Обновляем поля в зависимости от статуса
      Map<String, dynamic> updateData = {
        'status': newStatus,
        'updatedAt': now,
        'lastUpdatedAt': now,
      };
      
      // Обновляем поле isCancelled, если статус "отменен"
      if (newStatus == 'отменен') {
        updateData['isCancelled'] = true;
        updateData['cancelledAt'] = now;
        updateData['cancelledBy'] = 'admin'; // Указываем, что отменено администратором
        
        // Если заказ был удалён, восстанавливаем его (убираем флаг isDeleted)
        if (isCurrentlyDeleted) {
          updateData['isDeleted'] = false;
          updateData['restoredAt'] = now;
          updateData['restoredBy'] = 'admin';
          print('Восстанавливаем удалённый заказ с новым статусом: $newStatus');
        }
      } else if (newStatus == 'новый' || newStatus == 'в обработке' || 
                 newStatus == 'отправлен' || newStatus == 'доставлен') {
        updateData['isCancelled'] = false;
        
        // Если заказ был удалён, восстанавливаем его (убираем флаг isDeleted)
        if (isCurrentlyDeleted) {
          updateData['isDeleted'] = false;
          updateData['restoredAt'] = now;
          updateData['restoredBy'] = 'admin';
          print('Восстанавливаем удалённый заказ с новым статусом: $newStatus');
        }
      }
      
      // Если меняем на "доставлен", добавляем дату доставки
      if (newStatus == 'доставлен') {
        updateData['deliveredAt'] = now;
      }
      
      // Применяем обновления в основной коллекции заказов
      await _firestore.collection('orders').doc(orderId).update(updateData);
      
      // Создаем уведомление для пользователя при любой смене статуса
      if (userId.isNotEmpty) {
        await _createOrderNotification(
          userId: userId,
          orderId: orderId,
          orderNumber: orderData['orderNumber'] ?? orderData['id'],
          status: newStatus,
        );
      }
      
      // Синхронизируем статус в коллекции пользователя, если известен userId
      if (userId.isNotEmpty) {
        try {
          final userOrderRef = _firestore.collection('users').doc(userId).collection('orders').doc(orderId);
          final userOrderDoc = await userOrderRef.get();
          
          // Если заказ был удалён и теперь восстановлен, или заказ не существует в активной коллекции
          if (isCurrentlyDeleted || !userOrderDoc.exists) {
            // Проверяем, не находится ли заказ в истории пользователя
            final userHistoryRef = _firestore
                .collection('users')
                .doc(userId)
                .collection('orderHistory')
                .doc(orderId);
                
            final historyDoc = await userHistoryRef.get();
            
            if (historyDoc.exists) {
              // Восстанавливаем заказ из истории
              final Map<String, dynamic> historyData = historyDoc.data() as Map<String, dynamic>;
              final Map<String, dynamic> originalData = historyData['originalData'] as Map<String, dynamic>;
              
              // Обновляем данные заказа и возвращаем его в активные
              originalData['status'] = newStatus;
              originalData['updatedAt'] = now;
              originalData['isCancelled'] = newStatus == 'отменен';
              originalData['isDeleted'] = false;
              
              // Создаем заказ в коллекции заказов пользователя
              await _firestore
                  .collection('users')
                  .doc(userId)
                  .collection('orders')
                  .doc(orderId)
                  .set(originalData);
                  
              // Удаляем из истории
              await userHistoryRef.delete();
              print('Заказ восстановлен из истории пользователя с новым статусом: $newStatus');
            } else {
              // Если в истории не найдено, создаем новый заказ на основе данных из основной коллекции
              Map<String, dynamic> newOrderData = Map<String, dynamic>.from(orderData);
              newOrderData['status'] = newStatus;
              newOrderData['updatedAt'] = now;
              newOrderData['isCancelled'] = newStatus == 'отменен';
              newOrderData['isDeleted'] = false;
              
              await userOrderRef.set(newOrderData);
              print('Создан новый заказ в коллекции пользователя с статусом: $newStatus');
            }
          } else if (userOrderDoc.exists) {
            // Если заказ существует в коллекции пользователя, просто обновляем его
            Map<String, dynamic> userUpdateData = {
              'status': newStatus,
              'updatedAt': now,
            };
            
            // Синхронизируем данные об отмене, если статус "отменен"
            if (newStatus == 'отменен') {
              userUpdateData['isCancelled'] = true;
            } else if (newStatus == 'новый' || newStatus == 'в обработке' || 
                     newStatus == 'отправлен' || newStatus == 'доставлен') {
              userUpdateData['isCancelled'] = false;
            }
            
            await userOrderRef.update(userUpdateData);
            print('Статус заказа успешно обновлен в коллекции пользователя');
          }
        } catch (e) {
          print('Ошибка при обновлении статуса в коллекции пользователя: $e');
          // Продолжаем выполнение, даже если не удалось обновить в коллекции пользователя
        }
      }
      
      // Обновляем список заказов
      await _loadOrders();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Статус заказа успешно обновлен'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        print('Ошибка при обновлении статуса: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при обновлении статуса: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Метод для создания уведомления о заказе
  Future<void> _createOrderNotification({
    required String userId,
    required String orderId,
    required dynamic orderNumber,
    required String status,
  }) async {
    try {
      // Получаем текст уведомления в зависимости от статуса
      String message = _getNotificationMessage(status, orderNumber);
      
      // Создаем данные уведомления
      Map<String, dynamic> notificationData = {
        'userId': userId,
        'orderId': orderId,
        'orderNumber': orderNumber,
        'message': message,
        'type': 'order_status',
        'status': status,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'data': {
          'orderId': orderId,
          'status': status,
        }
      };
      
      // Записываем уведомление в коллекцию notifications
      await _firestore.collection('notifications').add(notificationData);
      
      // Дублируем уведомление в коллекцию пользователя
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add(notificationData);
      
      print('Создано уведомление о смене статуса заказа на: $status');
    } catch (e) {
      print('Ошибка при создании уведомления: $e');
    }
  }
  
  // Метод для получения текста уведомления в зависимости от статуса
  String _getNotificationMessage(String status, dynamic orderNumber) {
    switch (status) {
      case 'новый':
        return 'Ваш заказ №$orderNumber принят в обработку. Спасибо за заказ!';
      case 'в обработке':
        return 'Ваш заказ №$orderNumber находится в обработке. Мы начали готовить его к отправке!';
      case 'отправлен':
        return 'Ваш заказ №$orderNumber отправлен и скоро будет доставлен!';
      case 'доставлен':
        return 'Ваш заказ №$orderNumber успешно доставлен. Спасибо за покупку!';
      case 'отменен':
        return 'Ваш заказ №$orderNumber был отменен администратором.';
      default:
        return 'Статус вашего заказа №$orderNumber изменен на: $status';
    }
  }

  // Метод для создания фильтрующих чипов
  Widget _buildFilterChip(String label, String status) {
    final isSelected = _filterStatus == status;
    
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      showCheckmark: false,
      backgroundColor: Colors.grey.shade200,
      selectedColor: AppColors.primary,
      onSelected: (selected) {
        setState(() {
          _filterStatus = status;
        });
      },
    );
  }

  // Метод для определения логина пользователя на основе email, телефона и других полей
  String _getCustomerName(Map<String, dynamic> order) {
    print('Определение логина пользователя для заказа: ${order['id']}');
    
    // 0. Проверяем кэш имен, если известен userId
    if (order['userId'] != null && _userNameCache.containsKey(order['userId'])) {
      print('Имя найдено в кэше: ${_userNameCache[order['userId']]}');
      return _userNameCache[order['userId']]!;
    }
    
    // 1. Проверяем прямые поля имени пользователя в порядке приоритета
    
    // Проверяем displayName (высший приоритет)
    if (order['displayName'] != null && order['displayName'].toString().trim().isNotEmpty) {
      return order['displayName'];
    }
    
    // Проверяем username
    if (order['username'] != null && order['username'].toString().trim().isNotEmpty) {
      return order['username'];
    }
    
    // Проверяем userName
    if (order['userName'] != null && order['userName'].toString().trim().isNotEmpty) {
      return order['userName'];
    }
    
    // Проверяем customerName
    if (order['customerName'] != null && order['customerName'].toString().trim().isNotEmpty) {
      return order['customerName'];
    }
    
    // 2. Проверяем вложенные объекты пользователя
    
    // Проверяем вложенный displayName в user
    if (order['user'] is Map && order['user']['displayName'] != null && 
        order['user']['displayName'].toString().trim().isNotEmpty) {
      return order['user']['displayName'];
    }
    
    // Проверяем вложенный username в user
    if (order['user'] is Map && order['user']['username'] != null && 
        order['user']['username'].toString().trim().isNotEmpty) {
      return order['user']['username'];
    }
    
    // 3. Проверяем userId и загружаем данные пользователя
    if (order['userId'] != null && order['userId'].toString().trim().isNotEmpty) {
      String userId = order['userId'];
      // Запускаем асинхронную загрузку имени
      _loadUserNameAsync(userId, order['id']);
      
      // Возвращаем временную заглушку до загрузки полного имени
      return 'Загрузка...';
    }
    
    // 4. Извлекаем имя из email, если доступен
    String? email = order['email'] ?? order['userEmail'] ?? order['user']?['email'];
    if (email != null && email.toString().trim().isNotEmpty) {
      if (email.contains('@')) {
        String username = email.split('@')[0];
        // Улучшение читаемости имен из email
        username = username.replaceAll(RegExp(r'\d+$'), ''); // Убираем цифры в конце
        username = username.replaceAll('.', ' '); // Заменяем точки на пробелы
        
        // Приводим к нормальному формату имени
        List<String> parts = username.split(' ');
        for (int i = 0; i < parts.length; i++) {
          if (parts[i].isNotEmpty) {
            parts[i] = parts[i][0].toUpperCase() + (parts[i].length > 1 ? parts[i].substring(1) : '');
          }
        }
        username = parts.join(' ');
        
        return username;
      }
      return email;
    }
    
    // 5. Используем номер телефона, если доступен
    String? phone = order['phoneNumber'] ?? order['phone'] ?? order['customer']?['phone'] ?? order['user']?['phone'];
    if (phone != null && phone.toString().trim().isNotEmpty) {
      return 'Клиент с телефоном: ${_formatPhone(phone)}';
    }
    
    // Если ничего не найдено
    return 'Неизвестный клиент';
  }
  
  // Форматирование номера телефона для удобочитаемости
  String _formatPhone(String phone) {
    // Убираем все нецифровые символы
    String cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    
    // Для российских номеров делаем красивый формат
    if (cleanPhone.length == 11 && (cleanPhone.startsWith('7') || cleanPhone.startsWith('8'))) {
      return '+7 ${cleanPhone.substring(1, 4)} ${cleanPhone.substring(4, 7)}-${cleanPhone.substring(7, 9)}-${cleanPhone.substring(9, 11)}';
    }
    
    // Для других номеров просто возвращаем как есть
    return phone;
  }
  
  // Асинхронная загрузка имени пользователя из коллекции users
  Future<void> _loadUserNameAsync(String userId, String orderId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        print('Данные пользователя для заказа $orderId получены:');
        print('displayName: ${userData['displayName']}, username: ${userData['username']}, email: ${userData['email']}');
        
        String userName = 'Неизвестный пользователь';
        
        // Ищем имя пользователя в полученных данных в порядке приоритета
        if (userData['displayName'] != null && userData['displayName'].toString().trim().isNotEmpty) {
          userName = userData['displayName'];
        } else if (userData['username'] != null && userData['username'].toString().trim().isNotEmpty) {
          userName = userData['username'];
        } else if (userData['email'] != null && userData['email'].toString().trim().isNotEmpty) {
          String email = userData['email'];
          if (email.contains('@')) {
            userName = email.split('@')[0].replaceAll('.', ' ');
            // Приводим к формату имени
            List<String> parts = userName.split(' ');
            for (int i = 0; i < parts.length; i++) {
              if (parts[i].isNotEmpty) {
                parts[i] = parts[i][0].toUpperCase() + (parts[i].length > 1 ? parts[i].substring(1) : '');
              }
            }
            userName = parts.join(' ');
          } else {
            userName = email;
          }
        }
        
        print('Найдено имя пользователя: $userName');
        
        // Обновляем кэш имен, чтобы использовать при следующем построении UI
        _userNameCache[userId] = userName;
        
        // Обновляем UI, чтобы сразу отобразить новое имя
        if (mounted) {
          setState(() {
            // Обновляем UI для отображения новых данных
          });
        }
      } else {
        print('Пользователь не найден в коллекции users');
      }
    } catch (e) {
      print('Ошибка при загрузке данных пользователя: $e');
    }
  }
  
  // Кэш имен пользователей для быстрого доступа
  final Map<String, String> _userNameCache = {};

  // Показывает диалог подтверждения удаления заказа
  void _showDeleteConfirmation(Map<String, dynamic> order) {
    final bool isAlreadyDeleted = order['isDeleted'] == true;
    final String orderIdShort = order['id'].substring(0, Math.min<int>(8, order['id'].length));
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isAlreadyDeleted ? 'Полностью удалить заказ?' : 'Удалить заказ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isAlreadyDeleted
                ? 'Заказ #$orderIdShort уже помечен как удаленный.'
                : 'Вы уверены, что хотите удалить заказ #$orderIdShort?'),
            const SizedBox(height: 8),
            Text(
              isAlreadyDeleted
                  ? 'Заказ будет перемещен в архив удаленных заказов и не будет отображаться в общем списке.'
                  : 'Заказ будет помечен как удаленный и останется в базе данных, но будет скрыт из активных заказов.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (isAlreadyDeleted) {
                _permanentlyDeleteOrder(order);
              } else {
                _deleteOrder(order['id']);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(isAlreadyDeleted ? 'Полностью удалить' : 'Удалить'),
          ),
        ],
      ),
    );
  }
  
  // Удаляет заказ (помечает как удаленный)
  Future<void> _deleteOrder(String orderId) async {
    if (!mounted) return;
    
    try {
      // Показываем индикатор загрузки
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Удаление заказа...'),
          duration: Duration(seconds: 1),
        ),
      );
      
      // Получаем данные заказа для получения userId
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) {
        throw Exception('Заказ не найден');
      }
      
      final orderData = orderDoc.data() as Map<String, dynamic>;
      final String userId = orderData['userId'] ?? '';
      
      // Обновляем заказ, устанавливая isDeleted = true
      await _firestore.collection('orders').doc(orderId).update({
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Синхронизируем удаление в коллекции пользователя, если известен userId
      if (userId.isNotEmpty) {
        try {
          final userOrderRef = _firestore.collection('users').doc(userId).collection('orders').doc(orderId);
          final userOrderDoc = await userOrderRef.get();
          
          if (userOrderDoc.exists) {
            // Копируем данные заказа в коллекцию истории заказов пользователя
            await _firestore
                .collection('users')
                .doc(userId)
                .collection('orderHistory')
                .doc(orderId)
                .set({
              'orderId': orderId,
              'originalData': userOrderDoc.data(),
              'deletedAt': FieldValue.serverTimestamp(),
              'restorable': true
            });
            
            // Удаляем заказ из активных заказов пользователя
            await userOrderRef.delete();
            print('Заказ успешно удален из коллекции пользователя и перемещен в историю');
          }
        } catch (e) {
          print('Ошибка при удалении заказа из коллекции пользователя: $e');
          // Продолжаем выполнение, даже если не удалось удалить в коллекции пользователя
        }
      }
      
      // Обновляем список заказов
      await _loadOrders();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Заказ успешно удален'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        print('Ошибка при удалении заказа: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при удалении заказа: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Добавить новый метод:
  
  // Полностью удаляет заказ (перемещает в коллекцию deleted_orders)
  Future<void> _permanentlyDeleteOrder(Map<String, dynamic> order) async {
    if (!mounted) return;
    
    try {
      // Показываем индикатор загрузки
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Архивирование заказа...'),
          duration: Duration(seconds: 1),
        ),
      );
      
      String orderId = order['id'];
      final String userId = order['userId'] ?? '';
      
      // 1. Копируем заказ в коллекцию deleted_orders
      await _firestore.collection('deleted_orders').doc(orderId).set({
        ...order,
        'permanentlyDeletedAt': FieldValue.serverTimestamp(),
      });
      
      // 2. Удаляем заказ из основной коллекции
      await _firestore.collection('orders').doc(orderId).delete();
      
      // 3. Если есть userId, удаляем заказ из истории заказов пользователя
      if (userId.isNotEmpty) {
        try {
          // Проверяем, есть ли заказ в истории
          final userHistoryRef = _firestore
              .collection('users')
              .doc(userId)
              .collection('orderHistory')
              .doc(orderId);
              
          final historyDoc = await userHistoryRef.get();
          
          if (historyDoc.exists) {
            // Удаляем из истории заказов пользователя
            await userHistoryRef.delete();
            print('Заказ успешно удален из истории заказов пользователя');
          }
          
          // На всякий случай проверяем, не остался ли заказ в активных заказах
          final userOrderRef = _firestore
              .collection('users')
              .doc(userId)
              .collection('orders')
              .doc(orderId);
              
          final orderDoc = await userOrderRef.get();
          
          if (orderDoc.exists) {
            await userOrderRef.delete();
            print('Заказ успешно удален из активных заказов пользователя');
          }
        } catch (e) {
          print('Ошибка при удалении заказа из коллекций пользователя: $e');
          // Продолжаем выполнение, даже если не удалось удалить заказ пользователя
        }
      }
      
      // 4. Обновляем список заказов
      await _loadOrders();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Заказ успешно архивирован'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        print('Ошибка при архивировании заказа: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при архивировании заказа: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 