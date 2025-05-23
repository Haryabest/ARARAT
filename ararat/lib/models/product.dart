class Product {
  final String id;
  final String name;
  final String? description;
  final double price;
  final String category;
  final List<String> imageUrls;
  final String weight;
  final bool available;
  final Map<String, dynamic>? additionalInfo;
  final String? ingredients;
  final int quantity;
  final String unit;
  final List<String> tags;
  final bool special;

  Product({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.category,
    required this.imageUrls,
    required this.weight,
    required this.available,
    this.additionalInfo,
    this.ingredients,
    this.quantity = 0,
    required this.unit,
    required this.tags,
    required this.special,
  });

  // Создание Product из Map (для Firestore)
  factory Product.fromMap(Map<String, dynamic> map, String id) {
    List<String> images = [];
    
    // Проверяем наличие поля imageUrls (список)
    if (map['imageUrls'] != null) {
      images = List<String>.from(map['imageUrls'] ?? []);
    } 
    // Проверяем наличие отдельных полей imageUrl1, imageUrl2, и т.д.
    else {
      // Проверяем все возможные поля с изображениями
      if (map['imageUrl1'] != null && map['imageUrl1'].toString().isNotEmpty) {
        images.add(map['imageUrl1'].toString());
      }
      if (map['imageUrl2'] != null && map['imageUrl2'].toString().isNotEmpty) {
        images.add(map['imageUrl2'].toString());
      }
      if (map['imageUrl3'] != null && map['imageUrl3'].toString().isNotEmpty) {
        images.add(map['imageUrl3'].toString());
      }
      if (map['imageUrl'] != null && map['imageUrl'].toString().isNotEmpty) {
        images.add(map['imageUrl'].toString());
      }
    }

    return Product(
      id: id,
      name: map['name'] ?? '',
      description: map['description'],
      price: (map['price'] is int) ? (map['price'] as int).toDouble() : (map['price'] ?? 0.0).toDouble(),
      category: map['category'] ?? '',
      imageUrls: images,
      weight: map['weight'] ?? '',
      available: map['available'] ?? map['inStock'] ?? true,
      additionalInfo: map['additionalInfo'],
      ingredients: map['ingredients'],
      quantity: map['quantity'] ?? 0,
      unit: map['unit'] ?? '',
      tags: List<String>.from(map['tags'] ?? []),
      special: map['special'] ?? false,
    );
  }

  // Преобразование Product в Map (для Firestore)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'imageUrls': imageUrls,
      'weight': weight,
      'available': available,
      'additionalInfo': additionalInfo,
      'ingredients': ingredients,
      'quantity': quantity,
      'unit': unit,
      'tags': tags,
      'special': special,
    };
  }

  // Создание копии Product с обновленными полями
  Product copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? category,
    List<String>? imageUrls,
    String? weight,
    bool? available,
    Map<String, dynamic>? additionalInfo,
    String? ingredients,
    int? quantity,
    String? unit,
    List<String>? tags,
    bool? special,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      imageUrls: imageUrls ?? this.imageUrls,
      weight: weight ?? this.weight,
      available: available ?? this.available,
      additionalInfo: additionalInfo ?? this.additionalInfo,
      ingredients: ingredients ?? this.ingredients,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      tags: tags ?? this.tags,
      special: special ?? this.special,
    );
  }

  // Метод для обновления количества товара
  Product copyWithUpdatedQuantity(int newQuantity) {
    return Product(
      id: id,
      name: name,
      price: price,
      category: category,
      description: description,
      ingredients: ingredients,
      weight: weight,
      available: available,
      quantity: newQuantity, // Используем новое количество
      imageUrls: List.from(imageUrls),
      unit: unit,
      tags: List.from(tags),
      special: special,
    );
  }
} 