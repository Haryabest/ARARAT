import 'package:flutter/material.dart';
import 'package:ararat/screens/main/main_screen.dart';
import 'package:ararat/services/order_service.dart';
import 'package:intl/intl.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final OrderService _orderService = OrderService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _historyItems = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Получаем историю заказов
      final history = await _orderService.getOrderHistory();
      
      if (!mounted) return;
      
      setState(() {
        _historyItems = history;
        _isLoading = false;
      });
    } catch (e) {
      print('Ошибка загрузки истории: $e');
      
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
      backgroundColor: const Color(0xFFA99378),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок
              const Text(
                'История',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 16),
              
              // Основной контент
              Expanded(
                child: _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Colors.white,
            ),
            SizedBox(height: 16),
            Text(
              'Загрузка истории...',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                color: Colors.white,
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
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'Ошибка загрузки истории',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _error!,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadHistory,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF50321B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Повторить',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_historyItems.isEmpty) {
      return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 80,
                        color: Colors.white.withOpacity(0.7),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Ничего нет',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Здесь будет отображаться история ваших заказов',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                          color: Color(0xFFD5D5D5),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            // Переход на главную страницу для выбора товаров
                            HomeTabNavigationRequest(2).dispatch(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF50321B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                            splashFactory: NoSplash.splashFactory,
                          ),
                          child: const Text(
                            'Каталог',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      color: const Color(0xFF50321B),
      child: ListView.builder(
        itemCount: _historyItems.length,
        itemBuilder: (context, index) {
          final item = _historyItems[index];
          return _buildHistoryCard(item);
        },
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    // Форматирование дат
    final DateFormat dateFormat = DateFormat('dd.MM.yyyy в HH:mm');
    final String createdDate = dateFormat.format(item['createdAt'] as DateTime);
    final String deletedDate = dateFormat.format(item['deletedAt'] as DateTime);
    
    // Расчет количества товаров
    final List<dynamic> items = item['items'] as List<dynamic>;
    int totalItems = 0;
    for (var itemData in items) {
      totalItems += (itemData['quantity'] as num).toInt();
    }

    // Получение адреса если есть
    String address = '';
    if (item['deliveryAddress'] != null && 
        (item['deliveryAddress'] as Map<String, dynamic>)['address'] != null) {
      address = (item['deliveryAddress'] as Map<String, dynamic>)['address'] as String;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.white,
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
                  'Заказ #${item['id'].toString().substring(0, 8)}',
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
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Удален',
                    style: TextStyle(
                      color: Colors.grey,
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Даты заказа
            Text(
              'Создан: $createdDate',
              style: TextStyle(
                color: Colors.grey[600],
                fontFamily: 'Inter',
                fontSize: 12,
              ),
            ),
            Text(
              'Удален: $deletedDate',
              style: TextStyle(
                color: Colors.grey[600],
                fontFamily: 'Inter',
                fontSize: 12,
              ),
            ),
            
            // Адрес если есть
            if (address.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Адрес: $address',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontFamily: 'Inter',
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
            const SizedBox(height: 12),
            
            // Миниатюры товаров и общая сумма
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Горизонтальный список миниатюр товаров
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: items.isEmpty 
                      ? const Text('Нет товаров')
                      : _buildProductThumbnails(items),
                  ),
                ),
                
                // Общая сумма
                Text(
                  '${(item['total'] as num).toInt()} ₽',
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
            
            // Кнопки действий
            Row(
              children: [
                // Кнопка подробнее
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    onPressed: () => _showOrderDetails(item),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF50321B),
                      side: const BorderSide(color: Color(0xFF50321B)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Подробнее'),
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Кнопка восстановления заказа
                if (item['restorable'] == true)
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => _restoreOrder(item['id'].toString()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF50321B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: const Text('Восстановить'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // Метод для отображения миниатюр товаров
  Widget _buildProductThumbnails(List<dynamic> items) {
    // Ограничиваем число отображаемых миниатюр до 4
    final displayItems = items.length > 4 ? items.sublist(0, 4) : items;
    final hasMore = items.length > 4;
    
    print('Отображение миниатюр товаров: найдено ${displayItems.length} товаров');
    
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: displayItems.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < displayItems.length) {
          final item = displayItems[index];
          
          // Проверяем различные поля для изображения
          String? imageUrl;
          
          if (item is Map<String, dynamic>) {
            // Проверяем разные возможные поля для URL изображения
            if (item.containsKey('imageUrl') && item['imageUrl'] != null) {
              imageUrl = item['imageUrl'] as String?;
            } else if (item.containsKey('image') && item['image'] != null) {
              imageUrl = item['image'] as String?;
            } else if (item.containsKey('img') && item['img'] != null) {
              imageUrl = item['img'] as String?;
            }
            
            print('Товар #$index: ${item['name'] ?? 'без имени'}, imageUrl: $imageUrl');
          }
          
          // Проверяем и исправляем URL изображения
          if (imageUrl != null && imageUrl.isNotEmpty) {
            // Если URL не содержит http/https, добавляем префикс для Firebase Storage
            if (!imageUrl.startsWith('http')) {
              if (imageUrl.startsWith('/')) {
                imageUrl = 'https://firebasestorage.googleapis.com/v0/b/ararat-efa6f.appspot.com/o${Uri.encodeComponent(imageUrl)}?alt=media';
              } else {
                imageUrl = 'https://firebasestorage.googleapis.com/v0/b/ararat-efa6f.appspot.com/o/${Uri.encodeComponent(imageUrl)}?alt=media';
              }
            }
          }
          
          return Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            clipBehavior: Clip.hardEdge,
            child: imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      print('Ошибка загрузки изображения: $error');
                      return Icon(
                        Icons.image_not_supported_outlined,
                        size: 20,
                        color: Colors.grey.shade400,
                      );
                    },
                  )
                : Icon(
                    Icons.fastfood,
                    size: 20,
                    color: Colors.grey.shade400,
                  ),
          );
        } else {
          // Кнопка "еще" для отображения оставшихся товаров
          return Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade200,
            ),
            child: Center(
              child: Text(
                '+${items.length - displayItems.length}',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }
      },
    );
  }
  
  // Метод для отображения подробной информации о заказе
  void _showOrderDetails(Map<String, dynamic> orderData) {
    final List<dynamic> items = orderData['items'] as List<dynamic>;
    
    print('Открытие деталей заказа, товаров: ${items.length}');
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: ListView(
              controller: scrollController,
              children: [
                // Заголовок
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Заказ #${orderData['id'].toString().substring(0, 8)}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF50321B),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Color(0xFF50321B)),
                    ),
                  ],
                ),
                const Divider(),
                
                // Даты
                ListTile(
                  leading: const Icon(Icons.calendar_today, size: 20),
                  title: const Text('Дата создания'),
                  subtitle: Text(DateFormat('dd.MM.yyyy в HH:mm').format(orderData['createdAt'] as DateTime)),
                  dense: true,
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, size: 20),
                  title: const Text('Дата удаления'),
                  subtitle: Text(DateFormat('dd.MM.yyyy в HH:mm').format(orderData['deletedAt'] as DateTime)),
                  dense: true,
                ),
                
                // Адрес доставки
                if (orderData['deliveryAddress'] != null && 
                    (orderData['deliveryAddress'] as Map<String, dynamic>)['address'] != null)
                  ListTile(
                    leading: const Icon(Icons.location_on_outlined, size: 20),
                    title: const Text('Адрес доставки'),
                    subtitle: Text((orderData['deliveryAddress'] as Map<String, dynamic>)['address'] as String),
                    dense: true,
                  ),
                
                // Доставка и оплата
                ListTile(
                  leading: const Icon(Icons.local_shipping_outlined, size: 20),
                  title: const Text('Способ доставки'),
                  subtitle: Text(
                    orderData['deliveryType'] == 'fast' ? 'Срочная' : 
                    orderData['deliveryType'] == 'scheduled' ? 'По расписанию' : 'Стандартная'
                  ),
                  dense: true,
                ),
                ListTile(
                  leading: const Icon(Icons.payment_outlined, size: 20),
                  title: const Text('Способ оплаты'),
                  subtitle: Text(orderData['paymentMethod'] == 'qr' ? 'QR-код' : 'Наличными'),
                  dense: true,
                ),
                
                const SizedBox(height: 16),
                const Text(
                  'Товары',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF50321B),
                  ),
                ),
                const SizedBox(height: 8),
                
                // Список товаров
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final name = item['name'] as String? ?? 'Товар';
                    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                    final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
                    
                    // Проверяем различные поля для изображения
                    String? imageUrl;
                    
                    if (item is Map<String, dynamic>) {
                      // Проверяем разные возможные поля для URL изображения
                      if (item.containsKey('imageUrl') && item['imageUrl'] != null) {
                        imageUrl = item['imageUrl'] as String?;
                      } else if (item.containsKey('image') && item['image'] != null) {
                        imageUrl = item['image'] as String?;
                      } else if (item.containsKey('img') && item['img'] != null) {
                        imageUrl = item['img'] as String?;
                      }
                      
                      print('Детали - Товар #$index: $name, imageUrl: $imageUrl');
                    }
                    
                    // Проверяем и исправляем URL изображения
                    if (imageUrl != null && imageUrl.isNotEmpty) {
                      // Если URL не содержит http/https, добавляем префикс для Firebase Storage
                      if (!imageUrl.startsWith('http')) {
                        if (imageUrl.startsWith('/')) {
                          imageUrl = 'https://firebasestorage.googleapis.com/v0/b/ararat-efa6f.appspot.com/o${Uri.encodeComponent(imageUrl)}?alt=media';
                        } else {
                          imageUrl = 'https://firebasestorage.googleapis.com/v0/b/ararat-efa6f.appspot.com/o/${Uri.encodeComponent(imageUrl)}?alt=media';
                        }
                      }
                    }
                    
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                print('Ошибка загрузки изображения в деталях: $error');
                                return Icon(
                                  Icons.image_not_supported_outlined,
                                  size: 20,
                                  color: Colors.grey.shade400,
                                );
                              },
                            )
                          : Icon(
                              Icons.fastfood,
                              size: 20,
                              color: Colors.grey.shade400,
                            ),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        '$price ₽ × $quantity шт.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      trailing: Text(
                        '${(price * quantity).toStringAsFixed(0)} ₽',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF50321B),
                        ),
                      ),
                    );
                  },
                ),
                
                const Divider(),
                
                // Итоговая информация
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Итого:',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF50321B),
                        ),
                      ),
                      Text(
                        '${(orderData['total'] as num).toInt()} ₽',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF50321B),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Кнопка восстановления
                if (orderData['restorable'] == true)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Закрываем диалог
                      _restoreOrder(orderData['id'].toString());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF50321B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Восстановить заказ'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  // Метод для восстановления заказа
  Future<void> _restoreOrder(String orderId) async {
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
              Text('Восстановление заказа...'),
            ],
          ),
        ),
      ),
    );
    
    try {
      // Восстанавливаем заказ
      await _orderService.restoreOrderFromHistory(orderId);
      
      // Безопасно закрываем индикатор загрузки
      closeLoadingDialog();
      
      // Обновляем список, если виджет всё ещё активен
      if (mounted) {
        setState(() {
          _historyItems.removeWhere((item) => item['id'].toString() == orderId);
        });
        
        // Показываем уведомление
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Заказ успешно восстановлен'),
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
            content: Text('Ошибка при восстановлении заказа: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 