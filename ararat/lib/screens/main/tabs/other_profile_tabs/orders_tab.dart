import 'package:flutter/material.dart';
import 'package:ararat/services/order_service.dart';
import 'package:intl/intl.dart';
import 'package:ararat/widgets/checkout_form.dart';

// Вынесли классы OrderCard и _OrderCardState на верхний уровень файла
class OrderCard extends StatefulWidget {
  final Order order;
  final VoidCallback onLongPress;
  
  const OrderCard({
    Key? key,
    required this.order,
    required this.onLongPress,
  }) : super(key: key);
  
  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  bool isExpanded = false;
  
  @override
  Widget build(BuildContext context) {
    // Форматирование даты
    final DateFormat dateFormat = DateFormat('dd.MM.yyyy в HH:mm');
    final String formattedDate = dateFormat.format(widget.order.createdAt);
    
    // Проверяем способ оплаты
    final bool isQrPayment = widget.order.paymentMethod.toLowerCase() == 'qr' || 
                           widget.order.paymentMethod.toLowerCase() == 'qr-код';
    final bool isCashOnDelivery = widget.order.paymentMethod.toLowerCase() == 'cash' || 
                               widget.order.paymentMethod.toLowerCase() == 'при получении';
    
    // Проверяем, можно ли отменить заказ (только для новых или в обработке)
    final bool canCancel = widget.order.status.toLowerCase() == 'новый' || 
                       widget.order.status.toLowerCase() == 'в обработке';
    
    // Формирование полного адреса
    String fullAddress = '';
    if (widget.order.deliveryAddress.isNotEmpty) {
      if (widget.order.deliveryAddress['address'] != null) {
        fullAddress += widget.order.deliveryAddress['address'];
      }
      
      // Добавление квартиры
      if (widget.order.deliveryAddress['apartment'] != null && widget.order.deliveryAddress['apartment'].toString().isNotEmpty) {
        fullAddress += ', кв. ${widget.order.deliveryAddress['apartment']}';
      }
      
      // Добавление подъезда
      if (widget.order.deliveryAddress['entrance'] != null && widget.order.deliveryAddress['entrance'].toString().isNotEmpty) {
        fullAddress += ', подъезд ${widget.order.deliveryAddress['entrance']}';
      }
      
      // Добавление этажа
      if (widget.order.deliveryAddress['floor'] != null && widget.order.deliveryAddress['floor'].toString().isNotEmpty) {
        fullAddress += ', этаж ${widget.order.deliveryAddress['floor']}';
      }
      
      // Добавление домофона
      if (widget.order.deliveryAddress['intercom'] != null && widget.order.deliveryAddress['intercom'].toString().isNotEmpty) {
        fullAddress += ', домофон ${widget.order.deliveryAddress['intercom']}';
      }
      
      // Добавление полного адреса, если он есть
      if (widget.order.deliveryAddress['fullAddress'] != null && widget.order.deliveryAddress['fullAddress'].toString().isNotEmpty) {
        // Если fullAddress содержит более детальную информацию, используем его вместо составного адреса
        fullAddress = widget.order.deliveryAddress['fullAddress'];
      }
    }
    
    // Русификация способа оплаты
    String paymentMethodRu = _getPaymentMethodInRussian(widget.order.paymentMethod);
    
    // Русификация способа доставки
    String deliveryTypeRu = _getDeliveryTypeInRussian(widget.order.deliveryType);

    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBF6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Верхняя часть с номером и статусом
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF6C4425),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.receipt_long,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Заказ №${widget.order.id.substring(0, 8)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      widget.order.status,
                      style: TextStyle(
                        color: _getStatusColor(widget.order.status.toLowerCase()),
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Информация о заказе
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Компактные строки информации
                  _buildCompactInfoRow(Icons.calendar_today, 'Дата заказа:', formattedDate),
                  const SizedBox(height: 4),
                  _buildCompactInfoRow(
                    isQrPayment ? Icons.qr_code : Icons.payments, 
                    'Способ оплаты:', 
                    paymentMethodRu
                  ),
                  const SizedBox(height: 4),
                  _buildCompactInfoRow(Icons.local_shipping, 'Способ доставки:', deliveryTypeRu),
                  const SizedBox(height: 4),
                  
                  // Адрес доставки (если есть)
                  if (fullAddress.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _buildCompactInfoRow(
                        Icons.location_on, 
                        'Адрес:', 
                        fullAddress,
                      ),
                    ),
                  
                  // Секция товаров
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Заголовок товаров
                      Row(
                        children: [
                          const Icon(
                            Icons.shopping_bag,
                            size: 14,
                            color: Color(0xFF6C4425),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Товары (${widget.order.items.length})',
                            style: const TextStyle(
                              color: Color(0xFF50321B),
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      
                      // Кнопка "Подробнее"
                      TextButton(
                        onPressed: () {
                          setState(() {
                            isExpanded = !isExpanded;
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Row(
                          children: [
                            Text(
                              isExpanded ? 'Свернуть' : 'Подробнее',
                              style: const TextStyle(
                                color: Color(0xFF6C4425),
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Icon(
                              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              size: 14,
                              color: const Color(0xFF6C4425),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  // Горизонтальный список превью товаров, видимый всегда
                  SizedBox(
                    height: 70,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.order.items.length > 4 ? 4 : widget.order.items.length,
                      itemBuilder: (context, index) {
                        final dynamic item = widget.order.items[index];
                        String? imageUrl;
                        
                        // Если это Map (из Firebase), извлекаем данные
                        if (item is Map<String, dynamic>) {
                          imageUrl = item['imageUrl'] as String?;
                          
                          if (imageUrl == null && item['product'] is Map && (item['product'] as Map)['imageUrls'] is List) {
                            final imageUrls = List<String>.from((item['product'] as Map)['imageUrls'] as List);
                            if (imageUrls.isNotEmpty) {
                              imageUrl = imageUrls.first;
                            }
                          }
                        } 
                        // Если это OrderItem
                        else if (item is OrderItem) {
                          imageUrl = item.imageUrl;
                        }
                        
                        // Если это последний элемент и есть еще товары, показываем "+N"
                        if (index == 3 && widget.order.items.length > 4) {
                          return Stack(
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  image: imageUrl != null
                                      ? DecorationImage(
                                          image: NetworkImage(imageUrl.startsWith('http')
                                              ? imageUrl
                                              : 'https://storage.googleapis.com/ararat-80efa.appspot.com/$imageUrl'),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                  color: Colors.grey.shade200,
                                ),
                              ),
                              Container(
                                width: 70,
                                height: 70,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.black.withOpacity(0.5),
                                ),
                                child: Center(
                                  child: Text(
                                    '+${widget.order.items.length - 3}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Inter',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                        
                        return Container(
                          width: 70,
                          height: 70,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: imageUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(imageUrl.startsWith('http')
                                        ? imageUrl
                                        : 'https://storage.googleapis.com/ararat-80efa.appspot.com/$imageUrl'),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            color: Colors.grey.shade200,
                          ),
                          child: imageUrl == null
                              ? const Center(
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey,
                                    size: 24,
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
                  ),
                  
                  // Развернутый список товаров
                  if (isExpanded)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(),
                          ...widget.order.items.map((dynamic item) {
                            String name = 'Неизвестный товар';
                            double price = 0;
                            int quantity = 1;
                            
                            // Если это Map (из Firebase), извлекаем данные
                            if (item is Map<String, dynamic>) {
                              name = item['name'] as String? ?? 
                                    (item['product'] is Map ? (item['product'] as Map)['name'] as String? ?? 'Неизвестный товар' : 'Неизвестный товар');
                              
                              price = (item['price'] != null) ? (item['price'] as num).toDouble() : 0;
                              quantity = (item['quantity'] != null) ? (item['quantity'] as num).toInt() : 1;
                            } 
                            // Если это OrderItem
                            else if (item is OrderItem) {
                              name = item.name;
                              price = item.price;
                              quantity = item.quantity;
                            }
                            
                            final totalPrice = (price * quantity).toStringAsFixed(0);
                            
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF50321B),
                                        fontFamily: 'Inter',
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Row(
                                    children: [
                                      Text(
                                        '$quantity шт.',
                                        style: const TextStyle(
                                          color: Color(0xFF6C4425),
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '$totalPrice ₽',
                                        style: const TextStyle(
                                          color: Color(0xFF6C4425),
                                          fontFamily: 'Inter',
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          const Divider(),
                          
                          // Сумма заказа
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Итого:',
                                  style: TextStyle(
                                    color: Color(0xFF50321B),
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${widget.order.total.toStringAsFixed(0)} ₽',
                                  style: const TextStyle(
                                    color: Color(0xFF6C4425),
                                    fontFamily: 'Inter',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Кнопки действий
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Кнопка оплаты для QR-кода
                        if (isQrPayment && (widget.order.status.toLowerCase() == 'новый' || widget.order.status.toLowerCase() == 'в обработке'))
                          ElevatedButton.icon(
                            onPressed: () {
                              // Действие для оплаты
                            },
                            icon: const Icon(Icons.qr_code, size: 16),
                            label: const Text('Оплатить'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6C4425),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              textStyle: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              minimumSize: const Size(100, 32),
                            ),
                          ),
                        
                        // Кнопка отмены заказа
                        if (canCancel)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: OutlinedButton(
                              onPressed: () {
                                // Действие для отмены заказа
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                textStyle: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                minimumSize: const Size(100, 32),
                              ),
                              child: const Text('Отменить'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Вспомогательный метод для строки информации
  Widget _buildCompactInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 14,
          color: const Color(0xFF6C4425),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: Color(0xFF50321B),
              ),
              children: [
                TextSpan(
                  text: label + ' ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextSpan(
                  text: value,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Вспомогательные методы для перевода статусов
Color _getStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'новый':
      return Colors.blue;
    case 'в обработке':
      return Colors.orange;
    case 'доставляется':
      return Colors.purple;
    case 'выполнен':
      return Colors.green;
    case 'отменен':
      return Colors.red;
    default:
      return Colors.grey;
  }
}

String _getPaymentMethodInRussian(String method) {
  switch (method.toLowerCase()) {
    case 'qr':
    case 'qr-код':
      return 'QR-код';
    case 'cash':
    case 'при получении':
      return 'При получении';
    case 'card':
    case 'карта':
      return 'Картой';
    default:
      return method;
  }
}

String _getDeliveryTypeInRussian(String type) {
  switch (type.toLowerCase()) {
    case 'pickup':
    case 'самовывоз':
      return 'Самовывоз';
    case 'delivery':
    case 'доставка':
      return 'Доставка';
    default:
      return type;
  }
}

class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  final OrderService _orderService = OrderService();
  bool _isLoading = true;
  List<Order> _orders = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('Начинаем загрузку заказов для экрана OrdersTab');
      
      // Проверка соединения с Firebase
      final isConnected = await _orderService.checkFirebaseConnection();
      if (!isConnected) {
        throw Exception('Не удалось установить соединение с Firebase');
      }
      
      final orders = await _orderService.getUserOrders();
      
      if (!mounted) return;
      
      print('Загружено заказов: ${orders.length}');
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    } catch (e) {
      print('Ошибка загрузки заказов на экран OrdersTab: $e');
      
      if (!mounted) return;
      
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF50321B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Мои заказы',
          style: TextStyle(
            color: Color(0xFF50321B),
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF50321B)),
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Color(0xFF50321B),
            ),
            SizedBox(height: 16),
            Text(
              'Загрузка заказов...',
              style: TextStyle(
                color: Color(0xFF50321B),
                fontFamily: 'Inter',
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Ошибка загрузки заказов',
              style: TextStyle(
                color: Color(0xFF50321B),
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: Colors.red,
                  fontFamily: 'Inter',
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Возможно, проблема с подключением к серверу или с настройками Firebase.',
                style: TextStyle(
                  color: Color(0xFF50321B),
                  fontFamily: 'Inter',
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadOrders,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF50321B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Повторить',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag,
              size: 60,
              color: Color(0xFF50321B).withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'У вас пока нет заказов',
              style: TextStyle(
                color: Color(0xFF50321B),
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ваши заказы будут отображаться здесь',
              style: TextStyle(
                color: Color(0xFF50321B),
                fontFamily: 'Inter',
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: const Color(0xFF50321B),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          return _buildOrderCard(_orders[index]);
        },
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    return OrderCard(
      order: order, 
      onLongPress: () => _showDeleteConfirmation(order.id)
    );
  }

  // Метод для показа диалога подтверждения удаления заказа
  Future<void> _showDeleteConfirmation(String orderId) async {
    // Создаем ключ для диалога загрузки
    final GlobalKey<NavigatorState> _loadingDialogKey = GlobalKey<NavigatorState>();
    
    // Переменная для отслеживания состояния диалога загрузки
    bool isLoadingDialogClosed = false;
    
    // Функция для безопасного закрытия диалога загрузки
    void closeLoadingDialog() {
      if (!isLoadingDialogClosed && _loadingDialogKey.currentContext != null) {
        isLoadingDialogClosed = true;
        Navigator.of(_loadingDialogKey.currentContext!, rootNavigator: true).pop();
      }
    }
    
    // Проверяем, активен ли виджет
    if (!mounted) return;
    
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить заказ?'),
        content: const Text(
          'Заказ будет перемещен в историю. Вы сможете просмотреть его позже во вкладке "История".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              // Закрываем диалог подтверждения
              Navigator.pop(dialogContext);
              
              // Проверяем, активен ли виджет после закрытия диалога
              if (!mounted) return;
              
              // Показываем индикатор загрузки
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (loadingContext) => Dialog(
                  key: _loadingDialogKey,
                  child: const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF50321B)),
                        SizedBox(width: 20),
                        Text('Удаление заказа...'),
                      ],
                    ),
                  ),
                ),
              );
              
              try {
                // Удаляем заказ
                await _orderService.deleteOrder(orderId);
                
                // Безопасно закрываем индикатор загрузки
                closeLoadingDialog();
                
                // Обновляем список заказов, если виджет всё ещё активен
                if (mounted) {
                  setState(() {
                    _orders.removeWhere((order) => order.id == orderId);
                  });
                  
                  // Показываем уведомление
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Заказ перемещен в историю'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                // Безопасно закрываем индикатор загрузки в случае ошибки
                closeLoadingDialog();
                
                // Показываем уведомление об ошибке, если виджет всё ещё активен
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Ошибка при удалении заказа: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
} 