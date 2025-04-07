import 'package:flutter/material.dart';
import 'package:ararat/screens/main/tabs/history_tab.dart';
import 'package:ararat/screens/main/tabs/favorites_tab.dart';
import 'package:ararat/screens/main/tabs/home_tab.dart';
import 'package:ararat/screens/main/tabs/cart_tab.dart';
import 'package:ararat/screens/main/tabs/profile_tab.dart';

// Класс уведомления для переключения вкладок
class HomeTabNavigationRequest extends Notification {
  final int tabIndex;
  
  HomeTabNavigationRequest(this.tabIndex);
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 2; // Начинаем с главной вкладки (по центру)
  
  final List<Widget> _tabs = [
    const HistoryTab(),
    const FavoritesTab(),
    const HomeTab(),
    const CartTab(),
    const ProfileTab(),
  ];
  
  // Менеджеры для доступа к количеству избранных товаров и товаров в корзине
  final _favoritesManager = FavoritesManager();
  final _cartManager = CartManager();

  @override
  Widget build(BuildContext context) {
    return NotificationListener<HomeTabNavigationRequest>(
      onNotification: (notification) {
        setState(() {
          _currentIndex = notification.tabIndex;
        });
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF6F1),
        body: _tabs[_currentIndex],
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              selectedItemColor: const Color(0xFF6C4425),
              unselectedItemColor: Colors.grey,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              selectedLabelStyle: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              showUnselectedLabels: true,
              showSelectedLabels: true,
              elevation: 8,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              items: [
                BottomNavigationBarItem(
                  icon: Image.asset(
                    'assets/icons/history.png',
                    width: 24,
                    height: 24,
                    color: Colors.grey,
                  ),
                  activeIcon: Image.asset(
                    'assets/icons/history.png',
                    width: 24,
                    height: 24,
                    color: const Color(0xFF6C4425),
                  ),
                  label: 'История',
                ),
                BottomNavigationBarItem(
                  icon: ValueListenableBuilder<List<Map<String, dynamic>>>(
                    valueListenable: _favoritesManager.favoritesNotifier,
                    builder: (context, favoritesList, child) {
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Image.asset(
                            'assets/icons/fav.png',
                            width: 24,
                            height: 24,
                            color: Colors.grey,
                          ),
                          if (favoritesList.isNotEmpty)
                            Positioned(
                              right: -6,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Center(
                                  child: Text(
                                    favoritesList.length > 9 ? '9+' : '${favoritesList.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  activeIcon: ValueListenableBuilder<List<Map<String, dynamic>>>(
                    valueListenable: _favoritesManager.favoritesNotifier,
                    builder: (context, favoritesList, child) {
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Image.asset(
                            'assets/icons/fav.png',
                            width: 24,
                            height: 24,
                            color: const Color(0xFF6C4425),
                          ),
                          if (favoritesList.isNotEmpty)
                            Positioned(
                              right: -6,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Center(
                                  child: Text(
                                    favoritesList.length > 9 ? '9+' : '${favoritesList.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  label: 'Избранное',
                ),
                BottomNavigationBarItem(
                  icon: Image.asset(
                    'assets/icons/home.png',
                    width: 24,
                    height: 24,
                    color: Colors.grey,
                  ),
                  activeIcon: Image.asset(
                    'assets/icons/home.png',
                    width: 24,
                    height: 24,
                    color: const Color(0xFF6C4425),
                  ),
                  label: 'Главная',
                ),
                BottomNavigationBarItem(
                  icon: ValueListenableBuilder<List<Map<String, dynamic>>>(
                    valueListenable: _cartManager.cartNotifier,
                    builder: (context, cartList, child) {
                      final itemCount = _cartManager.getCartItemsCount();
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Image.asset(
                            'assets/icons/basket.png',
                            width: 24,
                            height: 24,
                            color: Colors.grey,
                          ),
                          if (itemCount > 0)
                            Positioned(
                              right: -6,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Center(
                                  child: Text(
                                    itemCount > 9 ? '9+' : '$itemCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  activeIcon: ValueListenableBuilder<List<Map<String, dynamic>>>(
                    valueListenable: _cartManager.cartNotifier,
                    builder: (context, cartList, child) {
                      final itemCount = _cartManager.getCartItemsCount();
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Image.asset(
                            'assets/icons/basket.png',
                            width: 24,
                            height: 24,
                            color: const Color(0xFF6C4425),
                          ),
                          if (itemCount > 0)
                            Positioned(
                              right: -6,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Center(
                                  child: Text(
                                    itemCount > 9 ? '9+' : '$itemCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  label: 'Корзина',
                ),
                BottomNavigationBarItem(
                  icon: Image.asset(
                    'assets/icons/profile.png',
                    width: 24,
                    height: 24,
                    color: Colors.grey,
                  ),
                  activeIcon: Image.asset(
                    'assets/icons/profile.png',
                    width: 24,
                    height: 24,
                    color: const Color(0xFF6C4425),
                  ),
                  label: 'Профиль',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 