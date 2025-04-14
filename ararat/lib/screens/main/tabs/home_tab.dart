import 'package:flutter/material.dart';
import 'package:ararat/widgets/product_detail_sheet.dart';
import 'package:ararat/services/user_data_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ararat/services/product_service.dart';
import 'package:ararat/models/product.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ararat/services/search_service.dart';
import 'package:ararat/services/product_update_notifier.dart';

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
      // Добавляем количество для экрана избранного и сохраняем исходное количество
      final Map<String, dynamic> newProduct = Map<String, dynamic>.from(product);
      newProduct['quantity'] = 1;
      newProduct['originalQuantity'] = product['quantity'] ?? 0;
      
      final newList = List<Map<String, dynamic>>.from(favoriteProducts);
      newList.add(newProduct);
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
  
  // Локальный кэш количества товаров
  final Map<String, int> _localProductQuantity = {};

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
    // Получаем имя продукта
    final String productName = product['name'];
    
    // Проверяем локальное количество
    if (!_localProductQuantity.containsKey(productName)) {
      // Инициализируем локальное количество из product
      _localProductQuantity[productName] = product['quantity'] as int;
    }
    
    // Если товара больше нет в наличии локально, показываем сообщение и не добавляем
    if (_localProductQuantity[productName]! <= 0) {
      return;
    }
    
    // Уменьшаем локальное количество
    _localProductQuantity[productName] = _localProductQuantity[productName]! - 1;
    
    // Проверяем, есть ли товар уже в корзине
    int existingIndex = cartProducts.indexWhere((item) => item['name'] == productName);
    
    final newList = List<Map<String, dynamic>>.from(cartProducts);
    
    if (existingIndex != -1) {
      // Если товар уже есть, увеличиваем количество
      newList[existingIndex]['quantity'] += 1;
    } else {
      // Если товара нет, добавляем с количеством 1 и id для идентификации
      final Map<String, dynamic> newProduct = Map<String, dynamic>.from(product);
      newProduct['quantity'] = 1;
      newProduct['id'] = DateTime.now().millisecondsSinceEpoch;
      
      // Убедимся, что сохраняем documentId продукта для правильного обновления в Firestore
      if (product.containsKey('documentId') && product['documentId'] != null) {
        newProduct['documentId'] = product['documentId'];
      }
      
      newList.add(newProduct);
    }
    
    cartNotifier.value = newList;
    _saveCartToFirebase();
  }

  // Получение локального количества товара
  int getLocalQuantity(String productName, int originalQuantity) {
    if (!_localProductQuantity.containsKey(productName)) {
      _localProductQuantity[productName] = originalQuantity;
    }
    return _localProductQuantity[productName]!;
  }

  // Проверка, можно ли добавить товар в корзину
  bool canAddToCart(String productName) {
    return _localProductQuantity.containsKey(productName) && 
           _localProductQuantity[productName]! > 0;
  }

  // Сброс локального количества при удалении из корзины
  void removeFromCart(int productId) {
    // Находим товар в корзине
    final item = cartProducts.firstWhere((item) => item['id'] == productId, orElse: () => {});
    
    if (item.isNotEmpty) {
      final String productName = item['name'];
      final int quantity = item['quantity'] as int;
      
      // Возвращаем количество в локальное хранилище
      if (_localProductQuantity.containsKey(productName)) {
        _localProductQuantity[productName] = _localProductQuantity[productName]! + quantity;
      }
    }
    
    final newList = List<Map<String, dynamic>>.from(cartProducts);
    newList.removeWhere((item) => item['id'] == productId);
    cartNotifier.value = newList;
    _saveCartToFirebase();
  }
  
  // Обновление локального количества при изменении количества в корзине
  void incrementQuantity(int productId) {
    final newList = List<Map<String, dynamic>>.from(cartProducts);
    int index = newList.indexWhere((item) => item['id'] == productId);
    
    if (index != -1) {
      final String productName = newList[index]['name'];
      
      // Проверяем локальное наличие
      if (_localProductQuantity.containsKey(productName) && _localProductQuantity[productName]! > 0) {
        // Уменьшаем локальное количество
        _localProductQuantity[productName] = _localProductQuantity[productName]! - 1;
        
        // Увеличиваем в корзине
        newList[index]['quantity'] += 1;
        cartNotifier.value = newList;
        _saveCartToFirebase();
      }
    }
  }
  
  void decrementQuantity(int productId) {
    final newList = List<Map<String, dynamic>>.from(cartProducts);
    int index = newList.indexWhere((item) => item['id'] == productId);
    
    if (index != -1 && newList[index]['quantity'] > 1) {
      final String productName = newList[index]['name'];
      
      // Увеличиваем локальное количество
      if (_localProductQuantity.containsKey(productName)) {
        _localProductQuantity[productName] = _localProductQuantity[productName]! + 1;
      }
      
      // Уменьшаем в корзине
      newList[index]['quantity'] -= 1;
      cartNotifier.value = newList;
      _saveCartToFirebase();
    }
  }
  
  void clearCart() {
    // Восстанавливаем локальные количества
    for (var item in cartProducts) {
      final String productName = item['name'];
      final int quantity = item['quantity'] as int;
      
      if (_localProductQuantity.containsKey(productName)) {
        _localProductQuantity[productName] = _localProductQuantity[productName]! + quantity;
      }
    }
    
    cartNotifier.value = [];
    _saveCartToFirebase();
  }
  
  // Новый метод для очистки корзины после успешного заказа
  void clearCartAfterOrder() {
    // Не восстанавливаем локальные количества - товары уже заказаны
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

  // Проверка и удаление товаров, которых нет в наличии
  void removeOutOfStockItems(List<Map<String, dynamic>> products) {
    final newList = List<Map<String, dynamic>>.from(cartProducts);
    bool hasChanges = false;
    
    // Проходим по товарам в корзине
    for (int i = newList.length - 1; i >= 0; i--) {
      final cartItem = newList[i];
      final String cartItemName = cartItem['name'];
      
      // Ищем соответствующий товар в списке продуктов
      final productExists = products.any((product) => 
        product['name'] == cartItemName && product['inStock'] == true);
      
      // Если товара нет в наличии, удаляем его из корзины
      if (!productExists) {
        newList.removeAt(i);
        hasChanges = true;
      }
    }
    
    // Обновляем корзину только если были изменения
    if (hasChanges) {
      cartNotifier.value = newList;
      _saveCartToFirebase();
    }
  }

  // Метод для обновления локальных количеств товаров в корзине
  void refreshLocalQuantities(List<Map<String, dynamic>> products) {
    print('Обновление локальных количеств товаров с учетом товаров в корзине');
    
    // Сначала обновляем локальные количества из БД
    for (var product in products) {
      final String productName = product['name'];
      final int originalQuantity = product['quantity'] as int? ?? 0;
      
      // Устанавливаем начальное значение из БД
      _localProductQuantity[productName] = originalQuantity;
    }
    
    // Затем вычитаем количество товаров, уже находящихся в корзине
    for (var cartItem in cartProducts) {
      final String cartItemName = cartItem['name'];
      final int cartItemQuantity = cartItem['quantity'] as int;
      
      if (_localProductQuantity.containsKey(cartItemName)) {
        // Уменьшаем доступное количество на количество в корзине
        _localProductQuantity[cartItemName] = _localProductQuantity[cartItemName]! - cartItemQuantity;
        
        // Если получилось отрицательное число, устанавливаем 0
        if (_localProductQuantity[cartItemName]! < 0) {
          _localProductQuantity[cartItemName] = 0;
        }
      }
    }
    
    print('Локальные количества товаров обновлены с учетом корзины');
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
  
  // Сервис для работы с поисковыми запросами
  final _searchService = SearchService();
  
  // Списки продуктов и категорий
  List<Product> _products = [];
  List<String> _categories = [];
  List<String> _filteredCategories = [];
  List<Product> _filteredProducts = [];
  
  // Список популярных запросов
  List<String> _popularQueries = [];
  bool _isLoadingQueries = false;
  
  @override
  void initState() {
    super.initState();
    
    // Инициализируем контроллер для анимации поиска
    _searchAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _searchAnimation = CurvedAnimation(
      parent: _searchAnimController,
      curve: Curves.easeInOut,
    );
    
    // Инициализируем контроллер для скролла
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
    
    // Инициализируем контроллер для анимации обновления
    _refreshAnimController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _refreshAnimation = Tween<double>(
      begin: 0,
      end: 2 * 3.14159, // Полный оборот
    ).animate(_refreshAnimController);
    
    // Инициализируем контроллер для скелетной анимации
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    
    // Инициализируем контроллер для анимации избранного
    _favoriteAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _favoriteAnimation = CurvedAnimation(
      parent: _favoriteAnimController,
      curve: Curves.elasticOut,
    );
    
    // Инициализируем контроллер для анимации корзины
    _cartAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    // Добавляем метод загрузки данных
    _loadData();
    
    // Добавляем слушателя для обновления списка товаров
    ProductUpdateNotifier().updateNotifier.addListener(_onProductsUpdated);
  }
  
  // Метод, вызываемый при обновлении товаров
  void _onProductsUpdated() {
    if (mounted) {
      print('Получено уведомление об обновлении товаров, обновляем список');
      
      // Принудительно сбрасываем кэш продуктов
      _products = [];
      _filteredProducts = [];
      
      // Перезагружаем данные с принудительным обновлением
      setState(() {
        _isLoading = true;
      });
      
      // Полностью перезагружаем данные из Firebase
      _productService.getProductsDirectly().then((productsList) {
        if (mounted) {
          setState(() {
            _products = productsList;
            _loadCategories();
            _isLoading = false;
            
            // Принудительно обновляем локальный кэш товаров в корзине
            final List<Map<String, dynamic>> productsMap = productsList.map((product) => {
              'name': product.name,
              'inStock': product.available && product.quantity > 0,
              'quantity': product.quantity
            }).toList();
            
            // Обновляем и отображаем товары в корзине
            _cartManager.refreshLocalQuantities(productsMap);
            
            // Обновляем исходное количество товаров в избранном
            _updateFavoritesOriginalQuantity(productsList);
          });
        }
      });
    }
  }
  
  @override
  void dispose() {
    _searchAnimController.dispose();
    _scrollController.dispose();
    _refreshAnimController.dispose();
    _shimmerController.dispose();
    _favoriteAnimController.dispose();
    _cartAnimController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    
    // Удаляем слушателя обновлений продуктов
    ProductUpdateNotifier().updateNotifier.removeListener(_onProductsUpdated);
    
    super.dispose();
  }
  
  void _loadCategories() {
    _productService.getCategories().listen((categoriesList) {
      if (mounted) {
        setState(() {
          _categories = categoriesList;
          // Фильтруем категории, оставляя только те, в которых есть товары
          _filterCategories();
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
          // После загрузки продуктов загружаем категории
          _loadCategories();
          _isLoading = false;
          
          // Проверяем и удаляем товары из корзины, которых нет в наличии
          final List<Map<String, dynamic>> productsMap = productsList.map((product) => {
            'name': product.name,
            'inStock': product.available && product.quantity > 0,
            'quantity': product.quantity
          }).toList();
          
          // Обновляем локальный кэш количеств в корзине
          _cartManager.refreshLocalQuantities(productsMap);
          _cartManager.removeOutOfStockItems(productsMap);
          
          // Обновляем исходное количество товаров в избранном
          _updateFavoritesOriginalQuantity(productsList);
        });
      }
    });
  }

  // Метод для обновления исходного количества в избранных товарах
  void _updateFavoritesOriginalQuantity(List<Product> products) {
    final favorites = _favoritesManager.favoriteProducts;
    if (favorites.isEmpty) return;
    
    final newList = List<Map<String, dynamic>>.from(favorites);
    bool hasChanges = false;
    
    for (int i = 0; i < newList.length; i++) {
      final String favoriteName = newList[i]['name'];
      
      // Находим соответствующий продукт по имени
      final product = products.firstWhere(
        (p) => p.name == favoriteName,
        orElse: () => Product(
          id: '',
          name: '',
          price: 0,
          category: '',
          imageUrls: [],
          weight: '',
          available: false,
          quantity: 0,
          unit: '',
          tags: [],
          special: false,
        ),
      );
      
      // Если нашли продукт и его количество отличается от текущего
      if (product.name.isNotEmpty && 
          (newList[i]['originalQuantity'] == null || 
           newList[i]['originalQuantity'] != product.quantity)) {
        newList[i]['originalQuantity'] = product.quantity;
        hasChanges = true;
      }
    }
    
    // Обновляем список, только если были изменения
    if (hasChanges) {
      _favoritesManager.favoritesNotifier.value = newList;
    }
  }

  void _filterCategories() {
    // Фильтруем категории, оставляя только те, в которых есть товары
    _filteredCategories = _categories.where((category) {
      // Проверяем, есть ли товары в данной категории
      return _products.any((product) => product.category == category);
    }).toList();
    
    // Добавляем категорию "Все" в начало списка
    _filteredCategories.insert(0, 'Все');
    
    // Если категория не выбрана, выбираем "Все" по умолчанию
    if (_selectedCategory.isEmpty || !_filteredCategories.contains(_selectedCategory)) {
      _selectedCategory = 'Все';
    }
    
    // Фильтруем продукты в соответствии с выбранной категорией
    _filterProductsByCategory();
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
  
  void _onSearchChanged() {
    if (_searchController.text.isEmpty) {
      // Если поисковая строка пуста, возвращаем фильтрацию только по категории
      setState(() {
        _filterProductsByCategory();
      });
    } else {
      // Иначе фильтруем по запросу и категории
      setState(() {
        _searchProducts(_searchController.text, saveQuery: false);
      });
    }
  }
  
  void _searchProducts(String query, {bool saveQuery = false}) {
    // Приводим запрос к нижнему регистру для сравнения без учета регистра
    final String normalizedQuery = query.toLowerCase();
    
    // Если запрос не пустой и нужно сохранить его, сохраняем в базе данных
    if (saveQuery && query.trim().isNotEmpty) {
      _searchService.saveQuery(query.trim())
        .then((_) => _loadPopularQueries());
    }
    
    // Если выбрана категория "Все" или категория не выбрана, ищем по всем продуктам
    if (_selectedCategory.isEmpty || _selectedCategory == 'Все') {
      _filteredProducts = _products.where((product) {
        return product.name.toLowerCase().contains(normalizedQuery) || 
               (product.description?.toLowerCase().contains(normalizedQuery) ?? false) ||
               (product.ingredients?.toLowerCase().contains(normalizedQuery) ?? false) ||
               product.category.toLowerCase().contains(normalizedQuery);
      }).toList();
    } else {
      // Иначе ищем только среди товаров выбранной категории
      _filteredProducts = _products.where((product) {
        return product.category == _selectedCategory && 
              (product.name.toLowerCase().contains(normalizedQuery) ||
               (product.description?.toLowerCase().contains(normalizedQuery) ?? false) ||
               (product.ingredients?.toLowerCase().contains(normalizedQuery) ?? false));
      }).toList();
    }
    
    // Сортируем результаты поиска
    _sortProducts();
  }
  
  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent) {
      // Load more data
      _loadMoreProducts();
    }
  }
  
  void _loadMoreProducts() {
    // Реализуем логику загрузки дополнительных товаров
    print('Загрузка дополнительных товаров...');
    
    // Обновляем количество товаров, если изменились данные в БД
    _productService.refreshQuantities().then((updatedProducts) {
      if (mounted && updatedProducts.isNotEmpty) {
        setState(() {
          // Обновляем количество в существующих продуктах
          for (var updatedProduct in updatedProducts) {
            final index = _products.indexWhere((p) => p.id == updatedProduct.id);
            if (index != -1) {
              _products[index] = updatedProduct;
            }
          }
          
          // Обновляем отфильтрованные продукты
          _filterProductsByCategory();
          
          // Обновляем доступность товаров в корзине
          final List<Map<String, dynamic>> productsMap = _products.map((product) => {
            'name': product.name,
            'inStock': product.available && product.quantity > 0,
          }).toList();
          
          _cartManager.removeOutOfStockItems(productsMap);
          
          // Обновляем количество в избранном
          _updateFavoritesOriginalQuantity(_products);
        });
      }
    });
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
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C4425),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                                    child: Row(
                                      children: _filteredCategories.map((category) => 
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
                                description: product.description,
                                ingredients: product.ingredients,
                                quantity: product.quantity,
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
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4.0),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        decoration: isSelected ? BoxDecoration(
          color: const Color(0xFF50321B),
          borderRadius: BorderRadius.circular(20),
        ) : null,
        child: Text(
          title,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFFD5D5D5),
          ),
        ),
      ),
    );
  }
  
  Widget _productCard(String name, int price, String weight, String? imageUrl, {String? description, String? ingredients, int quantity = 0}) {
    // Проверяем, находится ли товар в избранном и корзине
    final bool isFavorite = _favoritesManager.isFavorite(name);
    _cartManager.isInCart(name);
    
    // Получаем локальное количество товара
    final int localQuantity = _cartManager.getLocalQuantity(name, quantity);
    final bool canAddMore = localQuantity > 0;
    
    return GestureDetector(
      onTap: () {
        // Открываем детальную информацию о товаре
        final product = {
          'name': name,
          'price': price,
          'weight': weight,
          'imageUrl': imageUrl ?? 'assets/icons/placeholder.png',
          'description': description,
          'ingredients': ingredients,
          'quantity': quantity,
          'documentId': name, // Используем имя как идентификатор документа, если реальный ID не доступен
        };
        
        showProductDetailSheet(context, product).then((result) {
          if (result != null && result['action'] == 'add_to_cart') {
            // Если пользователь нажал кнопку "Добавить в корзину"
            _cartManager.addToCart(product);
            
            // Обновляем UI после изменения локального количества
            setState(() {});
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
                        child: GestureDetector(
                          onTap: () {
                            // Показываем полноразмерное изображение
                            _showFullImage(context, imageUrl ?? 'assets/icons/placeholder.png', name);
                          },
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Изображение продукта
                              imageUrl != null && imageUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    placeholder: (context, url) => const Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFF50321B),
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Image.asset(
                                      'assets/icons/placeholder.png',
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Image.asset(
                                    'assets/icons/placeholder.png',
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                              
                              // Индикатор количества товара
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: localQuantity > 0 ? const Color(0xFF6C4425) : Colors.red[700],
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    localQuantity > 0 ? '$localQuantity шт' : 'Нет в наличии',
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
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
                              onTap: canAddMore ? () {
                                // Добавляем товар в корзину
                                final productData = {
                                  'name': name,
                                  'price': price,
                                  'weight': weight,
                                  'imageUrl': imageUrl ?? 'assets/icons/placeholder.png',
                                  'description': description,
                                  'ingredients': ingredients,
                                  'quantity': quantity,
                                  'inStock': quantity > 0,
                                };
                                _cartManager.addToCart(productData);
                                
                                // Обновляем интерфейс после изменения локального количества
                                setState(() {});
                                
                                // Показываем сообщение
                                if (!_cartManager.canAddToCart(name)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Нельзя добавить больше этого товара'),
                                      backgroundColor: Colors.red,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                } else {
                                  // Показываем уведомление о добавлении товара в корзину
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('${name} добавлен в корзину'),
                                      backgroundColor: const Color(0xFF6C4425),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              } : () {
                                // Показываем уведомление о невозможности добавления
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Нельзя добавить больше этого товара'),
                                    backgroundColor: Colors.red,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              child: Container(
                                height: 36,
                                decoration: BoxDecoration(
                                  color: canAddMore ? const Color(0xFF4B260A) : Colors.grey[400],
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
                        'quantity': quantity,
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
                    // Добавляем отображение результатов поиска или популярных запросов
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
                                  if (_isLoadingQueries)
                                    const Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFF6C4425),
                                      ),
                                    )
                                  else if (_popularQueries.isEmpty)
                                    const Center(
                                      child: Text(
                                        'Нет популярных запросов',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    )
                                  else
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: _popularQueries
                                          .map((query) => _buildSearchTag(query))
                                          .toList(),
                                    ),
                                ],
                              ),
                            )
                          : _buildSearchResults(),
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
        // Устанавливаем текст запроса и обновляем фокус
        setState(() {
          _searchController.text = tag;
          // Сохраняем запрос при выборе из популярных
          _searchProducts(tag, saveQuery: true);
        });
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
  
  // Метод для отображения результатов поиска
  Widget _buildSearchResults() {
    if (_filteredProducts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: Color(0xFF6C4425),
              ),
              SizedBox(height: 16),
              Text(
                'Товары не найдены',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Попробуйте изменить запрос или категорию поиска',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Colors.black38,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    return Column(
      children: [
        // Добавляем кнопку "Сохранить запрос" сверху списка результатов
        Padding(
          padding: const EdgeInsets.only(top: 8.0, left: 16.0, right: 16.0),
          child: ElevatedButton(
            onPressed: () {
              // Сохраняем текущий запрос
              if (_searchController.text.trim().isNotEmpty) {
                _searchService.saveQuery(_searchController.text.trim())
                  .then((_) => _loadPopularQueries());
                
                // Показываем уведомление
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Запрос сохранен'),
                    backgroundColor: Color(0xFF6C4425),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C4425),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Сохранить этот запрос'),
          ),
        ),
        // Список результатов
        Expanded(
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            shrinkWrap: true,
            padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 100),
            itemCount: _filteredProducts.length,
            itemBuilder: (context, index) {
              final product = _filteredProducts[index];
              return _buildSearchResultItem(product);
            },
          ),
        ),
      ],
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
  
  // Метод для создания элемента результата поиска
  Widget _buildSearchResultItem(Product product) {
    // Получаем локальное количество товара
    final int localQuantity = _cartManager.getLocalQuantity(product.name, product.quantity);
    final bool canAddMore = localQuantity > 0;
    
    return GestureDetector(
      onTap: () {
        // Закрываем поиск
        _toggleSearch();
        
        // Открываем детальную информацию о товаре
        final productData = {
          'name': product.name,
          'price': product.price.toInt(),
          'weight': product.weight,
          'imageUrl': product.imageUrls.isNotEmpty ? product.imageUrls[0] : null,
          'description': product.description,
          'ingredients': product.ingredients,
          'quantity': product.quantity,
        };
        
        showProductDetailSheet(context, productData).then((result) {
          if (result != null && result['action'] == 'add_to_cart') {
            _cartManager.addToCart(productData);
            setState(() {}); // Обновляем UI
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Изображение товара
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                color: Colors.white,
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                child: product.imageUrls.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: product.imageUrls[0],
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF50321B),
                            strokeWidth: 2,
                          ),
                        ),
                        errorWidget: (context, url, error) => Image.asset(
                          'assets/icons/placeholder.png',
                          fit: BoxFit.cover,
                        ),
                      )
                    : Image.asset(
                        'assets/icons/placeholder.png',
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            
            // Информация о товаре
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${product.price.toInt()} ₽',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6C4425),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          product.weight,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.category,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Кнопка добавления в корзину
            Padding(
              padding: const EdgeInsets.all(12),
              child: GestureDetector(
                onTap: canAddMore ? () {
                  final productData = {
                    'name': product.name,
                    'price': product.price.toInt(),
                    'weight': product.weight,
                    'imageUrl': product.imageUrls.isNotEmpty ? product.imageUrls[0] : null,
                    'description': product.description,
                    'ingredients': product.ingredients,
                    'quantity': product.quantity,
                    'inStock': product.quantity > 0,
                  };
                  _cartManager.addToCart(productData);
                  
                  // Обновляем интерфейс после изменения локального количества
                  setState(() {});
                  
                  // Показываем сообщение
                  if (!_cartManager.canAddToCart(product.name)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Нельзя добавить больше этого товара'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } else {
                    // Показываем уведомление о добавлении товара в корзину
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${product.name} добавлен в корзину'),
                        backgroundColor: const Color(0xFF6C4425),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                } : () {
                  // Показываем уведомление о невозможности добавления
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Нельзя добавить больше этого товара'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: canAddMore ? const Color(0xFF6C4425) : Colors.grey[400],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.add_shopping_cart,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Добавить метод для отображения полноразмерного изображения
  void _showFullImage(BuildContext context, String imageUrl, String productName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Полупрозрачный фон
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(color: Colors.black87),
            ),
            
            // Изображение
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Название товара вверху
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    productName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                // Изображение с Hero анимацией
                Expanded(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 3.0,
                    child: imageUrl.startsWith('assets/')
                      ? Image.asset(
                          imageUrl,
                          fit: BoxFit.contain,
                        )
                      : CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                          errorWidget: (context, url, error) => const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.white,
                                  size: 48,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Не удалось загрузить изображение',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ),
                ),
                
                // Кнопка закрытия внизу
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF50321B),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Закрыть', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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

  // Метод для загрузки популярных запросов
  Future<void> _loadPopularQueries() async {
    setState(() {
      _isLoadingQueries = true;
    });
    
    try {
      final queries = await _searchService.getPopularQueries();
      if (mounted) {
        setState(() {
          _popularQueries = queries;
          _isLoadingQueries = false;
        });
      }
    } catch (e) {
      print('Ошибка при загрузке популярных запросов: $e');
      if (mounted) {
        setState(() {
          _isLoadingQueries = false;
        });
      }
    }
  }

  // Добавляем метод загрузки данных
  void _loadData() {
    setState(() {
      _isLoading = true;
    });
    
    // Загружаем продукты
    _loadProducts();
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