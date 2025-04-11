import 'package:cloud_firestore/cloud_firestore.dart';

/// Простая модель адреса для обратной совместимости и миграции
class Address {
  final String id;
  final String type;
  final String title;
  final String city;
  final String street;
  final String house;
  final String apartment;

  Address({
    required this.id,
    required this.type,
    this.title = '',
    required this.city,
    required this.street,
    required this.house,
    this.apartment = '',
  });
}

/// Расширенная модель адреса с дополнительными полями и функциональностью
class AddressModel {
  final String id;          // Уникальный идентификатор
  final String type;        // Тип адреса (Домашний, Рабочий, Другой)
  final String title;       // Название адреса
  final String city;        // Город
  final String street;      // Улица
  final String house;       // Номер дома
  final String apartment;   // Квартира/офис
  final String entrance;    // Подъезд
  final String floor;       // Этаж
  final String intercom;    // Домофон
  final bool isDefault;     // Флаг "По умолчанию"
  final DateTime? createdAt; // Дата создания
  final DateTime? updatedAt; // Дата обновления

  /// Конструктор
  AddressModel({
    required this.id,
    required this.type,
    this.title = '',
    required this.city,
    required this.street,
    required this.house,
    this.apartment = '',
    this.entrance = '',
    this.floor = '',
    this.intercom = '',
    this.isDefault = false,
    this.createdAt,
    this.updatedAt,
  });

  /// Полный адрес в виде строки
  String get fullAddress {
    return [
      city,
      street,
      'д. $house',
      if (apartment.isNotEmpty) '${type == "Рабочий" ? "офис" : "кв."} $apartment',
    ].join(', ');
  }

  /// Создание модели из карты данных Firestore
  factory AddressModel.fromMap(Map<String, dynamic> map, String id) {
    return AddressModel(
      id: id,
      type: map['type'] ?? 'Другой',
      title: map['title'] ?? '',
      city: map['city'] ?? '',
      street: map['street'] ?? '',
      house: map['house'] ?? '',
      apartment: map['apartment'] ?? '',
      entrance: map['entrance'] ?? '',
      floor: map['floor'] ?? '',
      intercom: map['intercom'] ?? '',
      isDefault: map['isDefault'] ?? false,
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate() 
          : null,
      updatedAt: map['updatedAt'] != null 
          ? (map['updatedAt'] as Timestamp).toDate() 
          : null,
    );
  }

  /// Преобразование модели в карту данных для Firestore
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'title': title,
      'city': city,
      'street': street,
      'house': house,
      'apartment': apartment,
      'entrance': entrance,
      'floor': floor,
      'intercom': intercom,
      'isDefault': isDefault,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Создание копии модели с измененными полями
  AddressModel copyWith({
    String? id,
    String? type,
    String? title,
    String? city,
    String? street,
    String? house,
    String? apartment,
    String? entrance,
    String? floor,
    String? intercom,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AddressModel(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      city: city ?? this.city,
      street: street ?? this.street,
      house: house ?? this.house,
      apartment: apartment ?? this.apartment,
      entrance: entrance ?? this.entrance,
      floor: floor ?? this.floor,
      intercom: intercom ?? this.intercom,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Вспомогательная функция для конвертации списка адресов из Firestore
List<AddressModel> addressesFromFirestore(List<dynamic> data) {
  return data.map((item) => AddressModel.fromMap(item as Map<String, dynamic>, item['id'] ?? '')).toList();
} 