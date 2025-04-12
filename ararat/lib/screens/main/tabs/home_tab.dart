import 'package:flutter/material.dart';
import 'package:ararat/widgets/product_detail_sheet.dart';
import 'package:ararat/services/user_data_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ararat/services/product_service.dart';
import 'package:ararat/models/product.dart';

// Глобальный класс для хранения данных избранного (в реальном приложении это должен быть провайдер или менеджер состояния)
class FavoritesManager {
  static final FavoritesManager _instance = FavoritesManager._internal();

  factory FavoritesManager() {
    return _instance;
  }

  FavoritesManager._internal() {
    _loadFavoritesFromFirebase();
    _listenToAuthChanges();
  }

  final UserDataService _userDataService = UserDataService();

  // Используем ValueNotifier для отслеживания изменений в списке
  final ValueNotifier<List<Map<String, dynamic>>> favoritesNotifier = 
      ValueNotifier<List<Map<String, dynamic>>>([]);
  
  List<Map<String, dynamic>> get favoriteProducts => favoritesNotifier.value;

  // Слушаем изменения аутентификации
  void _listenToAuthChanges() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        // Пользователь вошел в систему - загружаем его данные
        _loadFavoritesFromFirebase();
      } else {
        // Пользователь вышел - очищаем локальные данные
        clearFavorites();
      }
    });
  }

  Future<void> _loadFavoritesFromFirebase() async {
    // Сначала очищаем существующие данные
    favoritesNotifier.value = [];
    
    try {
      final favorites = await _userDataService.loadFavorites();
      if (favorites.isNotEmpty) {
        favoritesNotifier.value = favorites;
      }
    } catch (e) {
      print('Ошибка при загрузке избранного: $e');
    }
  }

  Future<void> _saveFavoritesToFirebase() async {
    try {
      await _userDataService.saveFavorites(favoriteProducts);
    } catch (e) {
      print('Ошибка при сохранении избранного: $e');
    }
  }

  void addToFavorites(Map<String, dynamic> product) {
    // Проверяем, есть ли товар уже в избранном
    bool isExists = favoriteProducts.any((item) => item['name'] == product['name']);
    if (!isExists) {
      // Добавляем количество для экрана избранного
      product['quantity'] = 1;
      final newList = List<Map<String, dynamic>>.from(favoriteProducts);
      newList.add(product);
      favoritesNotifier.value = newList;
      _saveFavoritesToFirebase();
    }
  }

  void removeFromFavorites(String productName) {
    final newList = List<Map<String, dynamic>>.from(favoriteProducts);
    newList.removeWhere((item) => item['name'] == productName);
    favoritesNotifier.value = newList;
    _saveFavoritesToFirebase();
  }

  bool isFavorite(String productName) {
    return favoriteProducts.any((item) => item['name'] == productName);
  }
  
  void clearFavorites() {
    favoritesNotifier.value = [];
  }
}

// Глобальный класс для хранения данных корзины
class CartManager {
  static final CartManager _instance = CartManager._internal();

  factory CartManager() {
    return _instance;
  }

  CartManager._internal() {
    _loadCartFromFirebase();
    _listenToAuthChanges();
  }

  final UserDataService _userDataService = UserDataService();

  // Используем ValueNotifier для отслеживания изменений в списке
  final ValueNotifier<List<Map<String, dynamic>>> cartNotifier = 
      ValueNotifier<List<Map<String, dynamic>>>([]);
  
  List<Map<String, dynamic>> get cartProducts => cartNotifier.value;

  // Слушаем изменения аутентификации
  void _listenToAuthChanges() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        // Пользователь вошел в систему - загружаем его данные
        _loadCartFromFirebase();
      } else {
        // Пользователь вышел - очищаем локальные данные
        clearCart();
      }
    });
  }

  Future<void> _loadCartFromFirebase() async {
    // Сначала очищаем существующие данные
    cartNotifier.value = [];
    
    try {
      final cart = await _userDataService.loadCart();
      if (cart.isNotEmpty) {
        cartNotifier.value = cart;
      }
    } catch (e) {
      print('Ошибка при загрузке корзины: $e');
    }
  }

  Future<void> _saveCartToFirebase() async {
    try {
      await _userDataService.saveCart(cartProducts);
    } catch (e) {
      print('Ошибка при сохранении корзины: $e');
    }
  }

  void addToCart(Map<String, dynamic> product) {
    // Проверяем, есть ли товар уже в корзине
    int existingIndex = cartProducts.indexWhere((item) => item['name'] == product['name']);
    
    final newList = List<Map<String, dynamic>>.from(cartProducts);
    
    if (existingIndex != -1) {
      // Если товар уже есть, увеличиваем количество
      newList[existingIndex]['quantity'] += 1;
    } else {
      // Если товара нет, добавляем с количеством 1 и id для идентификации
      final Map<String, dynamic> newProduct = Map<String, dynamic>.from(product);
      newProduct['quantity'] = 1;
      newProduct['id'] = DateTime.now().millisecondsSinceEpoch;
      newList.add(newProduct);
    }
    
    cartNotifier.value = newList;
    _saveCartToFirebase();
  }

  void removeFromCart(int productId) {
    final newList = List<Map<String, dynamic>>.from(cartProducts);
    newList.removeWhere((item) => item['id'] == productId);
    cartNotifier.value = newList;
    _saveCartToFirebase();
  }
  
  void incrementQuantity(int productId) {
    final newList = List<Map<String, dynamic>>.from(cartProducts);
    int index = newList.indexWhere((item) => item['id'] == productId);
    
    if (index != -1) {
      newList[index]['quantity'] += 1;
      cartNotifier.value = newList;
      _saveCartToFirebase();
    }
  }
  
  void decrementQuantity(int productId) {
    final newList = List<Map<String, dynamic>>.from(cartProducts);
    int index = newList.indexWhere((item) => item['id'] == productId);
    
    if (index != -1 && newList[index]['quantity'] > 1) {
      newList[index]['quantity'] -= 1;
      cartNotifier.value = newList;
      _saveCartToFirebase();
    }
  }
  
  void clearCart() {
    cartNotifier.value = [];
    _saveCartToFirebase();
  }
  
  void updateQuantity(String productName, int quantity) {
    final newList = List<Map<String, dynamic>>.from(cartProducts);
    int index = newList.indexWhere((item) => item['name'] == productName);
    
    if (index != -1) {
      if (quantity <= 0) {
        // Если количество 0 или меньше, удаляем товар
        newList.removeAt(index);
      } else {
        // Иначе обновляем количество
        newList[index]['quantity'] = quantity;
      }
      cartNotifier.value = newList;
      _saveCartToFirebase();
    }
  }

  bool isInCart(String productName) {
    return cartProducts.any((item) => item['name'] == productName);
  }
  
  int getCartItemsCount() {
    return cartProducts.fold(0, (sum, item) => sum + (item['quantity'] as int));
  }
}

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with TickerProviderStateMixin {
  String _selectedCategory = '';
  bool _isLoading = true;
  String _sortType = 'По алфавиту';
  bool _isSearchExpanded = false;
  late AnimationController _searchAnimController;
  late Animation<double> _searchAnimation;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  // Контроллер для анимации скролла
  late ScrollController _scrollController;
  bool _isSearchPinned = false;
  
  // Для кастомной индикации обновления
  bool _isRefreshing = false;
  late AnimationController _refreshAnimController;
  late Animation<double> _refreshAnimation;
  
  // Добавляем контроллер для скелетной анимации
  late AnimationController _shimmerController;
  
  // Менеджер избранного
  final _favoritesManager = FavoritesManager();
  
  // Менеджер корзины
  final _cartManager = CartManager();
  
  // Контроллер для анимации избранного
  late AnimationController _favoriteAnimController;
  late Animation<double> _favoriteAnimation;
  
  // Контроллер для анимации добавления в корзину
  late AnimationController _cartAnimController;

  // Сервис для работы с продуктами
  final _productService = ProductService();
  
  // Списки продуктов и категорий
  List<Product> _products = [];
  List<String> _categories = [];
  List<Product> _filteredProducts = [];
  
  @override
  void initState() {
    super.initState();
    
    // Загружаем категории и продукты
    _loadCategories();
    _loadProducts();
    
    // Инициализируем контроллер скролла
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    
    _searchAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _searchAnimation = CurvedAnimation(
      parent: _searchAnimController,
      curve: Curves.easeInOut,
    );
    
    // Инициализация анимации обновления
    _refreshAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _refreshAnimation = CurvedAnimation(
      parent: _refreshAnimController,
      curve: Curves.easeInOut,
    );
    
    // Инициализируем контроллер для скелетной анимации
    _shimmerController = AnimationController.unbounded(vsync: this)
      ..repeat(min: -0.5, max: 1.5, period: const Duration(milliseconds: 1000));
      
    // Инициализируем контроллер для анимации избранного
    _favoriteAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _favoriteAnimation = CurvedAnimation(
      parent: _favoriteAnimController,
      curve: Curves.elasticOut,
    );
    
    // Инициализируем контроллер для анимации корзины
    _cartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }
  
  void _loadCategories() {
    _productService.getCategories().listen((categoriesList) {
      if (mounted) {
        setState(() {
          _categories = categoriesList;
          if (_categories.isNotEmpty && _selectedCategory.isEmpty) {
            _selectedCategory = _categories[0];
            _filterProductsByCategory();
          }
        });
      }
    });
  }

  void _loadProducts() {
    setState(() {
      _isLoading = true;
    });

    _productService.getProducts().listen((productsList) {
      if (mounted) {
        setState(() {
          _products = productsList;
          _filterProductsByCategory();
          _isLoading = false;
        });
      }
    });
  }

  void _filterProductsByCategory() {
    if (_selectedCategory.isEmpty || _selectedCategory == 'Все') {
      _filteredProducts = List.from(_products);
    } else {
      _filteredProducts = _products
          .where((product) => product.category == _selectedCategory)
          .toList();
    }

    // Сортируем продукты
    _sortProducts();
  }

  void _sortProducts() {
    if (_sortType == 'По цене') {
      _filteredProducts.sort((a, b) => a.price.compareTo(b.price));
    } else if (_sortType == 'По алфавиту') {
      _filteredProducts.sort((a, b) => a.name.compareTo(b.name));
    }
  }
  
  // Слушатель скролла для анимации кнопки поиска и обновления
  void _onScroll() {
    // Логика для закрепления поиска
    if (_scrollController.offset > 60 && !_isSearchPinned) {
      setState(() {
        _isSearchPinned = true;
      });
    } else if (_scrollController.offset <= 60 && _isSearchPinned) {
      setState(() {
        _isSearchPinned = false;
      });
    }
    
    // Логика для обновления при скролле вниз
    if (_scrollController.offset <= -70 && !_isRefreshing) {
      _startRefresh();
    }
  }
  
  // Метод для запуска процесса обновления
  void _startRefresh() {
    setState(() {
      _isRefreshing = true;
    });
    
    _refreshAnimController.forward();
    
    // Имитация загрузки данных
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
        
        _refreshAnimController.reverse();
      }
    });
  }
  
  @override
  void dispose() {
    _searchAnimController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _shimmerController.dispose();
    _favoriteAnimController.dispose();
    _refreshAnimController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _cartAnimController.dispose();
    super.dispose();
  }
  
  void _toggleSearch() {
    setState(() {
      _isSearchExpanded = !_isSearchExpanded;
      if (_isSearchExpanded) {
        _searchAnimController.forward();
        Future.delayed(const Duration(milliseconds: 300), () {
          _searchFocusNode.requestFocus();
        });
      } else {
        _searchAnimController.reverse();
        _searchFocusNode.unfocus();
        _searchController.clear();
      }
    });
  }
  
  void _selectCategory(String category) {
    if (_selectedCategory != category) {
      setState(() {
        _selectedCategory = category;
        _isLoading = true;
      });
      
      // Фильтрация товаров по категории
      _filterProductsByCategory();
      
      // Имитация загрузки
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFFA99378),
        body: Stack(
          children: [
            // Основное содержимое
            SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(), // Эффект пружины при скролле
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Кастомный индикатор обновления
                  AnimatedBuilder(
                    animation: _refreshAnimation,
                    builder: (context, child) {
                      return SizedBox(
                        height: _isRefreshing || _refreshAnimController.isAnimating 
                            ? 60 * _refreshAnimation.value 
                            : 0,
                        child: Center(
                          child: Opacity(
                            opacity: _refreshAnimation.value.clamp(0.0, 1.0),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF50321B),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                  ),
                  
                  // Плейсхолдер для кнопки поиска (чтобы не было скачка при прикреплении)
                  SizedBox(
                    height: _isSearchPinned ? 66 : 0,
                  ),
                  
                  // Только если НЕ прикрепили кнопку - показываем её тут
                  if (!_isSearchPinned)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0.0),
                      child: _buildSearchButton(),
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // Категории с сортировкой
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C4425),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: _categories.map((category) => 
                                        _categoryItem(category, _selectedCategory == category)
                                      ).toList(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _showSortingModal,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C4425),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Image.asset(
                              'assets/icons/sort.png',
                              width: 18,
                              height: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Индикатор загрузки или список товаров
                  _isLoading 
                    ? _buildSkeletonLoading()
                    : _filteredProducts.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Text(
                              'Товары не найдены',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.75,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: _filteredProducts.length,
                            itemBuilder: (context, index) {
                              final product = _filteredProducts[index];
                              return _productCard(
                                product.name,
                                product.price.toInt(),
                                product.weight,
                                product.imageUrls.isNotEmpty ? product.imageUrls[0] : null,
                              );
                            },
                          ),
                        ),
                ],
              ),
            ),
            
            // Закрепленная кнопка поиска сверху
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              top: _isSearchPinned ? 0 : -70,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isSearchPinned ? 1.0 : 0.0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFA99378),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _buildSearchButton(),
                ),
              ),
            ),
            
            // Анимированный поиск
            _buildSearchOverlay(),
          ],
        ),
      ),
    );
  }
  
  Widget _categoryItem(String title, bool isSelected) {
    return GestureDetector(
      onTap: () => _selectCategory(title),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFFD5D5D5),
              ),
            ),
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 4),
                height: 2,
                width: title.length * 7.0, // Примерная ширина подчеркивания под текстом
                color: Colors.white,
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _productCard(String name, int price, String weight, String? imageUrl) {
    // Проверяем, находится ли товар в избранном и корзине
    final bool isFavorite = _favoritesManager.isFavorite(name);
    _cartManager.isInCart(name);
    
    return GestureDetector(
      onTap: () {
        // Открываем детальную информацию о товаре
        final product = {
          'name': name,
          'price': price,
          'weight': weight,
          'imageUrl': imageUrl ?? 'assets/icons/placeholder.png',
        };
        
        showProductDetailSheet(context, product).then((result) {
          if (result != null && result['action'] == 'add_to_cart') {
            // Если пользователь нажал кнопку "Добавить в корзину"
            _cartManager.addToCart(product);
          }
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF6C4425),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Картинка товара с закругленными углами
                Expanded(
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, left: 10, right: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: imageUrl != null && imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  return Image.asset(
                                    'assets/icons/placeholder.png',
                                    fit: BoxFit.cover,
                                  );
                                },
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded / 
                                            loadingProgress.expectedTotalBytes!
                                          : null,
                                    ),
                                  );
                                },
                              )
                            : Image.asset(
                                'assets/icons/placeholder.png',
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                      ),
                    ),
                  ),
                ),
                
                // Информация о товаре
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Цена и вес
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$price ₽',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            weight,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 8,
                              fontWeight: FontWeight.normal,
                              color: Color(0xFF8E8B8B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      
                      // Название товара
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      
                      // Кнопки действий
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                // Добавляем товар в корзину
                                final product = {
                                  'name': name,
                                  'price': price,
                                  'weight': weight,
                                  'imageUrl': imageUrl ?? 'assets/icons/placeholder.png',
                                };
                                _cartManager.addToCart(product);
                              },
                              child: Container(
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4B260A),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Center(
                                  child: Image.asset(
                                    'assets/icons/basket.png',
                                    width: 18,
                                    height: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4B260A),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.add,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Кнопка избранного (в правом верхнем углу)
            Positioned(
              top: 15,
              right: 15,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (isFavorite) {
                      _favoritesManager.removeFromFavorites(name);
                    } else {
                      // Создаем продукт для добавления в избранное
                      final product = {
                        'name': name,
                        'price': price,
                        'weight': weight,
                        'imageUrl': imageUrl ?? 'assets/icons/placeholder.png',
                      };
                      _favoritesManager.addToFavorites(product);
                    }
                  });
                },
                child: AnimatedBuilder(
                  animation: _favoriteAnimation,
                  builder: (context, child) {
                    double scale = isFavorite 
                      ? 1.0 + (_favoriteAnimation.value * 0.4)
                      : 1.0;
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            size: 18,
                            color: isFavorite ? Colors.red : Colors.grey,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSearchButton() {
    return GestureDetector(
      onTap: _toggleSearch,
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFF6C4425),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image(
                image: AssetImage('assets/icons/search.png'),
                width: 20,
                height: 20,
                color: Colors.white,
              ),
              SizedBox(width: 8),
              Text(
                'Поиск',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSearchOverlay() {
    return AnimatedBuilder(
      animation: _searchAnimation,
      builder: (context, child) {
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: _isSearchExpanded ? MediaQuery.of(context).size.height : 0,
          child: Opacity(
            opacity: _searchAnimation.value.clamp(0.0, 1.0),
            child: Visibility(
              visible: _searchAnimation.value > 0,
              child: Container(
                color: const Color(0xFFFAF6F1),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                child: Row(
                                  children: [
                                    Image.asset(
                                      'assets/icons/search.png',
                                      color: const Color(0xFF6C4425),
                                      width: 20,
                                      height: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: _searchController,
                                        focusNode: _searchFocusNode,
                                        cursorColor: const Color(0xFF6C4425),
                                        decoration: const InputDecoration(
                                          hintText: 'Поиск товаров...',
                                          hintStyle: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 16,
                                            color: Colors.grey,
                                          ),
                                          border: InputBorder.none,
                                        ),
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 16,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                    if (_searchController.text.isNotEmpty)
                                      GestureDetector(
                                        onTap: () {
                                          _searchController.clear();
                                        },
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.grey,
                                          size: 20,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _toggleSearch,
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                'Отмена',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF6C4425),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Здесь можно добавить популярные запросы или результаты поиска
                    Expanded(
                      child: _searchController.text.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Популярные запросы',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _buildSearchTag('Аджика'),
                                      _buildSearchTag('Бастурма'),
                                      _buildSearchTag('Гранатовый сок'),
                                      _buildSearchTag('Лаваш'),
                                      _buildSearchTag('Сыр'),
                                      _buildSearchTag('Варенье'),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: 0, // Заглушка для результатов поиска
                              itemBuilder: (context, index) => const SizedBox(),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildSearchTag(String tag) {
    return GestureDetector(
      onTap: () {
        _searchController.text = tag;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF6C4425).withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          tag,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: Color(0xFF6C4425),
          ),
        ),
      ),
    );
  }
  
  // Метод построения скелетной анимации
  Widget _buildSkeletonLoading() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: 6, // Показываем 6 скелетов карточек
        itemBuilder: (context, index) {
          return _buildSkeletonCard();
        },
      ),
    );
  }
  
  Widget _buildSkeletonCard() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF6C4425),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Скелет картинки товара
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, left: 10, right: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: [
                        Colors.grey[500]!,
                        Colors.grey[400]!,
                        Colors.grey[500]!,
                      ],
                      stops: const [0.1, 0.3, 0.4],
                      begin: const Alignment(-1.0, -0.3),
                      end: const Alignment(1.0, 0.3),
                      transform: _SlidingGradientTransform(
                        slidePercent: _shimmerController.value
                      ),
                    ),
                  ),
                ),
              ),
              
              // Скелет информации о товаре
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Скелет цены и веса
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 60,
                          height: 16,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: LinearGradient(
                              colors: [
                                Colors.grey[500]!,
                                Colors.grey[400]!,
                                Colors.grey[500]!,
                              ],
                              stops: const [0.1, 0.3, 0.4],
                              begin: const Alignment(-1.0, -0.3),
                              end: const Alignment(1.0, 0.3),
                              transform: _SlidingGradientTransform(
                                slidePercent: _shimmerController.value
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 40,
                          height: 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: LinearGradient(
                              colors: [
                                Colors.grey[500]!,
                                Colors.grey[400]!,
                                Colors.grey[500]!,
                              ],
                              stops: const [0.1, 0.3, 0.4],
                              begin: const Alignment(-1.0, -0.3),
                              end: const Alignment(1.0, 0.3),
                              transform: _SlidingGradientTransform(
                                slidePercent: _shimmerController.value
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Скелет названия
                    Container(
                      width: double.infinity,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          colors: [
                            Colors.grey[500]!,
                            Colors.grey[400]!,
                            Colors.grey[500]!,
                          ],
                          stops: const [0.1, 0.3, 0.4],
                          begin: const Alignment(-1.0, -0.3),
                          end: const Alignment(1.0, 0.3),
                          transform: _SlidingGradientTransform(
                            slidePercent: _shimmerController.value
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: MediaQuery.of(context).size.width * 0.3,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          colors: [
                            Colors.grey[500]!,
                            Colors.grey[400]!,
                            Colors.grey[500]!,
                          ],
                          stops: const [0.1, 0.3, 0.4],
                          begin: const Alignment(-1.0, -0.3),
                          end: const Alignment(1.0, 0.3),
                          transform: _SlidingGradientTransform(
                            slidePercent: _shimmerController.value
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Скелет кнопок
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 36,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.grey[500]!,
                                  Colors.grey[400]!,
                                  Colors.grey[500]!,
                                ],
                                stops: const [0.1, 0.3, 0.4],
                                begin: const Alignment(-1.0, -0.3),
                                end: const Alignment(1.0, 0.3),
                                transform: _SlidingGradientTransform(
                                  slidePercent: _shimmerController.value
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: 36,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.grey[500]!,
                                  Colors.grey[400]!,
                                  Colors.grey[500]!,
                                ],
                                stops: const [0.1, 0.3, 0.4],
                                begin: const Alignment(-1.0, -0.3),
                                end: const Alignment(1.0, 0.3),
                                transform: _SlidingGradientTransform(
                                  slidePercent: _shimmerController.value
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  void _showSortingModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFA99378),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Сортировка',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  _sortOption(
                    'По цене', 
                    _sortType == 'По цене',
                    () {
                      setModalState(() {
                        _sortType = 'По цене';
                      });
                    }
                  ),
                  
                  _sortOption(
                    'По алфавиту', 
                    _sortType == 'По алфавиту',
                    () {
                      setModalState(() {
                        _sortType = 'По алфавиту';
                      });
                    }
                  ),
                  
                  const SizedBox(height: 20),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          // Сохраняем выбранный тип сортировки
                          _sortProducts();
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4B260A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Применить',
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
            );
          }
        );
      },
    );
  }
  
  Widget _sortOption(String title, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? Colors.white : const Color(0xFF524F4F),
              ),
              child: isSelected 
                ? const Icon(Icons.check, size: 16, color: Color(0xFF6C4425))
                : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoBlock(int index) {
    if (_categories.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final int categoryIndex = index % _categories.length;
    final String category = _categories[categoryIndex];
    
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      width: 300,
      decoration: BoxDecoration(
        color: const Color(0xFF6C4425),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Иконка скидки
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF50321B),
            ),
            child: const Center(
              child: Text(
                '20%',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Информация о скидке
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Скидка недели',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                
                // Описание акции
                Text(
                  'На выбранные товары из категории "$category"',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: Color(0xFFD5D5D5),
                  ),
                ),
                const SizedBox(height: 8),
                
                // Кнопка "Подробнее"
                GestureDetector(
                  onTap: () {
                    // Можно добавить переход на экран с акциями
                  },
                  child: const Text(
                    'Подробнее',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      decoration: TextDecoration.underline,
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
}

// Класс для рисования черно-желтых полос
class StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    
    // Размер полосы
    double stripeWidth = 12.0;
    
    // Рисуем полосы
    for (double i = -stripeWidth; i < size.width + stripeWidth; i += stripeWidth) {
      // Желтая полоса
      paint.color = const Color(0xFFFFD600);
      var yellowPath = Path();
      yellowPath.moveTo(i, 0);
      yellowPath.lineTo(i + stripeWidth, 0);
      yellowPath.lineTo(i, size.height);
      yellowPath.lineTo(i - stripeWidth, size.height);
      yellowPath.close();
      canvas.drawPath(yellowPath, paint);
      
      // Черная полоса
      paint.color = Colors.black;
      var blackPath = Path();
      blackPath.moveTo(i + stripeWidth, 0);
      blackPath.lineTo(i + 2 * stripeWidth, 0);
      blackPath.lineTo(i + stripeWidth, size.height);
      blackPath.lineTo(i, size.height);
      blackPath.close();
      canvas.drawPath(blackPath, paint);
    }
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({
    required this.slidePercent,
  });

  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
} 