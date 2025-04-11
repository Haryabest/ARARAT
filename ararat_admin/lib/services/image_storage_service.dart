import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Сервис для хранения изображений в локальном файловом хранилище устройства
class ImageStorageService {
  // Синглтон
  static final ImageStorageService _instance = ImageStorageService._internal();
  factory ImageStorageService() => _instance;
  ImageStorageService._internal();
  
  // Кэш изображений в памяти (для быстрого доступа)
  final Map<String, Uint8List> _imageCache = {};
  
  // Получение хеша email для использования в качестве ключа
  String _getEmailHash(String email) {
    return md5.convert(utf8.encode(email.toLowerCase())).toString();
  }
  
  // Получение директории для хранения изображений
  Future<Directory> _getImageDirectory() async {
    try {
      // Используем системную временную директорию, которая всегда доступна для записи
      final tempDir = Directory.systemTemp;
      
      // Проверяем доступность директории
      if (await tempDir.exists()) {
        print('Используем временную директорию: ${tempDir.path}');
        return tempDir;
      } else {
        throw 'Временная директория не существует';
      }
    } catch (e) {
      print('Ошибка при получении директории: $e');
      
      // Если не удалось получить директорию, используем текущую директорию приложения
      // и создаем дополнительную папку только для хранения имени файла (без создания реальной папки)
      final fallbackDir = Directory('');
      print('Используем fallback директорию: ${fallbackDir.path}');
      return fallbackDir;
    }
  }
  
  // Получение пути к файлу изображения по email
  Future<String> _getImagePath(String email) async {
    try {
      final String key = _getEmailHash(email);
      final Directory imageDir = await _getImageDirectory();
      
      // Формируем путь к файлу
      final String path = '${imageDir.path}/profile_$key.jpg';
      print('Сформирован путь к изображению: $path');
      return path;
    } catch (e) {
      print('Ошибка при получении пути к изображению: $e');
      
      // В случае ошибки возвращаем путь в текущей директории
      final String key = _getEmailHash(email);
      return 'profile_$key.jpg';
    }
  }
  
  // Сохранение изображения в локальное хранилище
  Future<bool> saveImage(File imageFile, String email) async {
    try {
      // Читаем файл как байты
      final Uint8List bytes = await imageFile.readAsBytes();
      
      // Сохраняем в кэш для быстрого доступа
      final String key = _getEmailHash(email);
      _imageCache[key] = bytes;
      print('Изображение сохранено в кэш');
      
      try {
        // Получаем путь для сохранения и пробуем сохранить файл
        final String imagePath = await _getImagePath(email);
        final File file = File(imagePath);
        await file.writeAsBytes(bytes);
        
        print('Изображение сохранено на диск: $imagePath');
        print('Размер изображения: ${bytes.length} байт');
        
        // Проверяем, что файл был успешно создан
        bool fileExists = await file.exists();
        print('Файл существует после сохранения: $fileExists');
        
        if (fileExists) {
          return true;
        }
      } catch (fileError) {
        print('Ошибка при сохранении файла на диск: $fileError');
        // Здесь не бросаем исключение, так как изображение уже в кэше
      }
      
      // Если не удалось сохранить на диск, но оно есть в кэше - считаем успешным сохранением
      return true;
    } catch (e) {
      print('Ошибка сохранения изображения: $e');
      return false;
    }
  }
  
  // Получение изображения из локального хранилища
  Future<File?> getImage(String email) async {
    try {
      final String key = _getEmailHash(email);
      
      // Сначала проверяем кэш в памяти
      if (_imageCache.containsKey(key)) {
        print('Изображение найдено в кэше памяти');
        
        try {
          // Создаем временный файл из кэша
          final tempPath = '${Directory.systemTemp.path}/temp_profile_$key.jpg';
          final File tempFile = File(tempPath);
          await tempFile.writeAsBytes(_imageCache[key]!);
          print('Создан временный файл из кэша: $tempPath');
          return tempFile;
        } catch (tempError) {
          print('Ошибка при создании временного файла: $tempError');
        }
      }
      
      // Если в кэше нет или не удалось создать временный файл, пробуем загрузить с диска
      try {
        final String imagePath = await _getImagePath(email);
        final File file = File(imagePath);
        
        print('Проверка наличия файла изображения: $imagePath');
        
        // Проверяем существование файла
        if (await file.exists()) {
          // Если файл существует, загружаем его содержимое в кэш
          final bytes = await file.readAsBytes();
          _imageCache[key] = bytes;
          
          print('Изображение загружено с диска в кэш, размер: ${bytes.length} байт');
          return file;
        } else {
          print('Файл изображения не найден на диске');
        }
      } catch (fileError) {
        print('Ошибка при загрузке изображения с диска: $fileError');
      }
      
      print('Изображение не найдено ни в кэше, ни на диске');
      return null;
    } catch (e) {
      print('Общая ошибка загрузки изображения: $e');
      return null;
    }
  }
  
  // Проверка наличия изображения в хранилище
  Future<bool> hasImage(String email) async {
    try {
      final String key = _getEmailHash(email);
      
      // Проверяем кэш в памяти (быстрая проверка)
      if (_imageCache.containsKey(key)) {
        print('Изображение найдено в кэше памяти');
        return true;
      }
      
      // Проверяем файл на диске
      try {
        final String imagePath = await _getImagePath(email);
        final File file = File(imagePath);
        final bool exists = await file.exists();
        
        if (exists) {
          print('Изображение найдено на диске');
          // Загружаем в кэш для дальнейшего использования
          _imageCache[key] = await file.readAsBytes();
          return true;
        }
      } catch (fileError) {
        print('Ошибка при проверке файла на диске: $fileError');
      }
      
      print('Изображение не найдено ни в кэше, ни на диске');
      return false;
    } catch (e) {
      print('Ошибка проверки наличия изображения: $e');
      return false;
    }
  }
  
  // Удаление изображения полностью (из кэша и с диска)
  Future<bool> removeImage(String email) async {
    try {
      final String key = _getEmailHash(email);
      
      // Удаляем из кэша
      if (_imageCache.containsKey(key)) {
        _imageCache.remove(key);
        print('Изображение удалено из кэша');
      }
      
      // Удаляем файл с диска
      try {
        final String imagePath = await _getImagePath(email);
        final File file = File(imagePath);
        
        if (await file.exists()) {
          await file.delete();
          print('Изображение удалено с диска');
        }
      } catch (fileError) {
        print('Ошибка при удалении файла с диска: $fileError');
        // Не прерываем операцию, так как кэш уже очищен
      }
      
      return true;
    } catch (e) {
      print('Ошибка удаления изображения: $e');
      return false;
    }
  }
  
  // Очистка только из кэша при выходе из аккаунта (сохраняем на диске)
  Future<void> clearCurrentUserImage(String email) async {
    try {
      final String key = _getEmailHash(email);
      
      // Удаляем только из кэша, оставляя на диске
      if (_imageCache.containsKey(key)) {
        _imageCache.remove(key);
        print('Изображение удалено из кэша при выходе из аккаунта');
      }
    } catch (e) {
      print('Ошибка очистки изображения: $e');
    }
  }
} 