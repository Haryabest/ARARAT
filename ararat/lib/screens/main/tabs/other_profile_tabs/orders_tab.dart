import 'package:flutter/material.dart';
import 'package:ararat/services/order_service.dart';
import 'package:intl/intl.dart';
import 'package:ararat/widgets/checkout_form.dart';

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
    // Форматирование даты
    final DateFormat dateFormat = DateFormat('dd.MM.yyyy в HH:mm');
    final String formattedDate = dateFormat.format(order.createdAt);
    
    // Проверяем способ оплаты
    final bool isQrPayment = order.paymentMethod.toLowerCase() == 'qr' || 
                            order.paymentMethod.toLowerCase() == 'qr-код';
    final bool isCashOnDelivery = order.paymentMethod.toLowerCase() == 'cash' || 
                                 order.paymentMethod.toLowerCase() == 'при получении';
    
    // Проверяем, можно ли отменить заказ (только для новых или в обработке)
    final bool canCancel = order.status.toLowerCase() == 'новый' || 
                         order.status.toLowerCase() == 'в обработке';
    
    // Формирование полного адреса
    String fullAddress = '';
    if (order.deliveryAddress.isNotEmpty) {
      if (order.deliveryAddress['address'] != null) {
        fullAddress += order.deliveryAddress['address'];
      }
      
      // Добавление квартиры
      if (order.deliveryAddress['apartment'] != null && order.deliveryAddress['apartment'].toString().isNotEmpty) {
        fullAddress += ', кв. ${order.deliveryAddress['apartment']}';
      }
      
      // Добавление подъезда
      if (order.deliveryAddress['entrance'] != null && order.deliveryAddress['entrance'].toString().isNotEmpty) {
        fullAddress += ', подъезд ${order.deliveryAddress['entrance']}';
      }
      
      // Добавление этажа
      if (order.deliveryAddress['floor'] != null && order.deliveryAddress['floor'].toString().isNotEmpty) {
        fullAddress += ', этаж ${order.deliveryAddress['floor']}';
      }
      
      // Добавление домофона
      if (order.deliveryAddress['intercom'] != null && order.deliveryAddress['intercom'].toString().isNotEmpty) {
        fullAddress += ', домофон ${order.deliveryAddress['intercom']}';
      }
      
      // Добавление полного адреса, если он есть
      if (order.deliveryAddress['fullAddress'] != null && order.deliveryAddress['fullAddress'].toString().isNotEmpty) {
        // Если fullAddress содержит более детальную информацию, используем его вместо составного адреса
        fullAddress = order.deliveryAddress['fullAddress'];
      }
    }
    
    // Русификация способа оплаты
    String paymentMethodRu = _getPaymentMethodInRussian(order.paymentMethod);
    
    // Русификация способа доставки
    String deliveryTypeRu = _getDeliveryTypeInRussian(order.deliveryType);

    return GestureDetector(
      onLongPress: () => _showDeleteConfirmation(order.id),
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
                        'Заказ №${order.id.substring(0, 8)}',
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
                      order.status,
                      style: TextStyle(
                        color: _getStatusColor(order.status.toLowerCase()),
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
                    children: [
                      const Icon(
                        Icons.shopping_bag,
                        size: 14,
                        color: Color(0xFF6C4425),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Товары (${order.items.length})',
                        style: const TextStyle(
                          color: Color(0xFF50321B),
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  
                  // Отображаем первый товар из списка
                  if (order.items.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      child: _buildProductItem(order.items.first),
                    ),
                  
                  // Сумма заказа (выделенная) - ПЕРЕМЕЩЕНА ПОД ТОВАРЫ
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 10),
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2ECE4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF6C4425).withOpacity(0.15),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.monetization_on,
                              size: 14,
                              color: Color(0xFF6C4425),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Сумма заказа:',
                              style: TextStyle(
                                color: Color(0xFF50321B),
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${order.total.toStringAsFixed(0)} ₽',
                          style: const TextStyle(
                            color: Color(0xFF6C4425),
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Кнопки действий
                  if (isQrPayment)
                    _buildActionButton(
                      icon: Icons.qr_code_scanner,
                      label: 'Оплатить QR-кодом',
                      onPressed: () => _showQrPaymentDialog(context, order),
                      isPrimary: true,
                    )
                  else if (isCashOnDelivery)
                    _buildCashPaymentInfo(),
                  
                  // Кнопка отмены заказа
                  if (canCancel)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          onPressed: () => _showCancelConfirmation(order.id),
                          child: const Text(
                            'Отменить заказ',
                            style: TextStyle(
                              color: Color(0xFF9E9E9E),
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            minimumSize: Size.zero,
                          ),
                        ),
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
  
  // Метод для получения русского названия способа оплаты
  String _getPaymentMethodInRussian(String paymentMethod) {
    switch (paymentMethod.toLowerCase()) {
      case 'cash':
        return 'Наличными';
      case 'qr':
      case 'qr-код':
        return 'QR-код';
      default:
        return paymentMethod; // Возвращаем оригинальное значение если неизвестный метод
    }
  }
  
  // Метод для получения русского названия способа доставки
  String _getDeliveryTypeInRussian(String deliveryType) {
    switch (deliveryType.toLowerCase()) {
      case 'slow':
        return 'Обычная';
      case 'fast':
        return 'Срочная';
      case 'pickup':
        return 'Самовывоз';
      case 'standard':
        return 'Стандартная';
      default:
        return deliveryType; // Возвращаем оригинальное значение если неизвестный метод
    }
  }
  
  // Метод для получения цвета статуса заказа
  Color _getStatusColor(String status) {
    switch (status) {
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
  
  // Метод для создания компактной строки информации
  Widget _buildCompactInfoRow(IconData icon, String title, String value, {Color? valueColor}) {
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
                color: Color(0xFF50321B),
                fontFamily: 'Inter',
                fontSize: 13,
              ),
              children: [
                TextSpan(
                  text: '$title ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: valueColor,
                    fontWeight: valueColor != null ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  // Метод для создания элемента товара
  Widget _buildProductItem(OrderItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Изображение товара
          if (item.imageUrl != null)
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: Colors.grey[200],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                item.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (ctx, obj, trace) => const Center(
                  child: Icon(Icons.image_not_supported, size: 14, color: Colors.grey),
                ),
              ),
            )
          else
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: Colors.grey[200],
              ),
              child: const Center(
                child: Icon(Icons.image_not_supported, size: 14, color: Colors.grey),
              ),
            ),
          const SizedBox(width: 8),
          
          // Название и цена товара
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    color: Color(0xFF50321B),
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${item.quantity} × ${item.price.toStringAsFixed(0)} ₽',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontFamily: 'Inter',
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          
          // Стоимость товара
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF6C4425).withOpacity(0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${(item.price * item.quantity).toStringAsFixed(0)} ₽',
              style: const TextStyle(
                color: Color(0xFF6C4425),
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Метод для создания кнопки действия
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isPrimary,
    bool isCancel = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 36,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary 
              ? const Color(0xFF6C4425) 
              : isCancel
                  ? Colors.white
                  : const Color(0xFFF2ECE4),
          foregroundColor: isPrimary 
              ? Colors.white 
              : isCancel
                  ? Colors.red
                  : const Color(0xFF6C4425),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isCancel 
                  ? Colors.red.withOpacity(0.3) 
                  : isPrimary
                      ? Colors.transparent
                      : const Color(0xFF6C4425).withOpacity(0.15),
            ),
          ),
          elevation: 0,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
  
  // Метод для создания информации о наличной оплате
  Widget _buildCashPaymentInfo() {
    return Container(
      width: double.infinity,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF2ECE4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF6C4425).withOpacity(0.15),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.payments,
            size: 16,
            color: Color(0xFF6C4425),
          ),
          const SizedBox(width: 6),
          const Text(
            'Оплата при получении',
            style: TextStyle(
              color: Color(0xFF6C4425),
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Метод для отображения QR-кода оплаты
  void _showQrPaymentDialog(BuildContext context, Order order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Оплата QR-кодом',
          style: TextStyle(
            color: Color(0xFF50321B),
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Отсканируйте QR-код для оплаты заказа',
              style: TextStyle(
                color: Color(0xFF50321B),
                fontFamily: 'Inter',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(
                  Icons.qr_code_2,
                  size: 150,
                  color: Color(0xFF6C4425),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Сумма к оплате: ${order.total.toStringAsFixed(0)} ₽',
              style: const TextStyle(
                color: Color(0xFF50321B),
                fontFamily: 'Inter',
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Закрыть',
              style: TextStyle(
                color: Color(0xFF6C4425),
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Метод для отмены заказа
  Future<void> _cancelOrder(String orderId) async {
    // Создаем ключ для диалога загрузки
    final GlobalKey<State> _loadingDialogKey = GlobalKey<State>();
    
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
              Text('Отмена заказа...'),
            ],
          ),
        ),
      ),
    );
    
    try {
      // Отменяем заказ
      await _orderService.cancelOrder(orderId);
      
      // Безопасно закрываем индикатор загрузки
      closeLoadingDialog();
      
      // Обновляем список заказов, если виджет всё ещё активен
      if (mounted) {
        setState(() {
          final orderIndex = _orders.indexWhere((order) => order.id == orderId);
          if (orderIndex != -1) {
            // Обновляем статус заказа локально без перезагрузки с сервера
            final updatedOrder = Order(
              id: _orders[orderIndex].id,
              userId: _orders[orderIndex].userId,
              items: _orders[orderIndex].items,
              subtotal: _orders[orderIndex].subtotal,
              deliveryCost: _orders[orderIndex].deliveryCost,
              total: _orders[orderIndex].total,
              paymentMethod: _orders[orderIndex].paymentMethod,
              deliveryType: _orders[orderIndex].deliveryType,
              status: 'отменен', // Обновляем статус
              deliveryAddress: _orders[orderIndex].deliveryAddress,
              phoneNumber: _orders[orderIndex].phoneNumber,
              comment: _orders[orderIndex].comment,
              leaveAtDoor: _orders[orderIndex].leaveAtDoor,
              createdAt: _orders[orderIndex].createdAt,
            );
            
            // Заменяем старый заказ обновленным
            _orders[orderIndex] = updatedOrder;
          }
        });
        
        // Показываем уведомление
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Заказ успешно отменен'),
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
            content: Text('Ошибка при отмене заказа: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Метод для показа диалога подтверждения удаления заказа
  Future<void> _showDeleteConfirmation(String orderId) async {
    // Создаем ключ для диалога загрузки
    final GlobalKey<State> _loadingDialogKey = GlobalKey<State>();
    
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

  // Метод для удаления заказа
  Future<void> _deleteOrder(String orderId) async {
    // Создаем ключ для диалога загрузки
    final GlobalKey<State> _loadingDialogKey = GlobalKey<State>();
    
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
  }

  // Метод для показа диалога подтверждения отмены заказа
  Future<void> _showCancelConfirmation(String orderId) async {
    if (!mounted) return;
    
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Отменить заказ?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF50321B),
          ),
        ),
        content: const Text(
          'Вы уверены, что хотите отменить заказ? Эту операцию нельзя будет отменить.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF50321B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Нет',
              style: TextStyle(
                color: Color(0xFF6C4425),
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _cancelOrder(orderId);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red[400],
            ),
            child: const Text(
              'Да, отменить',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
} 