class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final List<String> imageUrls; // Теперь это URL-адреса изображений
  final String weight;
  final bool available;
  final Map<String, dynamic>? additionalInfo;
  final String? ingredients;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.imageUrls,
    required this.weight,
    this.available = true,
    this.additionalInfo,
    this.ingredients,
  });

  // Создание Product из Map (для Firestore)
  factory Product.fromMap(Map<String, dynamic> map, String id) {
    List<String> imageUrls = [];

    // Проверяем, есть ли в map уже готовый список imageUrls
    if (map['imageUrls'] != null && map['imageUrls'] is List) {
      imageUrls = List<String>.from(map['imageUrls']);
    } else {
      // Если нет, собираем из отдельных полей
      if (map['imageUrl'] != null && map['imageUrl'].toString().isNotEmpty) {
        imageUrls.add(map['imageUrl'].toString());
      }
      if (map['imageUrl1'] != null && map['imageUrl1'].toString().isNotEmpty) {
        imageUrls.add(map['imageUrl1'].toString());
      }
      if (map['imageUrl2'] != null && map['imageUrl2'].toString().isNotEmpty) {
        imageUrls.add(map['imageUrl2'].toString());
      }
      if (map['imageUrl3'] != null && map['imageUrl3'].toString().isNotEmpty) {
        imageUrls.add(map['imageUrl3'].toString());
      }
    }

    return Product(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] is int) 
          ? (map['price'] as int).toDouble() 
          : (map['price'] ?? 0.0).toDouble(),
      category: map['category'] ?? '',
      imageUrls: imageUrls,
      weight: map['weight'] ?? '',
      available: map['available'] ?? true,
      additionalInfo: map['additionalInfo'],
      ingredients: map['ingredients'],
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
    );
  }
} 