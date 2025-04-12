import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProductDetailSheet extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailSheet({
    super.key,
    required this.product,
  });

  @override
  State<ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends State<ProductDetailSheet> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _heightAnimation;
  
  bool _isExpanded = false;
  
  // Начальная высота панели (только изображение, название и цена)
  static const double _initialSheetHeight = 250;
  // Полная высота развернутой панели
  static const double _expandedSheetHeight = 500;
  
  // Текущая высота панели при ручном перетаскивании
  double _currentHeight = _initialSheetHeight;
  // Контроллер для определения позиции пальца при перетаскивании
  double _dragStartPosition = 0;
  
  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _heightAnimation = Tween<double>(
      begin: _initialSheetHeight,
      end: _expandedSheetHeight,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
        _currentHeight = _expandedSheetHeight;
      } else {
        _animationController.reverse();
        _currentHeight = _initialSheetHeight;
      }
    });
  }
  
  // Получаем нормализованное значение прогресса анимации (0.0 - 1.0)
  double get _expansionProgress {
    if (_animationController.isAnimating) {
      return _animationController.value;
    } else {
      // Ручное вычисление прогресса на основе текущей высоты
      return (_currentHeight - _initialSheetHeight) / 
          (_expandedSheetHeight - _initialSheetHeight);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Размер экрана для ограничения максимальной высоты
    final screenHeight = MediaQuery.of(context).size.height;
    final maxSheetHeight = screenHeight * 0.9; // 90% от высоты экрана
    
    return GestureDetector(
      // Обрабатываем начало перетаскивания
      onVerticalDragStart: (details) {
        _dragStartPosition = details.globalPosition.dy;
      },
      
      // Обрабатываем перетаскивание
      onVerticalDragUpdate: (details) {
        final dragDistance = _dragStartPosition - details.globalPosition.dy;
        
        // Обновляем текущую высоту на основе перетаскивания
        setState(() {
          _currentHeight = (_currentHeight + dragDistance).clamp(
            _initialSheetHeight, 
            maxSheetHeight
          );
          
          // Определяем, считается ли панель развернутой
          _isExpanded = _currentHeight > (_initialSheetHeight + (_expandedSheetHeight - _initialSheetHeight) / 2);
          
          // Обновляем позицию начала перетаскивания
          _dragStartPosition = details.globalPosition.dy;
        });
      },
      
      // Обрабатываем завершение перетаскивания
      onVerticalDragEnd: (details) {
        // Решаем, в какое состояние анимировать панель
        if (details.velocity.pixelsPerSecond.dy > 500) {
          // Быстрый свайп вниз - закрываем панель
          Navigator.of(context).pop();
        } else if (details.velocity.pixelsPerSecond.dy > 200) {
          // Умеренный свайп вниз - сворачиваем панель
          setState(() {
            _isExpanded = false;
            _currentHeight = _initialSheetHeight;
          });
          _animationController.animateTo(0.0);
        } else if (details.velocity.pixelsPerSecond.dy < -200) {
          // Умеренный свайп вверх - разворачиваем панель
          setState(() {
            _isExpanded = true;
            _currentHeight = _expandedSheetHeight;
          });
          _animationController.animateTo(1.0);
        } else {
          // Медленное перетаскивание - завершаем анимацию в ближайшее состояние
          if (_isExpanded) {
            _animationController.animateTo(1.0);
            _currentHeight = _expandedSheetHeight;
          } else {
            _animationController.animateTo(0.0);
            _currentHeight = _initialSheetHeight;
          }
        }
      },
      
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          // Используем прогресс расширения для анимаций
          final expansionProgress = _expansionProgress;
          
          // Рассчитываем высоту панели
          final height = _animationController.isAnimating
              ? _heightAnimation.value
              : _currentHeight;
          
          // Определяем позицию изображения (фиксированная от верха)
          const imageTopOffset = 30.0;
          
          // Рассчитываем размер изображения для корректного расположения текста
          // Начальный размер 180, но уменьшаем его только до определенного предела
          const double baseImageSize = 180.0;
          const double shrinkFactor = 0.22;
          // Ограничиваем уменьшение размера изображения
          final double limitedExpansionProgress = expansionProgress > 0.6 ? 0.6 : expansionProgress;
          final imageSize = baseImageSize * (1.0 - shrinkFactor * limitedExpansionProgress);
          
          // Вычисляем позицию для основного контента - фиксируем под изображением
          const contentTopOffset = imageTopOffset + baseImageSize + 10.0;
          
          // Рассчитываем прозрачность содержимого
          double contentOpacity;
          if (expansionProgress < 0.4) {
            contentOpacity = 0.0;
          } else {
            contentOpacity = ((expansionProgress - 0.4) / 0.6).clamp(0.0, 1.0);
          }
          
          return Container(
            height: height,
            decoration: const BoxDecoration(
              color: Color(0xFFA99378),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Индикатор свайпа
                Positioned(
                  top: 8,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                
                // Анимированное изображение товара (перемещается влево при растягивании)
                Positioned(
                  top: imageTopOffset,
                  left: 0,
                  right: 0,
                  child: Container(
                    // Используем более сильное смещение влево для достижения нужного эффекта
                    alignment: expansionProgress > 0.6 
                      ? Alignment.centerLeft // При максимальном растяжении - полностью влево
                      : Alignment.lerp(
                          Alignment.center,      // В начальном состоянии - по центру 
                          Alignment.centerLeft,  // Конечная позиция - влево
                          expansionProgress / 0.6 // Делим на 0.6 для достижения Alignment.centerLeft точно при 0.6
                        ),
                    // Добавляем левый отступ при предельном растяжении для лучшего позиционирования
                    padding: EdgeInsets.only(left: expansionProgress > 0.6 ? 20.0 : 20.0 * (expansionProgress / 0.6)),
                    child: Container(
                      // Фиксируем минимальный размер изображения
                      width: imageSize,
                      height: imageSize,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _buildProductImage(widget.product['imageUrl']),
                    ),
                  ),
                ),
                
                // Текст справа от изображения (виден только при растягивании)
                if (expansionProgress > 0.4)
                  Positioned(
                    top: imageTopOffset + 30.0,
                    // Согласуем позицию текста с новой логикой смещения изображения
                    left: expansionProgress > 0.6
                      ? MediaQuery.of(context).size.width * 0.39 // Фиксированная позиция при полном растяжении
                      : MediaQuery.of(context).size.width * (0.5 - 0.11 * (expansionProgress / 0.6)), // Плавно смещаем влево
                    right: 20.0,
                    child: Opacity(
                      // Полная непрозрачность после определенного уровня растяжения
                      opacity: ((expansionProgress - 0.4) / 0.2).clamp(0.0, 1.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Армянский продукт',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Высокое качество',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Анимированная информация о товаре
                Positioned(
                  top: contentTopOffset,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Название и цена видны всегда
                          Text(
                            widget.product['name'],
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${widget.product['price']} ₽',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                widget.product['weight'],
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: Color(0xFFD5D5D5),
                                ),
                              ),
                            ],
                          ),
                          
                          // Дополнительная информация, видна при растягивании
                          if (expansionProgress > 0)
                            Opacity(
                              opacity: contentOpacity.clamp(0.0, 1.0), // Гарантируем допустимый диапазон 0.0-1.0
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 24),
                                  const Divider(color: Colors.white24),
                                  const SizedBox(height: 16),
                                  
                                  const Text(
                                    'Описание',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.product['description'] != null && widget.product['description'].toString().isNotEmpty
                                        ? widget.product['description']
                                        : 'Описание отсутствует',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      color: Color(0xFFD5D5D5),
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 24),
                                  const Text(
                                    'Состав',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.product['ingredients'] != null && widget.product['ingredients'].toString().isNotEmpty
                                        ? widget.product['ingredients']
                                        : 'Информация о составе отсутствует',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      color: Color(0xFFD5D5D5),
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 32),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        // Логика для добавления в корзину
                                        Navigator.pop(context, {'action': 'add_to_cart'});
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF4B260A),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: const Text(
                                        'Добавить в корзину',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
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
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Метод для правильного отображения изображения в зависимости от источника
  Widget _buildProductImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          'assets/icons/placeholder.png',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      );
    }
    
    // Проверяем, является ли URL сетевым или локальным
    if (imageUrl.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          placeholder: (context, url) => const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          ),
          errorWidget: (context, url, error) => Image.asset(
            'assets/icons/placeholder.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      );
    } else {
      // Для локальных ресурсов используем AssetImage
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) => Image.asset(
            'assets/icons/placeholder.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      );
    }
  }
}

/// Показывает детальную информацию о продукте в модальном окне
Future<Map<String, dynamic>?> showProductDetailSheet(
  BuildContext context, 
  Map<String, dynamic> product
) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    enableDrag: true,
    builder: (BuildContext context) {
      return ProductDetailSheet(product: product);
    },
  );
} 