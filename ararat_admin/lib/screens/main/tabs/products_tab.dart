import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ararat/constants/colors.dart';

class ProductsTab extends StatefulWidget {
  const ProductsTab({super.key});

  @override
  State<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<ProductsTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  
  // Контроллеры для полей формы
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _ingredientsController = TextEditingController();
  
  // Текущая выбранная категория
  String? _selectedCategory;
  
  // Список доступных категорий
  final List<String> _categories = ['chevron', 'Гарниры', 'Закуски', 'Напитки', 'Другое'];
  
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
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadProducts();
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
                              GestureDetector(
                                onTap: () {
                                  modalSetState(() {
                                    _isDescriptionExpanded = !_isDescriptionExpanded;
                                  });
                                },
                                child: Container(
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
                              
                              // Упрощенный блок описания без сложных анимаций
                              if (_isDescriptionExpanded)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12.0, bottom: 16.0),
                                  child: Container(
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
                                      controller: _descriptionController,
                                      decoration: const InputDecoration(
                                        hintText: 'Введите описание товара',
                                        contentPadding: EdgeInsets.all(16),
                                        border: InputBorder.none,
                                        hintStyle: TextStyle(color: Colors.grey),
                                      ),
                                      maxLines: 5, // Фиксированное количество строк
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  ),
                                ),
                              if (!_isDescriptionExpanded)
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
                              
                              // Выбор категории (комбо-бокс)
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
                                  child: DropdownButtonHideUnderline(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: DropdownButton<String>(
                                        dropdownColor: const Color(0xFF70422F),
                                        isExpanded: true,
                                        elevation: 8,
                                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 28),
                                        hint: const Text(
                                          'Выберите категорию',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                        ),
                                        value: _selectedCategory,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                        menuMaxHeight: 300,
                                        borderRadius: BorderRadius.circular(12),
                                        onChanged: (String? newValue) {
                                          modalSetState(() {
                                            _selectedCategory = newValue;
                                          });
                                        },
                                        items: _categories.map<DropdownMenuItem<String>>((String value) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                                              decoration: const BoxDecoration(
                                                border: Border(
                                                  bottom: BorderSide(
                                                    color: Colors.white24,
                                                    width: 0.5,
                                                  ),
                                                ),
                                              ),
                                              child: Text(
                                                value,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
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
                                      _addProduct();
                                      Navigator.pop(context);
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
  
  // Метод для добавления товара в Firestore
  Future<void> _addProduct() async {
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
    
    try {
      // Создаем новый документ в коллекции products
      await _firestore.collection('products').add({
        'name': _nameController.text,
        'price': double.tryParse(_priceController.text) ?? 0,
        'description': _descriptionController.text,
        'imageUrl': _imageUrlController.text,
        'ingredients': _ingredientsController.text,
        'category': _selectedCategory,
        'discount': double.tryParse(_discountController.text) ?? 0,
        'weight': _weightController.text,
        'createdAt': FieldValue.serverTimestamp(),
        'inStock': true,
      });
      
      // Обновляем список товаров
      await _loadProducts();
      
      // Показываем сообщение об успешном добавлении
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Товар успешно добавлен'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Показываем сообщение об ошибке
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при добавлении товара: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
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
                  onRefresh: _loadProducts,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      final product = _products[index];
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
    );
  }
} 