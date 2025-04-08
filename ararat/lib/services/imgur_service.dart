import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ImgurService {
  // Замените на ваш Client ID от Imgur API
  // Получить можно на https://api.imgur.com/oauth2/addclient
  static const String _clientId = 'YOUR_IMGUR_CLIENT_ID';
  static const String _apiUrl = 'https://api.imgur.com/3/image';

  // Загрузка изображения на Imgur и получение ссылки
  static Future<String> uploadImage(File imageFile) async {
    try {
      // Читаем файл как байты
      List<int> imageBytes = await imageFile.readAsBytes();
      
      // Кодируем в base64
      String base64Image = base64Encode(imageBytes);
      
      // Создаем запрос
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Client-ID $_clientId',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'image': base64Image,
          'type': 'base64',
        }),
      );
      
      // Проверяем ответ
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data']['link']; // Возвращаем ссылку на изображение
      } else {
        throw Exception('Ошибка загрузки изображения: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
  
  // Загрузка нескольких изображений
  static Future<List<String>> uploadImages(List<File> imageFiles) async {
    List<String> imageUrls = [];
    
    for (var file in imageFiles) {
      try {
        String url = await uploadImage(file);
        imageUrls.add(url);
      } catch (e) {
        // Продолжаем с остальными изображениями
      }
    }
    
    return imageUrls;
  }
} 