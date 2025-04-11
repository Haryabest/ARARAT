import 'dart:io';
import 'package:ararat/services/image_storage_service.dart';

class ImageService {
  final ImageStorageService _storageService = ImageStorageService();

  // Получение изображения по электронной почте пользователя
  Future<File?> getImage(String email) async {
    return await _storageService.getImage(email);
  }

  // Сохранение изображения профиля
  Future<bool> saveImage(File imageFile, String email) async {
    return await _storageService.saveImage(imageFile, email);
  }

  // Очистка изображения пользователя
  Future<void> clearCurrentUserImage(String email) async {
    await _storageService.removeImage(email);
  }
} 