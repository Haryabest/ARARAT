import 'package:flutter/material.dart';
import 'package:ararat/screens/main/tabs/other_profile_tabs/orders_tab.dart';
import 'package:ararat/screens/main/tabs/other_profile_tabs/delivery_addresses_tab.dart';
import 'package:ararat/screens/main/tabs/other_profile_tabs/payment_methods_tab.dart';
import 'package:ararat/screens/main/tabs/other_profile_tabs/notifications_tab.dart';
import 'package:ararat/screens/main/tabs/other_profile_tabs/settings_tab.dart';
import 'package:ararat/screens/main/tabs/other_profile_tabs/support_tab.dart';
import 'package:ararat/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final AuthService _authService = AuthService();
  String _displayName = '';
  String _email = '';
  bool _isLoading = true;

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
      
      // Пробуем получить дополнительные данные из Firestore
      Map<String, dynamic>? userData = await _authService.getUserData();
      if (userData != null) {
        // Если в Firestore есть данные, используем их
        if (userData['displayName'] != null) {
          displayName = userData['displayName'];
        }
      }

      setState(() {
        _displayName = displayName;
        _email = email;
        _isLoading = false;
      });
    } else {
      setState(() {
        _displayName = 'Не авторизован';
        _email = '';
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      await _authService.signOut();
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при выходе: $e')),
      );
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
                    Container(
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
                          : const Center(
                              child: Icon(
                                Icons.person,
                                size: 35,
                                color: Color(0xFF50321B),
                              ),
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
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
                                Text(
                                  _displayName,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF50321B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
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
              _menuItem(
                context,
                Icons.settings,
                'Настройки',
                const SettingsTab(),
              ),
              _menuItem(
                context,
                Icons.help,
                'Справка и поддержка',
                const SupportTab(),
              ),
              
              const Spacer(),
              
              // Кнопка выхода
              SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: _signOut,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF50321B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(
                    Icons.logout,
                    size: 18,
                  ),
                  label: const Text(
                    'Выйти из аккаунта',
                    style: TextStyle(
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
} 