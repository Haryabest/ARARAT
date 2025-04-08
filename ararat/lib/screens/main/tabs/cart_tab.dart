import 'package:ararat/widgets/checkout_form.dart';
import 'package:flutter/material.dart';
import 'package:ararat/screens/main/main_screen.dart';
import 'package:ararat/screens/main/tabs/home_tab.dart';

class CartTab extends StatefulWidget {
  const CartTab({super.key});

  @override
  State<CartTab> createState() => _CartTabState();
}

class _CartTabState extends State<CartTab> with TickerProviderStateMixin {
  late final CartManager _cartManager;
  int _cutleryCount = 1; // Количество приборов
  
  // Контроллер для анимации нажатия на кнопку урны
  late AnimationController _deleteButtonController;
  late Animation<double> _deleteButtonAnimation;
  
  // Контроллеры для анимации кнопок "Каталог" и "Оформить заказ"
  late AnimationController _catalogButtonController;
  late Animation<double> _catalogButtonAnimation;
  
  late AnimationController _checkoutButtonController;
  late Animation<double> _checkoutButtonAnimation;
  
  // Контроллеры для анимации кнопок управления количеством товара
  late AnimationController _decrementButtonController;
  
  late AnimationController _incrementButtonController;
  
  // Контроллеры для анимации кнопок управления количеством приборов
  late AnimationController _decrementCutleryController;
  
  late AnimationController _incrementCutleryController;
  
  @override
  void initState() {
    super.initState();
    _cartManager = CartManager();
    
    // Инициализация контроллера анимации для кнопки удаления
    _deleteButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    
    _deleteButtonAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(
        parent: _deleteButtonController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Инициализация контроллера анимации для кнопки "Каталог"
    _catalogButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    
    _catalogButtonAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _catalogButtonController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Инициализация контроллера анимации для кнопки "Оформить заказ"
    _checkoutButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    
    _checkoutButtonAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _checkoutButtonController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Инициализация контроллеров для кнопок управления количеством товара
    _decrementButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    
    
    _incrementButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    
    
    // Инициализация контроллеров для кнопок управления количеством приборов
    _decrementCutleryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    
    
    _incrementCutleryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    
  }
  
  @override
  void dispose() {
    _deleteButtonController.dispose();
    _catalogButtonController.dispose();
    _checkoutButtonController.dispose();
    _decrementButtonController.dispose();
    _incrementButtonController.dispose();
    _decrementCutleryController.dispose();
    _incrementCutleryController.dispose();
    super.dispose();
  }
  
  // Метод для показа диалога подтверждения
  void _showClearCartDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFA99378),
          title: const Text(
            'Очистить корзину?',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          content: const Text(
            'Вы уверены, что хотите удалить все товары из корзины?',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: Colors.white,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          actions: [
            // Кнопка "Отмена"
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Отмена',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Кнопка "Очистить"
            ElevatedButton(
              onPressed: () {
                _cartManager.clearCart();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC4302B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text(
                'Очистить',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  double get _totalAmount {
    double total = 0;
    for (var item in _cartManager.cartNotifier.value) {
      total += (item['price'] as double) * (item['quantity'] as int);
    }
    return total;
  }
  
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFA99378),
        body: SafeArea(
          child: ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: _cartManager.cartNotifier,
            builder: (context, cartItems, _) {
              if (cartItems.isEmpty) {
                return _buildEmptyCart();
              }
              
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Кнопка очистки корзины (иконка урны) с анимацией
                        AnimatedBuilder(
                          animation: _deleteButtonAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _deleteButtonAnimation.value,
                              child: ElevatedButton(
                                onPressed: () {
                                  // Запускаем анимацию нажатия
                                  _deleteButtonController.forward().then((_) {
                                    _deleteButtonController.reverse();
                                  });
                                  
                                  // Показываем диалог подтверждения
                                  _showClearCartDialog();
                                },
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(40, 40),
                                  padding: EdgeInsets.zero,
                                  backgroundColor: const Color(0xFF50321B),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                  splashFactory: NoSplash.splashFactory,
                                  shadowColor: Colors.transparent,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Image.asset(
                                  'assets/icons/urn.png',
                                  width: 20,
                                  height: 20,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          }
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: cartItems.length,
                      itemBuilder: (context, index) {
                        final item = cartItems[index];
                        return _buildCartItem(item);
                      },
                    ),
                  ),
                  _buildCutleryBlock(), // Блок для выбора количества приборов
                  _buildBottomBar(context),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Пустая корзина - состояние по умолчанию
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart,
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
                    'Вы можете добавить в корзину заказы из нашего каталога',
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
                    child: AnimatedBuilder(
                      animation: _catalogButtonAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _catalogButtonAnimation.value,
                          child: ElevatedButton(
                            onPressed: () {
                              // Анимация нажатия
                              _catalogButtonController.forward().then((_) {
                                _catalogButtonController.reverse();
                              });
                              
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
                              shadowColor: Colors.transparent,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF6C4425),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Изображение товара
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.white,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.asset(
                'assets/icons/placeholder.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Информация о товаре
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] as String,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item['weight']}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: Color(0xFFD5D5D5),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(item['price'] as double)} ₽',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // Управление количеством
          _buildQuantityControl(item),
        ],
      ),
    );
  }

  Widget _buildQuantityControl(Map<String, dynamic> item) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFF50321B),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Кнопка уменьшения количества
          SizedBox(
            width: 28,
            height: 28,
            child: ElevatedButton(
              onPressed: () {
                if ((item['quantity'] as int) > 1) {
                  _cartManager.decrementQuantity(item['id'] as int);
                } else {
                  _cartManager.removeFromCart(item['id'] as int);
                }
              },
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(28, 28),
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
              ),
              child: const Icon(
                Icons.remove,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
          // Отображение количества
          Container(
            width: 32,
            alignment: Alignment.center,
            child: Text(
              '${item['quantity']}',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
          // Кнопка увеличения количества
          SizedBox(
            width: 28,
            height: 28,
            child: ElevatedButton(
              onPressed: () {
                _cartManager.incrementQuantity(item['id'] as int);
              },
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(28, 28),
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
              ),
              child: const Icon(
                Icons.add,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Блок для выбора количества приборов
  Widget _buildCutleryBlock() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF6C4425),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Иконка приборов
          const Icon(
            Icons.restaurant,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Приборы',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // Контроль количества приборов
          Container(
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFF4B260A),
            ),
            child: Row(
              children: [
                // Кнопка уменьшения
                SizedBox(
                  width: 28,
                  height: 28,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_cutleryCount > 0) {
                        setState(() {
                          _cutleryCount--;
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(28, 28),
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      splashFactory: NoSplash.splashFactory,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(8),
                          bottomLeft: Radius.circular(8),
                        ),
                      ),
                    ),
                    child: const Icon(
                      Icons.remove,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Количество
                Container(
                  width: 40,
                  alignment: Alignment.center,
                  child: Text(
                    '$_cutleryCount',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Кнопка увеличения
                SizedBox(
                  width: 28,
                  height: 28,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _cutleryCount++;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(28, 28),
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      splashFactory: NoSplash.splashFactory,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                    ),
                    child: const Icon(
                      Icons.add,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF50321B),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Итоговая сумма
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Итого:',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              Text(
                '${_totalAmount.toStringAsFixed(0)} ₽',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Кнопка оформления заказа
          Container(
            width: double.infinity,
            height: 40,
            margin: const EdgeInsets.only(top: 0),
            child: AnimatedBuilder(
              animation: _checkoutButtonAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _checkoutButtonAnimation.value,
                  child: ElevatedButton(
                    onPressed: () {
                      // Анимация нажатия
                      _checkoutButtonController.forward().then((_) {
                        _checkoutButtonController.reverse();
                      });
                      
                      // Показываем форму оформления заказа
                      showCheckoutForm(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF50321B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                      splashFactory: NoSplash.splashFactory,
                      shadowColor: Colors.transparent,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Оформить заказ',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF50321B),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Метод для показа формы оформления заказа
  void showCheckoutForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CheckoutForm(),
    );
  }
} 