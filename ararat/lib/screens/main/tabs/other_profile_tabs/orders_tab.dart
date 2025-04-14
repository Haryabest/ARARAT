import 'package:flutter/material.dart';
import 'package:ararat/services/order_service.dart';
import 'package:ararat/services/payment_service.dart';
import 'package:intl/intl.dart';
import 'package:ararat/widgets/checkout_form.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  final PaymentService _paymentService = PaymentService();
  bool _isProcessingPayment = false;
  Timer? _paymentCheckTimer;
  String? _currentPaymentId;

  @override
  void dispose() {
    _paymentCheckTimer?.cancel();
    super.dispose();
  }
  
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
                  
                  // Горизонтальный список изображений товаров (когда свернуто)
                  Container(
                    margin: const EdgeInsets.only(top: 6, bottom: 2),
                    height: 46,
      child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.order.items.length > 4 ? 5 : widget.order.items.length,
        itemBuilder: (context, index) {
                        // Показываем индикатор "+еще X" если товаров больше 4
                        if (widget.order.items.length > 4 && index == 4) {
                          return Container(
                            width: 46,
                            height: 46,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C4425).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '+${widget.order.items.length - 4}',
                                style: const TextStyle(
                                  color: Color(0xFF6C4425),
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
      ),
    );
  }

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
                        
                        return Container(
                          width: 46,
                          height: 46,
                          margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey[200],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: imageUrl != null && imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl.startsWith('http')
                                    ? imageUrl
                                    : 'https://storage.googleapis.com/ararat-80efa.appspot.com/$imageUrl',
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, obj, trace) => const Center(
                                  child: Icon(Icons.image_not_supported, size: 14, color: Colors.grey),
                                ),
                              )
                            : const Center(
                                child: Icon(Icons.image_not_supported, size: 14, color: Colors.grey),
                              ),
                        );
                      },
                    ),
                  ),
                  
                  // Вертикальный список товаров с ценами и названиями (когда развернуто)
                  if (isExpanded)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(top: 8),
                      child: Column(
                        children: widget.order.items.map((dynamic item) => _buildProductItem(item)).toList(),
                      ),
                    ),
                  
                  // Сумма заказа (выделенная) - ПОД ТОВАРАМИ
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
                          '${widget.order.total.toStringAsFixed(0)} ₽',
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
                  if (isQrPayment && (widget.order.status.toLowerCase() == 'новый' || widget.order.status.toLowerCase() == 'в обработке'))
                    _buildActionButton(
                      icon: Icons.qr_code_scanner,
                      label: 'Оплатить QR-кодом',
                      onPressed: _isProcessingPayment 
                          ? null 
                          : () => _showQrPaymentDialog(context, widget.order),
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
                          onPressed: () {
                            // Действие для отмены заказа
                          },
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
  
  // Метод для показа диалога QR-кода оплаты
  Future<void> _showQrPaymentDialog(BuildContext context, Order order) async {
    setState(() => _isProcessingPayment = true);
    
    try {
      // Получаем текущего пользователя из Firebase Auth
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Пользователь не авторизован');
      }
      
      // Создаем запись о платеже в Firestore
      final paymentResult = await _paymentService.createPayment(
        order.id,
        order.total,
        user.uid, // Используем ID текущего пользователя
      );
      
      final String paymentId = paymentResult['paymentId'];
      final String qrData = paymentResult['qrData'];
      _currentPaymentId = paymentId;
      
      if (mounted) {
        bool isScanned = false;
        bool isPaymentConfirmed = false;
        
        // Сохраняем состояние таймера для автоматической проверки
        _startPaymentStatusChecking(paymentId);
        
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return StatefulBuilder(
              builder: (context, setDialogState) {
                // Обновление статуса сканирования и подтверждения
                void updatePaymentStatus() async {
                  try {
                    final status = await _paymentService.checkPaymentStatus(paymentId);
                    if (status == 'processing' && !isScanned) {
                      setDialogState(() {
                        isScanned = true;
                      });
                    } else if (status == 'completed' && !isPaymentConfirmed) {
                      setDialogState(() {
                        isScanned = true;
                        isPaymentConfirmed = true;
                      });
                      
                      // Показываем сообщение об успешной оплате
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Платеж успешно обработан! Потяните вниз для обновления списка заказов.'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 5),
                        ),
                      );
                    }
                  } catch (e) {
                    print('Ошибка при обновлении статуса оплаты: $e');
                  }
                }
                
                return AlertDialog(
                  title: Column(
                children: [
                      Text(
                        'Оплата заказа',
                    style: TextStyle(
                      color: Color(0xFF50321B),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                    ),
                        textAlign: TextAlign.center,
                  ),
                      SizedBox(height: 4),
                  Text(
                        'Сумма: ${order.total.toStringAsFixed(2)} ₽',
                        style: TextStyle(
                      color: Color(0xFF50321B),
                          fontSize: 16,
                    ),
                        textAlign: TextAlign.center,
                  ),
                ],
              ),
                  content: Container(
                    width: 280,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                children: [
                        // QR-код для оплаты
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // QR-код
                            Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              padding: EdgeInsets.all(10),
                              child: isPaymentConfirmed
                                  ? Center(
                                      child: Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 100,
                                      ),
                                    )
                                  : QrImageView(
                                      data: qrData,
                                      version: QrVersions.auto,
                                      size: 180,
                                      padding: EdgeInsets.zero,
                                      backgroundColor: Colors.white,
                                    ),
                            ),
                            
                            // Анимация сканирования
                            if (isScanned && !isPaymentConfirmed)
                              Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Stack(
                                  children: [
                                    // Анимированное перемещение полосы сканирования
                                    AnimatedPositioned(
                                      duration: Duration(seconds: 2),
                                      curve: Curves.easeInOut,
                                      top: 0,
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        height: 2,
                                        color: Colors.green.withOpacity(0.7),
                                      ),
                                    ),
                                    Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        
                        SizedBox(height: 16),
                        
                        // Объяснение работы QR-кода
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Color(0xFFF2ECE4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Color(0xFF6C4425).withOpacity(0.15),
                            ),
                          ),
                          child: Text(
                            'QR-код содержит ссылку. При сканировании и переходе по ссылке оплата будет подтверждена автоматически.',
                    style: TextStyle(
                      color: Color(0xFF50321B),
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                    ),
                            textAlign: TextAlign.center,
                  ),
                        ),
                        
                        SizedBox(height: 16),
                        
                        // Статус оплаты
                  Text(
                          isPaymentConfirmed
                              ? 'Оплата подтверждена!'
                              : isScanned
                                  ? 'QR-код отсканирован, ожидаем подтверждение оплаты...'
                                  : 'Отсканируйте QR-код в приложении банка для оплаты',
                    style: TextStyle(
                            color: isPaymentConfirmed ? Colors.green : Color(0xFF50321B),
                      fontSize: 14,
                            fontWeight: isPaymentConfirmed ? FontWeight.bold : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        SizedBox(height: 16),
                        
                        // Для тестирования: кнопка симуляции сканирования и кнопка открытия ссылки
                        if (!isScanned && !isPaymentConfirmed)
                          Column(
                            children: [
                              ElevatedButton.icon(
                                onPressed: () async {
                                  setDialogState(() {
                                    isScanned = true;
                                  });
                                  
                                  // Через 3 секунды переводим платеж в статус в обработке
                                  await Future.delayed(Duration(seconds: 3));
                                  await _paymentService.updatePaymentStatus(paymentId, 'processing');
                                },
                                icon: Icon(Icons.qr_code_scanner),
                                label: Text('Симулировать сканирование'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF50321B),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  // Открываем ссылку из QR-кода для тестирования
                                  final Uri url = Uri.parse(qrData);
                                  
                                  if (await canLaunchUrl(url)) {
                                    setDialogState(() {
                                      isScanned = true;
                                    });
                                    
                                    await launchUrl(url);
                                    
                                    // Симулируем процесс оплаты для тестирования
                                    try {
                                      // Подтверждаем платеж сразу после открытия ссылки
                                      await _paymentService.updatePaymentStatus(paymentId, 'processing');
                                      
                                      // Через 2 секунды завершаем платеж
                                      await Future.delayed(Duration(seconds: 2));
                                      await _paymentService.updatePaymentStatus(paymentId, 'completed');
                                      
                                      // Обновляем статус в диалоге
                                      setDialogState(() {
                                        isPaymentConfirmed = true;
                                      });
                                    } catch (e) {
                                      print('Ошибка при симуляции оплаты: $e');
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Ошибка при обработке платежа: ${e.toString()}'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Невозможно открыть ссылку: $qrData'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                icon: Icon(Icons.open_in_browser),
                                label: Text('Открыть ссылку для оплаты'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
                      ],
                    ),
                  ),
                  actions: [
                    // Кнопка закрытия, доступна только если платеж подтвержден или отменен
                    TextButton(
                      onPressed: isPaymentConfirmed 
                        ? () {
                            Navigator.of(dialogContext).pop();
                          }
                        : null,
                      child: Text(
                        isPaymentConfirmed ? 'Готово' : 'Подождите...',
                    style: TextStyle(
                          color: isPaymentConfirmed ? Color(0xFF50321B) : Colors.grey,
                        ),
                      ),
                    ),
                    // Кнопка отмены, доступна только если платеж не подтвержден
                    if (!isPaymentConfirmed)
                      TextButton(
                        onPressed: () {
                          _paymentCheckTimer?.cancel();
                          Navigator.of(dialogContext).pop();
                        },
                        child: Text(
                          'Отмена',
                          style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
                );
              },
            );
          },
        );
      }
    } catch (e) {
      // Показываем ошибку пользователю
      print('Ошибка при создании QR-кода для оплаты: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при создании QR-кода для оплаты: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isProcessingPayment = false);
    }
  }
  
  // Запуск периодической проверки статуса платежа
  void _startPaymentStatusChecking(String paymentId) {
    // Отменяем предыдущий таймер, если он был
    _paymentCheckTimer?.cancel();
    
    // Запускаем новый таймер, который будет проверять статус каждые 3 секунды
    _paymentCheckTimer = Timer.periodic(Duration(seconds: 3), (timer) async {
      // Проверяем статус платежа
      try {
        final status = await _paymentService.checkPaymentStatus(paymentId);
        print('Проверка статуса платежа $paymentId: $status');
        
        // Обновляем UI в зависимости от статуса
        if (status == 'processing') {
          // Платеж в обработке - QR-код был отсканирован
          setState(() {
            // В этой точке UI диалога должен показать, что QR-код отсканирован
            // Обновление интерфейса происходит в диалоге через StatefulBuilder
          });
        } else if (status == 'completed') {
          // Платеж успешно завершен
          setState(() {
            // Обновление интерфейса происходит в диалоге через StatefulBuilder
          });
          
          // Показываем сообщение об успешной оплате
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Платеж успешно обработан! Потяните вниз для обновления списка заказов.'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 5),
              ),
            );
          }
          
          // Останавливаем проверку, т.к. платеж завершен
          _paymentCheckTimer?.cancel();
          _paymentCheckTimer = null;
          
        } else if (status == 'failed') {
          // Платеж не удался
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Ошибка при обработке платежа.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          
          // Останавливаем проверку
          _paymentCheckTimer?.cancel();
          _paymentCheckTimer = null;
        }
      } catch (e) {
        print('Ошибка при проверке статуса платежа: $e');
      }
    });
  }
  
  // Вспомогательные методы
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
  Widget _buildProductItem(dynamic item) {
    String name = 'Неизвестный товар';
    double price = 0;
    int quantity = 1;
    String? imageUrl;
    
    // Если это Map (из Firebase), извлекаем данные
    if (item is Map<String, dynamic>) {
      name = item['name'] as String? ?? 
            (item['product'] is Map ? (item['product'] as Map)['name'] as String? ?? 'Неизвестный товар' : 'Неизвестный товар');
      
      price = (item['price'] != null) ? (item['price'] as num).toDouble() : 0;
      quantity = (item['quantity'] != null) ? (item['quantity'] as num).toInt() : 1;
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
      name = item.name;
      price = item.price;
      quantity = item.quantity;
      imageUrl = item.imageUrl;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Изображение товара
          Container(
            width: 36,
            height: 36,
                  decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: Colors.grey[200],
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl != null && imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl.startsWith('http')
                      ? imageUrl
                      : 'https://storage.googleapis.com/ararat-80efa.appspot.com/$imageUrl',
                      fit: BoxFit.cover,
                  errorBuilder: (ctx, obj, trace) => const Center(
                    child: Icon(Icons.image_not_supported, size: 14, color: Colors.grey),
                  ),
                )
              : const Center(
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
                  name,
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
                  '$quantity × ${price.toStringAsFixed(0)} ₽',
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
              '${(price * quantity).toStringAsFixed(0)} ₽',
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
  
  // Метод для создания кнопки действия
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
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

  // Вспомогательный метод для отображения строки информации в диалоге оплаты
  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          Text(
          label,
            style: const TextStyle(
              color: Color(0xFF50321B),
              fontFamily: 'Inter',
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF50321B),
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
              fontSize: 12,
            ),
          ),
        ),
        // Кнопка копирования
        InkWell(
          onTap: () {
            // Копировать значение в буфер обмена
            _copyToClipboard(value);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(4),
            child: const Icon(
              Icons.copy,
              size: 14,
              color: Color(0xFF6C4425),
            ),
          ),
        )
      ],
    );
  }
  
  // Метод для копирования в буфер обмена
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Скопировано в буфер обмена'),
          duration: Duration(seconds: 1),
        ),
      );
    }
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
    case 'slow':
      return 'Обычная доставка';
    case 'fast':
      return 'Быстрая доставка';
    case 'standard':
      return 'Стандартная доставка';
    case 'scheduled':
      return 'Доставка к определенному времени';
    case 'express':
      return 'Экспресс-доставка';
    default:
      // Если неизвестный тип, выводим первую букву заглавной
      if (type.isEmpty) return 'Не указано';
      return type.substring(0, 1).toUpperCase() + type.substring(1);
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