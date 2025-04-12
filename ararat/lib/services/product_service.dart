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
} 