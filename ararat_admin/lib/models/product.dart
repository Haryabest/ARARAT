
class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final List<String> imageUrls; // Теперь это URL-адреса изображений
  final bool available;
  final Map<String, dynamic>? additionalInfo;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.imageUrls,
    this.available = true,
    this.additionalInfo,
  });

  // Создание Product из Map (для Firestore)
  factory Product.fromMap(Map<String, dynamic> map, String id) {
    return Product(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      category: map['category'] ?? '',
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      available: map['available'] ?? true,
      additionalInfo: map['additionalInfo'],
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
      'available': available,
      'additionalInfo': additionalInfo,
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
    bool? available,
    Map<String, dynamic>? additionalInfo,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      imageUrls: imageUrls ?? this.imageUrls,
      available: available ?? this.available,
      additionalInfo: additionalInfo ?? this.additionalInfo,
    );
  }
} 