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
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  Future<void> _loadUserData() async {
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

      setState(() {
        _displayName = displayName;
        _email = email;
        _imageFile = profileImage;
        _isLoading = false;
      });
    } else {
      setState(() {
        _displayName = 'Не авторизован';
        _email = '';
        _imageFile = null;
        _isLoading = false;
      });
    }
  }
  
  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery, 
        maxWidth: 800, // Ограничиваем размер для экономии памяти
        maxHeight: 800,
        imageQuality: 80, // Немного сжимаем для экономии памяти
      );
      
      if (image != null) {
        setState(() {
          _imageFile = File(image.path);
          _isUploadingImage = true;
        });
        
        await _saveImageToLocalStorage();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при выборе изображения: ${e.toString()}')),
      );
    }
  }
  
  // Сохранение изображения в локальное хранилище
  Future<void> _saveImageToLocalStorage() async {
    try {
      if (_imageFile == null || _email.isEmpty) {
        setState(() {
          _isUploadingImage = false;
        });
        return;
      }
      
      // Сохраняем изображение в наш сервис
      bool success = await _imageService.saveImage(_imageFile!, _email);
      
      if (success) {
        // Перезагружаем файл, чтобы убедиться, что он сохранен правильно
        final savedImage = await _imageService.getImage(_email);
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
      setState(() {
        _isUploadingImage = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при сохранении изображения: ${e.toString()}')),
      );
    }
  }
  
  Future<void> _saveUserData() async {
    FocusScope.of(context).unfocus();
    
    setState(() {
      _isUserDataLoading = true;
    });

    try {
      String login = _loginController.text.trim();
      String password = _passwordController.text;
      String confirmPassword = _confirmPasswordController.text;
      
      if (login.isEmpty) {
        throw 'Логин не может быть пустым';
      }
      
      if (login.contains(RegExp(r'[а-яА-Я]'))) {
        throw 'Логин не может содержать русские буквы';
      }
      
      if (password.isNotEmpty) {
        if (password.length < 6) {
          throw 'Пароль должен быть не менее 6 символов';
        }
        
        if (password != confirmPassword) {
          throw 'Пароли не совпадают';
        }
        
        // Обновляем пароль
        await _authService.updatePassword(password);
      }
      
      // Обновляем данные пользователя
      await _authService.updateUserData({
        'displayName': login
      });
      
      // Обновляем данные в UI
      await _loadUserData();
      
      // Закрываем диалог
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Данные успешно сохранены')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUserDataLoading = false;
        });
      }
    }
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
                  onPressed: _signOut,
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
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      // В случае ошибки показываем уведомление
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при выходе из аккаунта: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
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
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => destination),
          );
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
    _loginController.text = _displayName;
    _passwordController.clear();
    _confirmPasswordController.clear();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
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
                    TextField(
                      controller: _loginController,
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
                            setState(() {
                              _isPasswordHidden = !_isPasswordHidden;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _confirmPasswordController,
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
                            setState(() {
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
                    _isUserDataLoading
                        ? const CircularProgressIndicator(
                            color: Color(0xFF50321B),
                            strokeWidth: 3,
                          )
                        : TextButton(
                            onPressed: _saveUserData,
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