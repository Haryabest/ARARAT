import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ararat/constants/colors.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';

class ProductsTab extends StatefulWidget {
  const ProductsTab({super.key});

  @override
  State<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<ProductsTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  List<Map<String, dynamic>> _categories = [];
  List<String> _imageUrls = [];
  String? _selectedCategoryFilter;
  bool _isLoading = true;
  bool _isCategoriesLoading = true;
  
  // Контроллер для поиска
  final TextEditingController _searchController = TextEditingController();
  
  // Контроллеры для полей формы
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _ingredientsController = TextEditingController();
  
  // Добавляем контроллер для количества товара
  final TextEditingController _quantityController = TextEditingController();
  
  // Текущая выбранная категория
  String? _selectedCategory;
  
  // Флаг для отображения описания
  bool _isDescriptionExpanded = false;
  
  // Контроллеры для новых полей
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  
  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _ingredientsController.dispose();
    _discountController.dispose();
    _weightController.dispose();
    _searchController.dispose();
    _quantityController.dispose(); // Освобождаем новый контроллер
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _loadCategories();
    
    // Добавляем слушатель для поля поиска
    _searchController.addListener(_filterProducts);
  }
  
  // Метод для фильтрации товаров по поисковому запросу
  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      if (query.isEmpty && _selectedCategoryFilter == null) {
        _filteredProducts = List.from(_products);
      } else {
        _filteredProducts = _products.where((product) {
          bool matchesQuery = true;
          bool matchesCategory = true;
          
          if (query.isNotEmpty) {
            final name = (product['name'] as String? ?? '').toLowerCase();
            final description = (product['description'] as String? ?? '').toLowerCase();
            matchesQuery = name.contains(query) || description.contains(query);
          }
          
          if (_selectedCategoryFilter != null) {
            matchesCategory = product['category'] == _selectedCategoryFilter;
          }
          
          return matchesQuery && matchesCategory;
        }).toList();
      }
    });
  }
  
  // Метод для фильтрации товаров по категории
  void _filterByCategory(String? category) {
    setState(() {
      _selectedCategoryFilter = category;
      _filterProducts();
    });
  }
  
  // Метод для загрузки категорий из Firestore
  Future<void> _loadCategories() async {
    if (!mounted) return;
    
    setState(() {
      _isCategoriesLoading = true;
    });

    try {
      // Загружаем категории из коллекции categories
      final collectionRef = _firestore.collection('categories');
      final snapshot = await collectionRef.orderBy('order', descending: false).get();
      
      final categories = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      
      if (!mounted) return;
      
      setState(() {
        _categories = categories;
        _isCategoriesLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isCategoriesLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при загрузке категорий: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Метод для добавления новой категории
  Future<void> _addCategory(String categoryName) async {
    if (categoryName.trim().isEmpty) return;
    
    // Копируем и форматируем имя категории (первая буква заглавная)
    String trimmedName = categoryName.trim();
    if (trimmedName.isNotEmpty) {
      trimmedName = trimmedName[0].toUpperCase() + trimmedName.substring(1);
    }
    
    // Проверка на дубликаты категорий
    bool isDuplicate = _categories.any((cat) => 
      (cat['name'] as String).toLowerCase() == trimmedName.toLowerCase()
    );
    
    if (isDuplicate) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Категория с таким названием уже существует'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    // Показываем индикатор загрузки
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Добавление категории...'),
          duration: Duration(seconds: 2),
        ),
      );
    }
    
    try {
      // Определяем следующий порядковый номер
      int nextOrder = 1;
      if (_categories.isNotEmpty) {
        final maxOrder = _categories
            .map((category) => category['order'] as int? ?? 0)
            .reduce((a, b) => a > b ? a : b);
        nextOrder = maxOrder + 1;
      }
      
      // Добавляем новую категорию в Firestore напрямую
      await _firestore.collection('categories').add({
        'name': trimmedName,
        'order': nextOrder,
      });
      
      // После успешного добавления перезагружаем категории
      await _loadCategories();
      
      if (mounted) {
        setState(() {}); // Обновляем UI
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Категория "$trimmedName" успешно добавлена'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Ошибка при добавлении категории: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при добавлении категории: ${e.toString().split('\n').first}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Метод для удаления категории
  Future<void> _deleteCategory(Map<String, dynamic> categoryData) async {
    final categoryId = categoryData['id'] as String;
    final categoryName = categoryData['name'] as String;
    
    // Проверяем, используется ли категория в товарах
    try {
      final productsWithCategory = await _firestore
          .collection('products')
          .where('category', isEqualTo: categoryName)
          .get();
      
      if (productsWithCategory.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Нельзя удалить категорию "${categoryName}", так как она используется в ${productsWithCategory.docs.length} товарах'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      
      // Показываем индикатор загрузки
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Удаление категории...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      // Удаляем категорию
      await _firestore.collection('categories').doc(categoryId).delete();
      
      // После успешного удаления перезагружаем категории
      await _loadCategories();
      
      if (mounted) {
        setState(() {}); // Обновляем UI
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Категория "$categoryName" успешно удалена'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Ошибка при удалении категории: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при удалении категории: ${e.toString().split('\n').first}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Показать диалог подтверждения удаления категории
  void _showDeleteCategoryConfirmation(Map<String, dynamic> categoryData) {
    final categoryName = categoryData['name'] as String;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFEADAC5),
        title: const Text('Удаление категории'),
        content: Text('Вы уверены, что хотите удалить категорию "$categoryName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена', style: TextStyle(color: Color(0xFF70422F))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () {
              Navigator.pop(context);
              _deleteCategory(categoryData);
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  
  // Показываем диалог для добавления новой категории
  void _showAddCategoryDialog() {
    // Создаем контроллер здесь
    final categoryController = TextEditingController();
    
    // Функция для форматирования текста категории
    String formatCategoryName(String text) {
      if (text.isEmpty) return '';
      return text[0].toUpperCase() + text.substring(1);
    }
    
    // Используем AlertDialog вместо кастомного диалога
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFEADAC5),
              title: const Text('Новая категория', textAlign: TextAlign.center),
              content: TextField(
                controller: categoryController,
                decoration: InputDecoration(
                  hintText: 'Введите название категории',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onChanged: (text) {
                  // Форматируем текст при вводе
                  if (text.isNotEmpty) {
                    final formattedText = formatCategoryName(text);
                    if (formattedText != text) {
                      final selection = categoryController.selection;
                      categoryController.text = formattedText;
                      // Сохраняем позицию курсора
                      if (selection.baseOffset > 0) {
                        categoryController.selection = TextSelection.collapsed(
                          offset: selection.baseOffset,
                        );
                      }
                    }
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Отмена', style: TextStyle(color: Color(0xFF70422F))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF70422F),
                  ),
                  onPressed: () {
                    final categoryName = categoryController.text;
                    if (categoryName.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Введите название категории'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    Navigator.of(dialogContext).pop();
                    _addCategory(categoryName);
                  },
                  child: const Text('Добавить', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _loadProducts() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await _firestore.collection('products').get();
      
      final products = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        
        // Проверяем и синхронизируем свойство inStock на основе фактического количества товара
        final int quantity = (data['quantity'] as int?) ?? 0;
        final bool currentInStock = data['inStock'] as bool? ?? false;
        final bool shouldBeInStock = quantity > 0;
        
        // Если inStock не соответствует фактическому количеству, обновляем его в базе
        if (currentInStock != shouldBeInStock) {
          _firestore.collection('products').doc(doc.id).update({
            'inStock': shouldBeInStock
          });
          data['inStock'] = shouldBeInStock;
        }
        
        return data;
      }).toList();
      
      if (!mounted) return;
      
      // Сохраняем текущую категорию фильтрации перед обновлением списка
      final currentCategoryFilter = _selectedCategoryFilter;
      
      setState(() {
        _products = products;
        
        // Применяем фильтрацию категории, если она была выбрана
        if (currentCategoryFilter != null) {
          _filteredProducts = products.where((product) => 
            product['category'] == currentCategoryFilter
          ).toList();
        } else {
          // Иначе показываем все товары
          _filteredProducts = List.from(products);
        }
        
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
            content: Text('Ошибка при загрузке товаров: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Метод для отображения формы добавления товара
  void _showAddProductForm() {
    // Цветовая схема
    const Color backgroundColor = Color(0xFFFAF6F1);
    const Color primaryColor = Color(0xFF50321B);
    const Color textColor = Color(0xFF2F3036);
    
    // Очищаем поля формы
    _nameController.clear();
    _priceController.clear();
    _descriptionController.clear();
    _imageUrlController.clear();
    _ingredientsController.clear();
    _discountController.clear();
    _weightController.clear();
    _selectedCategory = _categories.isNotEmpty ? _categories[0]['name'] as String : '';
    _isDescriptionExpanded = false;

    // Показываем модальный лист с формой
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalSetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.95,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Заголовок с кнопкой закрытия
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: primaryColor),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const Text(
                            'Добавление товара',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(width: 24), // для выравнивания заголовка по центру
                        ],
                      ),
                    ),
                    
                    // Поле для названия товара
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20.0, top: 20.0),
                      child: TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          hintText: 'Введите название товара',
                          hintStyle: TextStyle(color: Colors.black54),
                          border: InputBorder.none,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(25.0)),
                            borderSide: BorderSide(color: Colors.transparent),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(25.0)),
                            borderSide: BorderSide(color: primaryColor),
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.normal,
                          color: textColor,
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ),
                    
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).viewInsets.bottom,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Поле для изображения
                              Center(
                                child: Container(
                                  width: MediaQuery.of(context).size.width * 0.85,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    borderRadius: BorderRadius.circular(15),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(15),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          _showImageUrlDialog(context);
                                        },
                                        child: _imageUrlController.text.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: _imageUrlController.text,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) => const Center(
                                                child: CircularProgressIndicator(color: Colors.white),
                                              ),
                                              errorWidget: (context, url, error) => const Center(
                                                child: Icon(
                                                  Icons.add_photo_alternate,
                                                  color: Colors.white,
                                                  size: 60,
                                                ),
                                              ),
                                            )
                                          : const Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.add_photo_alternate,
                                                    color: Colors.white,
                                                    size: 60,
                                                  ),
                                                  SizedBox(height: 8),
                                                  Text(
                                                    'Добавить изображение',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              // Расскрывающееся описание
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(15),
                                  child: ExpansionTile(
                                    initiallyExpanded: false,
                                    onExpansionChanged: (expanded) {
                                      modalSetState(() {
                                        _isDescriptionExpanded = expanded;
                                      });
                                    },
                                    title: const Text(
                                      'Описание',
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    trailing: Icon(
                                      _isDescriptionExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                      color: primaryColor,
                                    ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                        child: TextField(
                                          controller: _descriptionController,
                                          decoration: const InputDecoration(
                                            hintText: 'Введите описание товара',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.all(Radius.circular(15)),
                                              borderSide: BorderSide(color: Colors.grey, width: 1),
                                            ),
                                            contentPadding: EdgeInsets.all(12),
                                          ),
                                          maxLines: 5,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Поля ввода цены и скидки
                              Row(
                                children: [
                                  // Поле цены
                                  Expanded(
                                    child: Container(
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                      child: TextField(
                                        controller: _priceController,
                                        decoration: const InputDecoration(
                                          hintText: 'Цена',
                                          contentPadding: EdgeInsets.symmetric(horizontal: 16),
                                          border: InputBorder.none,
                                          hintStyle: TextStyle(color: Colors.grey),
                                          suffixText: '₽',
                                        ),
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Поле скидки
                                  Expanded(
                                    child: Container(
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                      child: TextField(
                                        controller: _discountController,
                                        decoration: const InputDecoration(
                                          hintText: 'Скидка',
                                          contentPadding: EdgeInsets.symmetric(horizontal: 16),
                                          border: InputBorder.none,
                                          hintStyle: TextStyle(color: Colors.grey),
                                          suffixText: '%',
                                        ),
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              
                              // Поля состава и граммовки
                              Row(
                                children: [
                                  // Поле состава
                                  Expanded(
                                    child: Container(
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                      child: TextField(
                                        controller: _ingredientsController,
                                        decoration: const InputDecoration(
                                          hintText: 'Состав',
                                          contentPadding: EdgeInsets.symmetric(horizontal: 16),
                                          border: InputBorder.none,
                                          hintStyle: TextStyle(color: Colors.grey),
                                        ),
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Поле граммовки
                                  Expanded(
                                    child: Container(
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                      child: TextField(
                                        controller: _weightController,
                                        decoration: const InputDecoration(
                                          hintText: 'Граммовка',
                                          contentPadding: EdgeInsets.symmetric(horizontal: 16),
                                          border: InputBorder.none,
                                          hintStyle: TextStyle(color: Colors.grey),
                                          suffixText: 'г',
                                        ),
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Выбор категории
                              Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(25),
                                    onTap: () {
                                      _showCategorySelectionDialog(context, modalSetState);
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _selectedCategory ?? 'Выберите категорию',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const Icon(
                                            Icons.arrow_drop_down,
                                            color: Colors.white,
                                            size: 28,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // Кнопка добавления товара
                              Container(
                                height: 55,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(25),
                                  color: primaryColor,
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      // Закрываем модальное окно и добавляем товар
                                      Navigator.pop(context);
                                      
                                      // После закрытия окна добавляем товар
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        if (mounted) {
                                          _addProductWithoutWaiting();
                                        }
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(25),
                                    child: const Center(
                                      child: Text(
                                        'Добавить',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  
  // Метод для отображения диалога ввода URL изображения
  void _showImageUrlDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFFEADAC5), // Бежевый фон
        title: const Text('URL изображения'),
        content: TextField(
          controller: _imageUrlController,
          decoration: const InputDecoration(
            hintText: 'Введите URL изображения',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text('Отмена', style: TextStyle(color: Color(0xFF70422F))),
          ),
          TextButton(
            onPressed: () {
              // Для обновления состояния в модальном окне необходим setState
              setState(() {}); // Обновляем основное состояние
              Navigator.pop(dialogContext);
            },
            child: const Text('Сохранить', style: TextStyle(color: Color(0xFF70422F))),
          ),
        ],
      ),
    );
  }
  
  // Метод для добавления товара без ожидания завершения операции
  Future<void> _addProductWithoutWaiting() async {
    if (_nameController.text.isEmpty ||
        _priceController.text.isEmpty ||
        _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пожалуйста, заполните все обязательные поля'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Показать индикатор загрузки
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    // Данные продукта
    final Map<String, dynamic> productData = {
      'name': _nameController.text,
      'description': _descriptionController.text,
      'price': double.tryParse(_priceController.text) ?? 0.0,
      'category': _selectedCategory,
      'imageUrls': _imageUrls,
      'weight': _weightController.text,
      'available': true,
      'ingredients': _ingredientsController.text,
      'createdAt': FieldValue.serverTimestamp(),
    };
    
    try {
      // Добавляем продукт в Firestore
      await _firestore.collection('products').add(productData)
          .timeout(const Duration(seconds: 15));
      
      // Обновляем список товаров в отдельной микрозадаче
      if (!mounted) return;
      
      // Загружаем продукты
      await _loadProducts();
      
      if (!mounted) return;
      
      // Обновляем интерфейс
      setState(() {});
      
      // Показываем сообщение об успешном добавлении
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Товар успешно добавлен'),
          backgroundColor: Colors.green,
        ),
      );
    } on TimeoutException catch (_) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Превышено время ожидания при добавлении товара. Проверьте соединение с интернетом.'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (error) {
      // Логируем ошибку
      print('Ошибка при добавлении товара: $error');
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при добавлении товара: ${error.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Метод для отображения диалога выбора категории
  void _showCategorySelectionDialog(BuildContext context, StateSetter modalSetState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 100 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF70422F),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: Center(
                    child: Text(
                      'Выберите категорию',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: _isCategoriesLoading 
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: _categories.map((categoryData) {
                          final category = categoryData['name'] as String;
                          final isSelected = _selectedCategory == category;
                          return InkWell(
                            onTap: () {
                              modalSetState(() {
                                _selectedCategory = category;
                              });
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 0.5,
                                  ),
                                ),
                                color: isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    category,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (isSelected)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 8),
                                      child: Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ),
                const SizedBox(height: 20),
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white.withOpacity(0.1),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => Navigator.pop(context),
                      child: const Center(
                        child: Text(
                          'Отмена',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Показать контекстное меню для товара
  void _showProductContextMenu(BuildContext context, Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: Colors.white,
        children: [
          ListTile(
            leading: const Icon(Icons.edit, color: AppColors.primary),
            title: const Text('Изменить'),
            onTap: () {
              Navigator.pop(context);
              _showEditProductForm(product);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Удалить', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _showDeleteProductConfirmation(product);
            },
          ),
        ],
      ),
    );
  }
  
  // Показать диалог подтверждения удаления товара
  void _showDeleteProductConfirmation(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFEADAC5),
        title: const Text('Удаление товара'),
        content: Text('Вы уверены, что хотите удалить товар "${product['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена', style: TextStyle(color: Color(0xFF70422F))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () {
              Navigator.pop(context);
              _deleteProduct(product);
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  
  // Метод для удаления товара
  Future<void> _deleteProduct(Map<String, dynamic> product) async {
    final productId = product['id'] as String;
    
    try {
      // Показываем индикатор загрузки
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Удаление товара...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      // Удаляем товар
      await _firestore.collection('products').doc(productId).delete();
      
      // После успешного удаления перезагружаем список товаров
      await _loadProducts();
      
      if (mounted) {
        setState(() {}); // Обновляем UI
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Товар "${product['name']}" успешно удален'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Ошибка при удалении товара: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при удалении товара: ${e.toString().split('\n').first}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Метод для обновления количества товара
  Future<void> _updateProductQuantity(String productId, int newQuantity) async {
    try {
      // Показываем индикатор загрузки
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Обновление количества...'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      
      // Обновляем количество и статус наличия
      // Устанавливаем inStock true только если количество товара больше 0
      await _firestore.collection('products').doc(productId).update({
        'quantity': newQuantity,
        'inStock': newQuantity > 0,
      });
      
      // Обновляем список товаров
      await _loadProducts();
      
      if (mounted) {
        setState(() {}); // Обновляем UI
      }
    } catch (e) {
      print('Ошибка при обновлении количества товара: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при обновлении: ${e.toString().split('\n').first}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Метод для открытия диалога ввода количества товара
  void _showQuantityInputDialog(BuildContext context, Map<String, dynamic> product) {
    final currentQuantity = (product['quantity'] as int?) ?? 0;
    final quantityController = TextEditingController(text: currentQuantity.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFEADAC5),
        title: Text('Количество товара "${product['name']}"'),
        content: TextField(
          controller: quantityController,
          decoration: const InputDecoration(
            labelText: 'Введите количество',
            border: OutlineInputBorder(),
            suffixText: 'шт.',
          ),
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена', style: TextStyle(color: Color(0xFF70422F))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF70422F),
            ),
            onPressed: () {
              final newQuantity = int.tryParse(quantityController.text) ?? 0;
              // Проверяем, что количество не отрицательное
              if (newQuantity < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Количество не может быть отрицательным'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context);
              _updateProductQuantity(product['id'], newQuantity);
            },
            child: const Text('Сохранить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Метод для отображения полноразмерного изображения
  void _showFullImage(BuildContext context, String imageUrl, String productName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  productName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Hero(
                  tag: 'product_image_$imageUrl',
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    errorWidget: (context, url, error) => const Center(
                      child: Icon(Icons.error, color: Colors.white, size: 50),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                ),
                child: const Text('Закрыть'),
              ),
            ],
          ),
        );
      },
    );
  }

  // Метод для отображения формы редактирования товара
  void _showEditProductForm(Map<String, dynamic> product) {
    // Заполняем поля формы данными выбранного товара
    _nameController.text = product['name'] ?? '';
    _priceController.text = (product['price'] ?? 0).toString();
    _descriptionController.text = product['description'] ?? '';
    _imageUrlController.text = product['imageUrl'] ?? '';
    _ingredientsController.text = product['ingredients'] ?? '';
    _discountController.text = (product['discount'] ?? 0).toString();
    _weightController.text = product['weight'] ?? '';
    _selectedCategory = product['category'];
    _isDescriptionExpanded = false;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFEADAC5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter modalSetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.95,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Заголовок с кнопкой закрытия
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                    
                    // Заголовок продукта
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Center(
                        child: TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            hintText: 'Введите название товара',
                            hintStyle: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).viewInsets.bottom,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Поле для изображения
                              Center(
                                child: Container(
                                  width: MediaQuery.of(context).size.width * 0.7,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF70422F),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          _showImageUrlDialog(context);
                                        },
                                        child: _imageUrlController.text.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: _imageUrlController.text,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) => const Center(
                                                child: CircularProgressIndicator(),
                                              ),
                                              errorWidget: (context, url, error) => const Center(
                                                child: Icon(
                                                  Icons.add_photo_alternate,
                                                  color: Colors.white,
                                                  size: 60,
                                                ),
                                              ),
                                            )
                                          : const Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.add_photo_alternate,
                                                    color: Colors.white,
                                                    size: 60,
                                                  ),
                                                  SizedBox(height: 8),
                                                  Text(
                                                    'Изменить изображение',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              // Комбо-бокс для описания с анимацией
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: const Color(0xFF70422F),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      modalSetState(() {
                                        _isDescriptionExpanded = !_isDescriptionExpanded;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Описание',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          AnimatedRotation(
                                            turns: _isDescriptionExpanded ? 0.5 : 0,
                                            duration: const Duration(milliseconds: 300),
                                            curve: Curves.easeOutCubic,
                                            child: const Icon(
                                              Icons.keyboard_arrow_down,
                                              color: Colors.white,
                                              size: 28,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              
                              // Плавно анимированный блок описания
                              AnimatedSize(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                child: Container(
                                  height: _isDescriptionExpanded ? null : 0,
                                  padding: EdgeInsets.only(
                                    top: _isDescriptionExpanded ? 12.0 : 0.0,
                                    bottom: _isDescriptionExpanded ? 16.0 : 0.0,
                                  ),
                                  child: Opacity(
                                    opacity: _isDescriptionExpanded ? 1.0 : 0.0,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeOutCubic,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey.shade300),
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: AnimatedSize(
                                        duration: const Duration(milliseconds: 200),
                                        child: TextField(
                                          controller: _descriptionController,
                                          decoration: const InputDecoration(
                                            hintText: 'Введите описание товара',
                                            contentPadding: EdgeInsets.all(16),
                                            border: InputBorder.none,
                                            hintStyle: TextStyle(color: Colors.grey),
                                          ),
                                          maxLines: null,
                                          minLines: 3,
                                          style: const TextStyle(fontSize: 15),
                                          onChanged: (text) {
                                            modalSetState(() {});
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Поля ввода цены и скидки
                              Row(
                                children: [
                                  // Поле цены
                                  Expanded(
                                    child: Container(
                                      height: 55,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey.shade300),
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: TextField(
                                        controller: _priceController,
                                        decoration: const InputDecoration(
                                          hintText: 'Цена',
                                          contentPadding: EdgeInsets.symmetric(horizontal: 16),
                                          border: InputBorder.none,
                                          hintStyle: TextStyle(color: Colors.grey),
                                          suffixText: '₽',
                                        ),
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Поле скидки
                                  Expanded(
                                    child: Container(
                                      height: 55,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey.shade300),
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: TextField(
                                        controller: _discountController,
                                        decoration: const InputDecoration(
                                          hintText: 'Скидка',
                                          contentPadding: EdgeInsets.symmetric(horizontal: 16),
                                          border: InputBorder.none,
                                          hintStyle: TextStyle(color: Colors.grey),
                                          suffixText: '%',
                                        ),
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              
                              // Поля состава и граммовки
                              Row(
                                children: [
                                  // Поле состава
                                  Expanded(
                                    child: Container(
                                      height: 55,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey.shade300),
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: TextField(
                                        controller: _ingredientsController,
                                        decoration: const InputDecoration(
                                          hintText: 'Состав',
                                          contentPadding: EdgeInsets.symmetric(horizontal: 16),
                                          border: InputBorder.none,
                                          hintStyle: TextStyle(color: Colors.grey),
                                        ),
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Поле граммовки
                                  Expanded(
                                    child: Container(
                                      height: 55,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey.shade300),
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: TextField(
                                        controller: _weightController,
                                        decoration: const InputDecoration(
                                          hintText: 'Граммовка',
                                          contentPadding: EdgeInsets.symmetric(horizontal: 16),
                                          border: InputBorder.none,
                                          hintStyle: TextStyle(color: Colors.grey),
                                          suffixText: 'г',
                                        ),
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Выбор категории
                              Theme(
                                data: Theme.of(context).copyWith(
                                  canvasColor: const Color(0xFF70422F),
                                  shadowColor: Colors.black.withOpacity(0.2),
                                ),
                                child: Container(
                                  height: 55,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: const Color(0xFF70422F),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () {
                                        _showCategorySelectionDialog(context, modalSetState);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              _selectedCategory ?? 'Выберите категорию',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const Icon(
                                              Icons.arrow_drop_down,
                                              color: Colors.white,
                                              size: 28,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              
                              // Кнопка сохранения изменений
                              Container(
                                height: 55,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: const Color(0xFF70422F),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      // Закрываем модальное окно и сохраняем изменения
                                      Navigator.pop(context);
                                      
                                      // После закрытия окна обновляем товар
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        if (mounted) {
                                          _updateProduct(product['id']);
                                        }
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: const Center(
                                      child: Text(
                                        'Сохранить изменения',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Метод для обновления данных товара в Firestore
  Future<void> _updateProduct(String productId) async {
    // Проверяем, что заполнены обязательные поля
    if (_nameController.text.isEmpty || _priceController.text.isEmpty || _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заполните обязательные поля: название, цена и категория'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Копируем данные из контроллеров
    final name = _nameController.text.trim();
    final priceText = _priceController.text.trim();
    final description = _descriptionController.text.trim();
    final imageUrl = _imageUrlController.text.trim();
    final ingredients = _ingredientsController.text.trim();
    final discount = _discountController.text.trim();
    final weight = _weightController.text.trim();
    final category = _selectedCategory;
    
    // Очищаем контроллеры
    _nameController.clear();
    _priceController.clear();
    _descriptionController.clear();
    _imageUrlController.clear();
    _ingredientsController.clear();
    _discountController.clear();
    _weightController.clear();
    _selectedCategory = null;
    
    // Показываем индикатор загрузки
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Обновление товара...'),
          duration: Duration(seconds: 2),
        ),
      );
    }
    
    // Данные для обновления
    final productData = {
      'name': name,
      'price': double.tryParse(priceText) ?? 0,
      'description': description,
      'imageUrl': imageUrl,
      'ingredients': ingredients,
      'category': category,
      'discount': double.tryParse(discount) ?? 0,
      'weight': weight,
      'updatedAt': FieldValue.serverTimestamp(),
      // Не меняем quantity и inStock при редактировании
    };
    
    try {
      // Обновляем товар в Firestore
      await _firestore.collection('products').doc(productId).update(productData);
      
      // Обновляем список товаров
      if (mounted) {
        await _loadProducts();
        
        // Обновляем UI
        setState(() {});
        
        // Показываем сообщение об успешном обновлении
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Товар успешно обновлен'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      print('Ошибка при обновлении товара: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при обновлении товара: ${error.toString().split('\n').first}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showSuccessSnackBar(String message) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  // Метод для отображения сообщений об ошибках
  Future<void> _showErrorSnackBar(String message) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  // Метод для синхронизации индикаторов наличия товаров
  Future<void> _syncAllProducts() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      QuerySnapshot productsSnapshot = await FirebaseFirestore.instance.collection('products').get();
      int updatedCount = 0;
      
      for (var doc in productsSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        int quantity = data['quantity'] ?? 0;
        bool currentAvailability = data['available'] ?? false;
        bool newAvailability = quantity > 0;
        
        // Обновляем флаг доступности товара, если он не соответствует количеству
        if (currentAvailability != newAvailability) {
          await FirebaseFirestore.instance.collection('products').doc(doc.id).update({
            'available': newAvailability
          });
          updatedCount++;
        }
      }
      
      setState(() {
        _isLoading = false;
      });
      
      _showSuccessSnackBar('Синхронизировано $updatedCount товаров');
      
      // Обновляем список товаров после синхронизации
      _loadProducts();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Ошибка синхронизации: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = const Color(0xFFFAF6F1);
    final Color primaryColor = const Color(0xFF50321B);
    final Color textColor = const Color(0xFF2F3036);
    
    return Scaffold(
      backgroundColor: backgroundColor,
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        onPressed: () {
          _showAddProductForm();
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        title: const Text(
          'ARARAT ADMIN',
          style: TextStyle(
            color: Color(0xFF50321B),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.sync, color: primaryColor),
            tooltip: 'Синхронизировать наличие',
            onPressed: _syncAllProducts,
          ),
          IconButton(
            icon: Icon(Icons.category_outlined, color: primaryColor),
            tooltip: 'Добавить категорию',
            onPressed: _showAddCategoryDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Поисковая строка с закругленными углами
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Поиск товаров...',
                  hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
                  prefixIcon: Icon(Icons.search, color: primaryColor),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
                ),
              ),
            ),
          ),
          
          // Фильтры категорий с закругленными углами
          SizedBox(
            height: 50,
            child: _isCategoriesLoading
              ? Center(child: CircularProgressIndicator(color: primaryColor))
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _categories.length + 1, // +1 для "Все" категории
                  itemBuilder: (context, index) {
                    // Первый элемент - "Все категории"
                    final isAllCategories = index == 0;
                    final categoryName = isAllCategories
                        ? 'Все'
                        : _categories[index - 1]['name'] as String? ?? '';
                    final isSelected = isAllCategories
                        ? _selectedCategoryFilter == null
                        : _selectedCategoryFilter == _categories[index - 1]['name'];
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: FilterChip(
                        selected: isSelected,
                        onSelected: (selected) {
                          _filterByCategory(selected && !isAllCategories
                              ? categoryName
                              : null);
                        },
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                          side: BorderSide(
                            color: isSelected ? primaryColor : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        selectedColor: Colors.white,
                        showCheckmark: false,
                        label: Text(categoryName),
                        labelStyle: TextStyle(
                          color: isSelected ? primaryColor : textColor.withOpacity(0.7),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  },
                ),
          ),
          
          // Список товаров (основной контент)
          Expanded(
            child: _isLoading
              ? Center(child: CircularProgressIndicator(color: primaryColor))
              : _filteredProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: textColor.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Товары отсутствуют',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _loadProducts,
                          style: TextButton.styleFrom(
                            foregroundColor: primaryColor,
                          ),
                          child: const Text('Обновить'),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    color: primaryColor,
                    onRefresh: () async {
                      await _loadProducts();
                      await _loadCategories();
                    },
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        final imageUrl = product['imageUrl'] as String? ?? '';
                        final name = product['name'] as String? ?? 'Без названия';
                        final price = product['price'] ?? 0;
                        final quantity = (product['quantity'] as int?) ?? 0;
                        final inStock = quantity > 0;

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  _showEditProductForm(product);
                                },
                                onLongPress: () {
                                  _showProductContextMenu(context, product);
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Изображение товара
                                    Expanded(
                                      child: Container(
                                        width: double.infinity,
                                        color: const Color(0xFFFEFEFE),
                                        child: imageUrl.isNotEmpty
                                            ? CachedNetworkImage(
                                                imageUrl: imageUrl,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) => Center(
                                                  child: CircularProgressIndicator(color: primaryColor),
                                                ),
                                                errorWidget: (context, url, error) => const Center(
                                                  child: Icon(
                                                    Icons.image_not_supported_outlined,
                                                    color: Colors.grey,
                                                    size: 40,
                                                  ),
                                                ),
                                              )
                                            : const Center(
                                                child: Icon(
                                                  Icons.image_outlined,
                                                  color: Colors.grey,
                                                  size: 40,
                                                ),
                                              ),
                                      ),
                                    ),
                                    
                                    // Информация о товаре
                                    Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: textColor,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '$price ₽',
                                            style: TextStyle(
                                              color: primaryColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: inStock ? Colors.green : Colors.red,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                inStock ? 'В наличии' : 'Нет в наличии',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: inStock ? Colors.green : Colors.red,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              // Делаем текст кликабельным
                                              InkWell(
                                                onTap: () {
                                                  _showQuantityInputDialog(context, product);
                                                },
                                                child: Text(
                                                  'Кол-во: ${product['quantity'] ?? 0} шт.',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: textColor.withOpacity(0.6),
                                                    decoration: TextDecoration.underline,
                                                  ),
                                                ),
                                              ),
                                              const Spacer(),
                                              // Кнопки + и - для изменения количества
                                              Container(
                                                width: 24,
                                                height: 24,
                                                decoration: BoxDecoration(
                                                  border: Border.all(color: Colors.grey.shade300),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: InkWell(
                                                  onTap: () {
                                                    final currentQuantity = (product['quantity'] as int?) ?? 0;
                                                    if (currentQuantity > 0) {
                                                      _updateProductQuantity(product['id'], currentQuantity - 1);
                                                    }
                                                  },
                                                  child: Icon(Icons.remove, size: 14, color: primaryColor),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Container(
                                                width: 24,
                                                height: 24,
                                                decoration: BoxDecoration(
                                                  color: primaryColor,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: InkWell(
                                                  onTap: () {
                                                    final currentQuantity = (product['quantity'] as int?) ?? 0;
                                                    _updateProductQuantity(product['id'], currentQuantity + 1);
                                                  },
                                                  child: const Icon(Icons.add, size: 14, color: Colors.white),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
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
    );
  }
} 