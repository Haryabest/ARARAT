import 'package:flutter/material.dart';
import 'package:ararat/constants/colors.dart';
import 'package:ararat/screens/main/tabs/profile_tab.dart';
import 'package:ararat/screens/main/tabs/orders_tab.dart';
import 'package:ararat/screens/main/tabs/products_tab.dart';
import 'package:ararat/screens/main/tabs/users_tab.dart';

/// Главный экран админ-панели после авторизации
class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // Список экранов для каждой вкладки
  final List<Widget> _screens = [
    const ProfileTab(),
    const OrdersTab(),
    const ProductsTab(),
    const UsersTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'ARARAT ADMIN',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.inactive,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Профиль',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag),
            label: 'Заказы',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Товары',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Пользователи',
          ),
        ],
      ),
    );
  }
} 