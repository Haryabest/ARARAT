import 'package:cloud_firestore/cloud_firestore.dart';

class SearchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Коллекция для хранения поисковых запросов
  final String _collection = 'search_queries';

  // Сохраняет поисковый запрос в Firestore
  Future<void> saveQuery(String query) async {
    if (query.trim().isEmpty) return;
    
    try {
      // Проверяем, существует ли такой запрос
      final queryRef = _firestore.collection(_collection).doc(query.toLowerCase());
      final doc = await queryRef.get();
      
      if (doc.exists) {
        // Если запрос уже существует, увеличиваем счетчик
        await queryRef.update({
          'count': FieldValue.increment(1),
          'lastSearched': FieldValue.serverTimestamp(),
        });
      } else {
        // Если запрос новый, создаем документ
        await queryRef.set({
          'query': query.toLowerCase(),
          'count': 1,
          'firstSearched': FieldValue.serverTimestamp(),
          'lastSearched': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Ошибка при сохранении поискового запроса: $e');
    }
  }

  // Получает список популярных запросов
  Future<List<String>> getPopularQueries({int limit = 5}) async {
    try {
      // Запрашиваем топ запросов, отсортированных по количеству
      final querySnapshot = await _firestore
          .collection(_collection)
          .orderBy('count', descending: true)
          .limit(limit)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return [];
      }

      // Преобразуем результаты в список строк
      return querySnapshot.docs.map((doc) {
        // Преобразуем первую букву в верхний регистр для лучшего отображения
        String query = doc['query'] as String;
        if (query.isNotEmpty) {
          query = query[0].toUpperCase() + query.substring(1);
        }
        return query;
      }).toList();
    } catch (e) {
      print('Ошибка при получении популярных запросов: $e');
      return [];
    }
  }
  
  // Очищает историю поисковых запросов (для тестирования или по запросу админа)
  Future<void> clearSearchHistory() async {
    try {
      final batch = _firestore.batch();
      final querySnapshot = await _firestore.collection(_collection).get();
      
      for (var doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
    } catch (e) {
      print('Ошибка при очистке истории поисковых запросов: $e');
    }
  }
} 