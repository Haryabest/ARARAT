import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ararat/constants/colors.dart';
import 'dart:math' as math;
import 'dart:async';

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
    
    // Показываем индикатор загрузки
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Добавление категории...'),
          duration: Duration(seconds: 2),
        ),
      );
    }
    
    // Копируем имя категории
    final trimmedName = categoryName.trim();
    
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
          const SnackBar(
            content: Text('Категория успешно добавлена'),
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
  
  // Показываем диалог для добавления новой категории
  void _showAddCategoryDialog() {
    // Создаем контроллер здесь
    final categoryController = TextEditingController();
    
    // Используем AlertDialog вместо кастомного диалога
    showDialog(
      context: context,
      builder: (dialogContext) {
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
        return data;
      }).toList();
      
      if (!mounted) return;
      
      setState(() {
        _products = products;
        _filteredProducts = List.from(products); // Инициализируем отфильтрованный список
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
    // Очищаем поля формы перед открытием
    _nameController.clear();
    _priceController.clear();
    _descriptionController.clear();
    _imageUrlController.clear();
    _ingredientsController.clear();
    _discountController.clear();
    _weightController.clear();
    _selectedCategory = null;
    _isDescriptionExpanded = false;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Важно для корректной работы с клавиатурой
      backgroundColor: const Color(0xFFEADAC5), // Бежевый фон как на скриншоте
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
                    
                    // Заголовок продукта (сделан редактируемым с подсказкой)
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
                              // Поле для изображения (с уменьшенной шириной)
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
                                          ? Image.network(
                                              _imageUrlController.text,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return const Center(
                                                  child: Icon(
                                                    Icons.add_photo_alternate,
                                                    color: Colors.white,
                                                    size: 60,
                                                  ),
                                                );
                                              },
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
                                          maxLines: null, // Автоматическое растягивание
                                          minLines: 3, // Минимальная высота
                                          style: const TextStyle(fontSize: 15),
                                          onChanged: (text) {
                                            // Обновляем состояние для перерисовки AnimatedSize
                                            modalSetState(() {});
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Поля ввода цены и скидки с улучшенным дизайном
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
                              
                              // Поля состава и граммовки с улучшенным дизайном
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
                              
                              // Выбор категории (комбо-бокс с улучшенной анимацией)
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
                              
                              // Кнопка добавления товара
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
                                      // Сначала закрываем модальное окно, чтобы избежать зависания UI
                                      Navigator.pop(context);
                                      
                                      // Затем добавляем товар без ожидания завершения
                                      _addProductWithoutWaiting();
                                    },
                                    borderRadius: BorderRadius.circular(12),
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
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
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
  void _addProductWithoutWaiting() {
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
    
    // Скрываем клавиатуру перед любыми UI операциями
    FocusScope.of(context).unfocus();
    
    // Закрываем диалог добавления товара до начала операции с Firestore
    Navigator.pop(context);
    
    // Копируем данные из контроллеров, чтобы избежать проблем с доступом к данным
    final name = _nameController.text.trim();
    final priceText = _priceController.text.trim();
    final description = _descriptionController.text.trim();
    final imageUrl = _imageUrlController.text.trim();
    final ingredients = _ingredientsController.text.trim();
    final discount = _discountController.text.trim();
    final weight = _weightController.text.trim();
    final category = _selectedCategory;
    
    // Очищаем контроллеры сразу после копирования данных
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
          content: Text('Добавление товара...'),
          duration: Duration(seconds: 2),
        ),
      );
    }
    
    // Создаем данные для добавления
    final productData = {
      'name': name,
      'price': double.tryParse(priceText) ?? 0,
      'description': description,
      'imageUrl': imageUrl,
      'ingredients': ingredients,
      'category': category,
      'discount': double.tryParse(discount) ?? 0,
      'weight': weight,
      'createdAt': FieldValue.serverTimestamp(),
      'inStock': true,
    };
    
    // Используем Future.delayed чтобы дать UI время обновиться перед началом операций с Firestore
    Future.delayed(const Duration(milliseconds: 100), () {
      // Используем Future для обработки Firestore операции асинхронно
      Future<void> addProductToFirestore() async {
        try {
          // Устанавливаем таймаут
          await _firestore.collection('products').add(productData)
              .timeout(const Duration(seconds: 15));
          
          // Обновляем список товаров
          if (mounted) {
            _loadProducts();
            
            // Показываем сообщение об успешном добавлении
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Товар успешно добавлен'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } on TimeoutException catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Превышено время ожидания при добавлении товара. Проверьте соединение с интернетом.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } catch (error) {
          // Показываем сообщение об ошибке
          print('Ошибка при добавлении товара: $error');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Ошибка при добавлении товара: ${error.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
      
      // Запускаем асинхронную операцию
      addProductToFirestore();
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddProductForm();
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Поле поиска
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              height: 50,
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
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Поиск товаров...',
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          
          // Горизонтальный скролл категорий
          SizedBox(
            height: 50,
            child: _isCategoriesLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _categories.length + 2, // +1 для кнопки "Все" и +1 для кнопки добавления
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // Кнопка "Все"
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FilterChip(
                          label: const Text('Все'),
                          selected: _selectedCategoryFilter == null,
                          onSelected: (_) => _filterByCategory(null),
                          backgroundColor: Colors.white,
                          selectedColor: AppColors.primary.withOpacity(0.2),
                          checkmarkColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: _selectedCategoryFilter == null 
                              ? AppColors.primary 
                              : Colors.black87,
                            fontWeight: _selectedCategoryFilter == null 
                              ? FontWeight.bold 
                              : FontWeight.normal,
                          ),
                        ),
                      );
                    }
                    
                    if (index == _categories.length + 1) {
                      // Кнопка добавления новой категории
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ActionChip(
                          avatar: const Icon(Icons.add, size: 18, color: AppColors.primary),
                          label: const Text('Добавить'),
                          backgroundColor: Colors.white,
                          onPressed: _showAddCategoryDialog,
                          labelStyle: const TextStyle(color: AppColors.primary),
                        ),
                      );
                    }
                    
                    final categoryData = _categories[index - 1];
                    final category = categoryData['name'] as String;
                    final isSelected = _selectedCategoryFilter == category;
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        label: Text(category),
                        selected: isSelected,
                        onSelected: (_) => _filterByCategory(category),
                        backgroundColor: Colors.white,
                        selectedColor: AppColors.primary.withOpacity(0.2),
                        checkmarkColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.primary : Colors.black87,
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
              ? const Center(child: CircularProgressIndicator())
              : _filteredProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Товары отсутствуют',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _loadProducts,
                          child: const Text('Обновить'),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      await _loadProducts();
                      await _loadCategories();
                    },
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        final imageUrl = product['imageUrl'] as String? ?? '';
                        final name = product['name'] as String? ?? 'Без названия';
                        final price = product['price'] ?? 0;
                        final inStock = product['inStock'] ?? false;

                        return Card(
                          clipBehavior: Clip.antiAlias,
                          elevation: 2,
                          child: InkWell(
                            onTap: () {
                              // TODO: Реализовать редактирование товара
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Изображение товара
                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    color: Colors.grey[200],
                                    child: imageUrl.isNotEmpty
                                        ? Image.network(
                                            imageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return const Center(
                                                child: Icon(
                                                  Icons.image_not_supported_outlined,
                                                  color: Colors.grey,
                                                  size: 40,
                                                ),
                                              );
                                            },
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
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$price ₽',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            width: 10,
                                            height: 10,
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
                                    ],
                                  ),
                                ),
                              ],
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