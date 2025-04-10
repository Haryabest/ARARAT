import 'package:flutter/material.dart';
import 'package:ararat/screens/main/tabs/other_profile_tabs/orders_tab.dart';
import 'package:ararat/screens/main/tabs/other_profile_tabs/delivery_addresses_tab.dart';
import 'package:ararat/screens/main/tabs/other_profile_tabs/payment_methods_tab.dart';
import 'package:ararat/screens/main/tabs/other_profile_tabs/notifications_tab.dart';
import 'package:ararat/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:ararat/services/image_storage_service.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final AuthService _authService = AuthService();
  final ImageStorageService _imageService = ImageStorageService();
  String _displayName = '';
  String _email = '';
  bool _isLoading = true;
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isUserDataLoading = false;
  bool _isPasswordHidden = true;
  bool _isConfirmPasswordHidden = true;
  File? _imageFile;
  bool _isUploadingImage = false;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  Future<void> _loadUserData() async {
    if (!mounted) return; // Проверяем, находится ли виджет в дереве
    
    setState(() {
      _isLoading = true;
    });

    User? user = _authService.currentUser;
    if (user != null) {
      // Обновим данные с сервера для получения актуальной информации
      await user.reload();
      user = _authService.currentUser; // Получаем обновленного пользователя

      // Получаем базовые данные из Firebase Auth
      String displayName = user?.displayName ?? 'Пользователь';
      String email = user?.email ?? 'Нет email';
      
      print('Загрузка данных пользователя: $displayName, $email');
      
      // Пробуем получить дополнительные данные из Firestore
      Map<String, dynamic>? userData = await _authService.getUserData();
      if (userData != null) {
        // Если в Firestore есть данные, используем их
        if (userData['displayName'] != null) {
          displayName = userData['displayName'];
        }
      }

      // Загружаем изображение профиля из нашего сервиса
      File? profileImage = await _imageService.getImage(email);
      
      print('Изображение профиля загружено: ${profileImage != null}');

      if (!mounted) return; // Проверяем снова после долгой операции
      
      setState(() {
        _displayName = displayName;
        _email = email;
        _imageFile = profileImage;
        _isLoading = false;
      });
    } else {
      if (!mounted) return; // Защита от вызова setState на размонтированном виджете
      
      setState(() {
        _displayName = 'Не авторизован';
        _email = '';
        _imageFile = null;
        _isLoading = false;
      });
    }
  }
  
  Future<void> _pickImage() async {
    if (!mounted) return;
    
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery, 
        maxWidth: 800, // Ограничиваем размер для экономии памяти
        maxHeight: 800,
        imageQuality: 80, // Немного сжимаем для экономии памяти
      );
      
      if (image != null) {
        if (!mounted) return; // Проверка после асинхронной операции
        
        setState(() {
          _imageFile = File(image.path);
          _isUploadingImage = true;
        });
        
        await _saveImageToLocalStorage();
      }
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при выборе изображения: ${e.toString()}')),
      );
    }
  }
  
  // Сохранение изображения в локальное хранилище
  Future<void> _saveImageToLocalStorage() async {
    try {
      if (_imageFile == null || _email.isEmpty) {
        if (!mounted) return; // Проверка перед обновлением состояния
        
        setState(() {
          _isUploadingImage = false;
        });
        return;
      }
      
      // Сохраняем изображение в наш сервис
      bool success = await _imageService.saveImage(_imageFile!, _email);
      
      if (!mounted) return; // Проверка после асинхронной операции
      
      if (success) {
        // Перезагружаем файл, чтобы убедиться, что он сохранен правильно
        final savedImage = await _imageService.getImage(_email);
        
        if (!mounted) return; // Повторная проверка после второй асинхронной операции
        
        if (savedImage != null) {
          setState(() {
            _imageFile = savedImage;
            _isUploadingImage = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Фото профиля обновлено')),
          );
        } else {
          throw 'Не удалось проверить сохраненное изображение';
        }
      } else {
        throw 'Не удалось сохранить изображение';
      }
    } catch (e) {
      if (!mounted) return; // Проверка перед обновлением состояния в случае ошибки
      
      setState(() {
        _isUploadingImage = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при сохранении изображения: ${e.toString()}')),
      );
    }
  }
  
  // Сохранение данных пользователя
  Future<void> _saveUserData() async {
    // Убираем фокус и закрываем клавиатуру
    FocusScope.of(context).unfocus();
    
    // Проверяем, чтобы не запускать несколько запросов одновременно
    if (_isLoading || !mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = '';
    });
    
    try {
      // Проверка имени пользователя
      if (_loginController.text.trim().isEmpty) {
        setState(() {
          _error = 'Имя пользователя не может быть пустым';
          _isLoading = false;
        });
        return;
      }
      
      // Проверка на кириллицу в имени
      if (_containsRussianCharacters(_loginController.text.trim())) {
        setState(() {
          _error = 'Имя пользователя не может содержать кириллицу';
          _isLoading = false;
        });
        return;
      }
      
      // Проверка паролей если они введены
      if (_passwordController.text.isNotEmpty) {
        // Проверка минимальной длины пароля
        if (_passwordController.text.length < 6) {
          setState(() {
            _error = 'Пароль должен содержать минимум 6 символов';
            _isLoading = false;
          });
          return;
        }
        
        // Проверка совпадения паролей
        if (_passwordController.text != _confirmPasswordController.text) {
          setState(() {
            _error = 'Пароли не совпадают';
            _isLoading = false;
          });
          return;
        }
      }
      
      // Вызываем обновление данных профиля
      final bool success = await _updateProfileData();
      
      if (success) {
        // Закрываем диалог при успешном обновлении
        Navigator.of(context).pop();
        
        // Очищаем поля паролей после успешного обновления
        _passwordController.clear();
        _confirmPasswordController.clear();
        
        // Показываем уведомление об успехе
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Данные успешно обновлены'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
      
      // После всех асинхронных операций проверяем снова
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_error ?? 'Произошла ошибка'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Обновление данных профиля
  Future<bool> _updateProfileData() async {
    if (!mounted) return false; // Проверка в начале метода
    
    final user = _authService.currentUser;
    if (user == null) {
      throw 'Пользователь не авторизован';
    }
    
    // Проверяем, нужно ли обновлять displayName
    final String newUsername = _loginController.text.trim();
    bool updated = false;
    
    if (user.displayName != newUsername) {
      try {
        // Обновляем имя пользователя
        await _authService.updateUserData({
          'displayName': newUsername,
        });
        
        // Сразу обновляем имя в UI
        if (!mounted) return false; // Проверка перед вызовом setState
        
        setState(() {
          _displayName = newUsername;
        });
        
        updated = true;
        print('Логин успешно обновлен');
      } catch (e) {
        print('Ошибка при обновлении логина: $e');
        throw 'Не удалось обновить логин: $e';
      }
    }
    
    // Проверяем, нужно ли обновлять пароль
    if (_passwordController.text.isNotEmpty) {
      try {
        await _authService.updatePassword(_passwordController.text);
        updated = true;
        print('Пароль успешно обновлен');
      } catch (e) {
        print('Ошибка при обновлении пароля: $e');
        throw 'Не удалось обновить пароль: $e';
      }
    }
    
    // Обновляем данные из Firebase для получения актуальной информации
    if (updated && mounted) {
      await _loadUserData();
    }
    
    return updated;
  }
  
  // Проверка на русские символы
  bool _containsRussianCharacters(String text) {
    return RegExp(r'[а-яА-ЯёЁ]').hasMatch(text);
  }
  
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF8F2E9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            'Выход из аккаунта',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF50321B),
            ),
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'Вы уверены, что хотите выйти из своего аккаунта?',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: Color(0xFF50321B),
            ),
            textAlign: TextAlign.center,
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF50321B),
                  ),
                  child: const Text(
                    'Отмена',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF50321B),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Сначала закрываем диалог
                    Navigator.pop(context);
                    // Затем выполняем выход из аккаунта
                    _signOut();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF50321B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Выйти',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _signOut() async {
    if (!mounted) return;
    
    try {
      // Показываем индикатор загрузки
      setState(() {
        _isLoading = true;
      });
      
      // Очищаем изображение текущего пользователя
      if (_email.isNotEmpty) {
        await _imageService.clearCurrentUserImage(_email);
      }
      
      // Выход из аккаунта Firebase
      await _authService.signOut();
      
      // Перенаправляем на экран входа
      if (!mounted) return; // Проверка после асинхронных операций
      
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      // В случае ошибки показываем уведомление
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при выходе из аккаунта: $e'),
          backgroundColor: Colors.red,
        ),
      );
      
      // Восстанавливаем состояние
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFA99378),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Информация о пользователе
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: _isLoading ? null : _pickImage,
                      borderRadius: BorderRadius.circular(35),
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0D5C9),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF50321B),
                            width: 2,
                          ),
                        ),
                        child: _isLoading
                            ? const Center(
                                child: SizedBox(
                                  width: 25,
                                  height: 25,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF50321B),
                                  ),
                                ),
                              )
                            : Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 35,
                                    backgroundColor: Colors.grey[300],
                                    backgroundImage: _isLoading 
                                        ? null 
                                        : _imageFile != null
                                            ? FileImage(_imageFile!)
                                            : null,
                                    child: _isLoading || (_imageFile == null)
                                        ? const Icon(
                                            Icons.person,
                                            size: 35,
                                            color: Colors.grey,
                                          )
                                        : null,
                                  ),
                                  if (_isUploadingImage)
                                    const Center(
                                      child: SizedBox(
                                        width: 25,
                                        height: 25,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF50321B),
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF50321B),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: _isLoading ? null : _showEditUserDataDialog,
                        borderRadius: BorderRadius.circular(8),
                        child: _isLoading
                            ? const Center(
                                child: SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF50321B),
                                  ),
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _displayName,
                                          style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF50321B),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.edit,
                                        size: 16,
                                        color: Color(0xFF50321B),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _email,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xFF838383),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Меню настроек
              _menuItem(
                context,
                Icons.shopping_bag,
                'Мои заказы',
                const OrdersTab(),
              ),
              _menuItem(
                context,
                Icons.location_on,
                'Адреса доставки',
                const DeliveryAddressesTab(),
              ),
              _menuItem(
                context,
                Icons.credit_card,
                'Способы оплаты',
                const PaymentMethodsTab(),
              ),
              _menuItem(
                context,
                Icons.notifications,
                'Уведомления',
                const NotificationsTab(),
              ),
              
              const Spacer(),
              
              // Кнопка выхода
              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _showLogoutDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF50321B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.logout,
                          size: 18,
                        ),
                  label: Text(
                    _isLoading ? 'Выход...' : 'Выйти из аккаунта',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _menuItem(BuildContext context, IconData icon, String title, Widget destination) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          if (title == 'Мои заказы') {
            // Используем именованный маршрут для экрана заказов
            Navigator.of(context).pushNamed('/profile/orders');
          } else {
            // Для других экранов используем обычный MaterialPageRoute
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => destination),
            );
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: const Color(0xFF50321B),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF50321B),
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Color(0xFF838383),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditUserDataDialog() {
    // Инициализируем поля текущими значениями
    _loginController.text = _displayName;
    _passwordController.clear();
    _confirmPasswordController.clear();
    
    // Сбрасываем состояние загрузки и ошибки
    bool isLoading = false;
    String? errorMessage;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFF8F2E9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: const Text(
                'Изменение данных',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF50321B),
                ),
                textAlign: TextAlign.center,
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Показываем сообщение об ошибке, если есть
                    if (errorMessage != null && errorMessage!.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red),
                        ),
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontFamily: 'Inter',
                            fontSize: 12,
                          ),
                        ),
                      ),
                      
                    TextField(
                      controller: _loginController,
                      enabled: !isLoading,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFF50321B),
                      ),
                      decoration: InputDecoration(
                        labelText: 'Логин',
                        labelStyle: const TextStyle(
                          fontFamily: 'Inter',
                          color: Color(0xFF8C7963),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF50321B)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      enabled: !isLoading,
                      obscureText: _isPasswordHidden,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFF50321B),
                      ),
                      decoration: InputDecoration(
                        labelText: 'Новый пароль',
                        labelStyle: const TextStyle(
                          fontFamily: 'Inter',
                          color: Color(0xFF8C7963),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF50321B)),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordHidden 
                                ? Icons.visibility_off 
                                : Icons.visibility,
                            color: const Color(0xFF50321B),
                          ),
                          onPressed: () {
                            setDialogState(() {
                              _isPasswordHidden = !_isPasswordHidden;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _confirmPasswordController,
                      enabled: !isLoading,
                      obscureText: _isConfirmPasswordHidden,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFF50321B),
                      ),
                      decoration: InputDecoration(
                        labelText: 'Подтверждение пароля',
                        labelStyle: const TextStyle(
                          fontFamily: 'Inter',
                          color: Color(0xFF8C7963),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF50321B)),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isConfirmPasswordHidden 
                                ? Icons.visibility_off 
                                : Icons.visibility,
                            color: const Color(0xFF50321B),
                          ),
                          onPressed: () {
                            setDialogState(() {
                              _isConfirmPasswordHidden = !_isConfirmPasswordHidden;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: isLoading ? null : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF50321B),
                      ),
                      child: const Text(
                        'Отмена',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF50321B),
                        ),
                      ),
                    ),
                    isLoading
                        ? const CircularProgressIndicator(
                            color: Color(0xFF50321B),
                            strokeWidth: 3,
                          )
                        : TextButton(
                            onPressed: () async {
                              // Проверки ввода
                              if (_loginController.text.trim().isEmpty) {
                                setDialogState(() {
                                  errorMessage = 'Имя пользователя не может быть пустым';
                                });
                                return;
                              }
                              
                              if (_containsRussianCharacters(_loginController.text.trim())) {
                                setDialogState(() {
                                  errorMessage = 'Имя пользователя не может содержать кириллицу';
                                });
                                return;
                              }
                              
                              if (_passwordController.text.isNotEmpty) {
                                if (_passwordController.text.length < 6) {
                                  setDialogState(() {
                                    errorMessage = 'Пароль должен содержать минимум 6 символов';
                                  });
                                  return;
                                }
                                
                                if (_passwordController.text != _confirmPasswordController.text) {
                                  setDialogState(() {
                                    errorMessage = 'Пароли не совпадают';
                                  });
                                  return;
                                }
                              }
                              
                              // Сохраняем введенные данные в локальные переменные
                              final String newUsername = _loginController.text.trim();
                              final String newPassword = _passwordController.text;
                              
                              // Показываем индикатор загрузки
                              setDialogState(() {
                                isLoading = true;
                                errorMessage = null;
                              });
                              
                              try {
                                // Разделим процесс на обновление имени и пароля
                                bool usernameUpdated = false;
                                bool passwordUpdated = false;
                                String resultMessage = '';
                                
                                // 1. Сначала пробуем обновить имя пользователя
                                if (newUsername != _displayName) {
                                  try {
                                    // Обновляем имя пользователя
                                    await _authService.updateUserData({
                                      'displayName': newUsername,
                                    });
                                    
                                    // Обновляем UI сразу - используем mounted для безопасности
                                    if (!mounted) return;
                                    
                                    setState(() {
                                      _displayName = newUsername;
                                    });
                                    
                                    usernameUpdated = true;
                                    resultMessage = 'Имя пользователя обновлено. ';
                                    print('Имя пользователя обновлено: $newUsername');
                                  } catch (e) {
                                    print('Ошибка при обновлении имени: $e');
                                    if (newPassword.isEmpty) {
                                      throw 'Не удалось обновить имя пользователя: $e';
                                    }
                                  }
                                } else {
                                  usernameUpdated = true; // Не требовалось обновление
                                }
                                
                                // 2. Затем пробуем обновить пароль, если он был введен
                                if (newPassword.isNotEmpty) {
                                  try {
                                    await _authService.updatePassword(newPassword);
                                    passwordUpdated = true;
                                    resultMessage += 'Пароль успешно обновлен.';
                                    print('Пароль успешно обновлен');
                                  } catch (e) {
                                    print('Ошибка при обновлении пароля: $e');
                                    if (!usernameUpdated) {
                                      throw e; // Если имя не обновилось, пробрасываем ошибку
                                    }
                                    resultMessage += 'Ошибка при обновлении пароля: $e';
                                  }
                                }
                                
                                // Если хоть что-то обновилось успешно, закрываем диалог
                                if (usernameUpdated || passwordUpdated) {
                                  // Проверяем, что виджет все еще в дереве перед обновлением данных
                                  if (!mounted) return;
                                  
                                  // Обновляем данные с сервера
                                  await _loadUserData();
                                  
                                  // Проверяем снова после длительной операции
                                  if (!mounted) return;
                                  
                                  // Закрываем диалог
                                  Navigator.pop(context);
                                  
                                  // Показываем сообщение об успехе
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(resultMessage),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } else {
                                  throw 'Не удалось обновить данные';
                                }
                              } catch (e) {
                                // Проверяем, что виджет все еще в дереве перед обновлением диалога
                                if (!mounted) return;
                                
                                // Показываем ошибку в диалоге
                                setDialogState(() {
                                  isLoading = false;
                                  errorMessage = e.toString();
                                });
                              }
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF50321B),
                            ),
                            child: const Text(
                              'Сохранить',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF50321B),
                              ),
                            ),
                          ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
} 