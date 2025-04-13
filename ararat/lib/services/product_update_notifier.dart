import 'package:flutter/foundation.dart';

/// Сервис для уведомления об обновлениях товаров
class ProductUpdateNotifier {
  static final ProductUpdateNotifier _instance = ProductUpdateNotifier._internal();

  factory ProductUpdateNotifier() {
    return _instance;
  }

  ProductUpdateNotifier._internal();

  /// Нотификатор для отправки сигнала о необходимости обновления списка товаров
  final ValueNotifier<bool> updateNotifier = ValueNotifier<bool>(false);

  /// Метод для уведомления о необходимости обновления списка товаров
  void notifyProductsUpdated() {
    print('Отправка уведомления об обновлении товаров');
    // Изменяем значение, чтобы активировать слушателей
    updateNotifier.value = !updateNotifier.value;
  }
} 