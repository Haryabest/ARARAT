import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ararat/models/product.dart';

class ProductService {
  final CollectionReference _productsCollection =
      FirebaseFirestore.instance.collection('products');
  final CollectionReference _categoriesCollection =
      FirebaseFirestore.instance.collection('categories');

  // Получить все продукты
  Stream<List<Product>> getProducts({String? category}) {
    Query query = _productsCollection;
    
    if (category != null && category.isNotEmpty) {
      query = query.where('category', isEqualTo: category);
    }
    
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Product.fromMap(data, doc.id);
      }).toList();
    });
  }

  // Получить все категории
  Stream<List<String>> getCategories() {
    return _categoriesCollection.snapshots().map((snapshot) {
      List<String> categories = ['Все']; // Добавляем категорию "Все" в начало списка
      
      categories.addAll(snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['name'] as String;
      }));
      
      return categories;
    });
  }

  // Добавить новый продукт
  Future<void> addProduct(Product product) async {
    try {
      // Создаем Map с данными продукта
      Map<String, dynamic> productData = product.toMap();
      
      // Добавляем продукт в Firestore
      await _productsCollection.add(productData);
    } catch (e) {
      rethrow;
    }
  }

  // Удалить продукт
  Future<void> deleteProduct(String productId) async {
    try {
      await _productsCollection.doc(productId).delete();
    } catch (e) {
      rethrow;
    }
  }

  // Обновить продукт
  Future<void> updateProduct(Product product, List<String>? newImageUrls) async {
    try {
      Map<String, dynamic> productData = product.toMap();
      
      // Если есть новые ссылки на изображения, обновляем их
      if (newImageUrls != null && newImageUrls.isNotEmpty) {
        productData['imageUrls'] = newImageUrls;
      }
      
      await _productsCollection.doc(product.id).update(productData);
    } catch (e) {
      rethrow;
    }
  }

  // Метод для обновления количества продуктов без полной загрузки
  Future<List<Product>> refreshQuantities() async {
    try {
      List<Product> updatedProducts = [];
      
      // Получаем только обновленные товары (с измененным количеством)
      final querySnapshot = await _productsCollection
          .orderBy('lastUpdatedAt', descending: true)
          .limit(20) // Ограничиваем запрос 20 последними обновленными товарами
          .get();
      
      for (var doc in querySnapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final product = Product.fromMap(data, doc.id);
          updatedProducts.add(product);
        } catch (e) {
          print('Ошибка при обработке обновленного товара: $e');
        }
      }
      
      print('Обновлено количество для ${updatedProducts.length} товаров');
      return updatedProducts;
    } catch (e) {
      print('Ошибка при обновлении количества товаров: $e');
      return [];
    }
  }

  // Метод для прямого получения продуктов (без стрима) для принудительного обновления
  Future<List<Product>> getProductsDirectly({String? category}) async {
    try {
      Query query = _productsCollection;
      
      if (category != null && category.isNotEmpty) {
        query = query.where('category', isEqualTo: category);
      }
      
      final querySnapshot = await query.get();
      List<Product> products = [];
      
      for (var doc in querySnapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          products.add(Product.fromMap(data, doc.id));
        } catch (e) {
          print('Ошибка при обработке продукта: $e');
        }
      }
      
      print('Напрямую загружено ${products.length} продуктов');
      return products;
    } catch (e) {
      print('Ошибка при прямой загрузке продуктов: $e');
      return [];
    }
  }
} 