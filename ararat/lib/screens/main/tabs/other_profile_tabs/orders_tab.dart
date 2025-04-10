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

    // Получение цвета статуса
    Color statusColor;
    switch (order.status.toLowerCase()) {
      case 'новый':
        statusColor = Colors.blue;
        break;
      case 'в обработке':
        statusColor = Colors.orange;
        break;
      case 'доставляется':
        statusColor = Colors.purple;
        break;
      case 'выполнен':
        statusColor = Colors.green;
        break;
      case 'отменен':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }
    
    // Перевод типа доставки
    String deliveryTypeText = 'Стандартная';
    switch (order.deliveryType.toLowerCase()) {
      case 'fast':
        deliveryTypeText = 'Срочная';
        break;
      case 'standard':
        deliveryTypeText = 'Стандартная';
        break;
      case 'scheduled':
        deliveryTypeText = 'По расписанию';
        break;
    }
    
    // Перевод способа оплаты
    String paymentMethodText = 'Наличными';
    if (order.paymentMethod.toLowerCase() == 'qr') {
      paymentMethodText = 'QR-код';
    }

    return GestureDetector(
      onLongPress: () => _showDeleteConfirmation(order.id),
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок заказа
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Заказ #${order.id.substring(0, 8)}',
                    style: const TextStyle(
                      color: Color(0xFF50321B),
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      order.status,
                      style: TextStyle(
                        color: statusColor,
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Дата заказа
              Text(
                'Дата: $formattedDate',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontFamily: 'Inter',
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              
              // Информация о доставке
              Row(
                children: [
                  Icon(
                    Icons.local_shipping_outlined, 
                    size: 14, 
                    color: Colors.grey[600]
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Доставка: $deliveryTypeText',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontFamily: 'Inter',
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              
              // Способ оплаты
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    order.paymentMethod.toLowerCase() == 'qr' 
                        ? Icons.qr_code 
                        : Icons.payments_outlined, 
                    size: 14, 
                    color: Colors.grey[600]
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Оплата: $paymentMethodText',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontFamily: 'Inter',
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              
              // Адрес доставки
              if (order.deliveryAddress['address'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined, 
                        size: 14, 
                        color: Colors.grey[600]
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Адрес: ${order.deliveryAddress['address']}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontFamily: 'Inter',
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 16),
              
              // Список товаров
              ...order.items.map((item) => _buildOrderItemRow(item)),
              
              const Divider(height: 24),
              
              // Итоговая информация
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Товары:',
                    style: TextStyle(
                      color: Color(0xFF50321B),
                      fontFamily: 'Inter',
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${order.subtotal.toStringAsFixed(0)} ₽',
                    style: const TextStyle(
                      color: Color(0xFF50321B),
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Доставка:',
                    style: TextStyle(
                      color: Color(0xFF50321B),
                      fontFamily: 'Inter',
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    order.deliveryCost > 0 ? '${order.deliveryCost.toStringAsFixed(0)} ₽' : 'Бесплатно',
                    style: TextStyle(
                      color: order.deliveryCost > 0 ? Color(0xFF50321B) : Colors.green,
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Итого:',
                    style: TextStyle(
                      color: Color(0xFF50321B),
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${order.total.toStringAsFixed(0)} ₽',
                    style: const TextStyle(
                      color: Color(0xFF50321B),
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Действия с заказом
              order.status.toLowerCase() == 'новый' || order.status.toLowerCase() == 'в обработке'
                  ? Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _cancelOrder(order.id),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.withOpacity(0.1),
                              foregroundColor: Colors.red,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Отменить заказ'),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderItemRow(OrderItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Миниатюра товара (если есть)
          item.imageUrl != null && item.imageUrl!.isNotEmpty
              ? Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    image: DecorationImage(
                      image: NetworkImage(item.imageUrl!),
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              : Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.grey[300],
                  ),
                  child: Icon(Icons.image_not_supported, size: 20, color: Colors.grey[500]),
                ),
          const SizedBox(width: 12),
          
          // Информация о товаре
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    color: Color(0xFF50321B),
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${item.price.toStringAsFixed(0)} ₽ × ${item.quantity} шт.',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontFamily: 'Inter',
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Итоговая стоимость позиции
          Text(
            '${(item.price * item.quantity).toStringAsFixed(0)} ₽',
            style: const TextStyle(
              color: Color(0xFF50321B),
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelOrder(String orderId) async {
    // Создаем ключ, чтобы иметь возможность закрыть диалог независимо от контекста
    final GlobalKey<State> _dialogKey = GlobalKey<State>();
    
    // Переменная для отслеживания, был ли закрыт диалог
    bool isDialogClosed = false;
    
    // Функция для безопасного закрытия диалога
    void closeDialog() {
      if (!isDialogClosed && _dialogKey.currentContext != null) {
        isDialogClosed = true;
        Navigator.of(_dialogKey.currentContext!, rootNavigator: true).pop();
      }
    }
    
    // Проверяем, активен ли виджет
    if (!mounted) return;
    
    // Показываем диалог подтверждения
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Отменить заказ?'),
        content: const Text('Вы уверены, что хотите отменить этот заказ?'),
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
                builder: (BuildContext loadingContext) {
                  return Dialog(
                    key: _dialogKey,
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
                  );
                },
              );
              
              try {
                // Отменяем заказ
                await _orderService.cancelOrder(orderId);
                
                // Безопасно закрываем диалог загрузки
                closeDialog();
                
                // Проверяем, активен ли виджет перед обновлением UI
                if (mounted) {
                  setState(() {
                    for (int i = 0; i < _orders.length; i++) {
                      if (_orders[i].id == orderId) {
                        // Обновляем статус заказа локально
                        Order updatedOrder = Order(
                          id: _orders[i].id,
                          userId: _orders[i].userId,
                          items: _orders[i].items,
                          subtotal: _orders[i].subtotal,
                          deliveryCost: _orders[i].deliveryCost,
                          total: _orders[i].total,
                          paymentMethod: _orders[i].paymentMethod,
                          deliveryType: _orders[i].deliveryType,
                          status: 'отменен',
                          deliveryAddress: _orders[i].deliveryAddress,
                          phoneNumber: _orders[i].phoneNumber,
                          comment: _orders[i].comment,
                          leaveAtDoor: _orders[i].leaveAtDoor,
                          createdAt: _orders[i].createdAt,
                        );
                        _orders[i] = updatedOrder;
                        break;
                      }
                    }
                  });
                  
                  // Показываем уведомление об успешной отмене
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Заказ успешно отменен'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  
                  // Обновляем список заказов
                  Future.delayed(const Duration(seconds: 1), () {
                    if (mounted) {
                      _loadOrders();
                    }
                  });
                }
              } catch (e) {
                // Безопасно закрываем диалог загрузки в случае ошибки
                closeDialog();
                
                // Показываем уведомление об ошибке, если виджет все еще активен
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Ошибка при отмене заказа: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Отменить заказ'),
          ),
        ],
      ),
    );
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
} 