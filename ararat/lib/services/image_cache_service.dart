import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Сервис для предзагрузки и кэширования изображений товаров
class ImageCacheService {
  // Синглтон
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();
  
  // Флаг инициализации
  bool _isInitialized = false;
  
  // Список URL изображений для предзагрузки
  final List<String> _preloadedUrls = [];
  
  // Метод получения статуса инициализации
  bool get isInitialized => _isInitialized;
  
  // Метод инициализации сервиса (вызывать при запуске приложения)
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Получаем только популярные товары или те, которые отображаются на главном экране
      final QuerySnapshot productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .orderBy('createdAt', descending: true)
          .limit(20) // Ограничиваем количество предзагружаемых элементов
          .get();
      
      // Извлекаем URL изображений
      for (var doc in productsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final imageUrl = data['imageUrl'] as String?;
        
        if (imageUrl != null && imageUrl.isNotEmpty) {
          _preloadedUrls.add(imageUrl);
          
          // Запускаем предзагрузку изображения в кэш
          _preloadImage(imageUrl);
        }
      }
      
      _isInitialized = true;
      debugPrint('ImageCacheService: предзагружено ${_preloadedUrls.length} изображений');
    } catch (e) {
      debugPrint('ImageCacheService: ошибка инициализации - $e');
    }
  }
  
  // Метод для предзагрузки изображения
  Future<void> _preloadImage(String imageUrl) async {
    try {
      // Создаем провайдер и загружаем изображение
      final provider = CachedNetworkImageProvider(imageUrl);
      
      // Создаем слушателя для обработки завершения загрузки
      final completer = Completer<void>();
      
      // Запускаем загрузку изображения
      final imageStream = provider.resolve(ImageConfiguration.empty);
      final listener = ImageStreamListener(
        (_, __) {
          if (!completer.isCompleted) {
            completer.complete();
          }
          debugPrint('ImageCacheService: изображение $imageUrl предзагружено');
        },
        onError: (error, stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
          debugPrint('ImageCacheService: ошибка предзагрузки $imageUrl - $error');
        },
      );
      
      // Добавляем слушателя
      imageStream.addListener(listener);
      
      // Устанавливаем таймаут
      return completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          imageStream.removeListener(listener);
          debugPrint('ImageCacheService: превышено время загрузки для $imageUrl');
        },
      );
    } catch (e) {
      debugPrint('ImageCacheService: ошибка предзагрузки $imageUrl - $e');
    }
  }
  
  // Метод для принудительной предзагрузки конкретного URL
  Future<void> preloadImage(String imageUrl) async {
    if (imageUrl.isEmpty) return;
    
    // Добавляем URL в список предзагруженных, если его там еще нет
    if (!_preloadedUrls.contains(imageUrl)) {
      _preloadedUrls.add(imageUrl);
      await _preloadImage(imageUrl);
    }
  }
  
  // Метод для проверки, был ли URL предзагружен
  bool isPreloaded(String imageUrl) {
    return _preloadedUrls.contains(imageUrl);
  }
  
  // Метод для очистки кэша (например, при выходе из приложения)
  Future<void> clearCache() async {
    try {
      await CachedNetworkImage.evictFromCache('');
      _preloadedUrls.clear();
      debugPrint('ImageCacheService: кэш очищен');
    } catch (e) {
      debugPrint('ImageCacheService: ошибка очистки кэша - $e');
    }
  }
} 