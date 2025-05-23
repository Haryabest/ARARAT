import 'package:flutter/material.dart';
import 'package:ararat/screens/main/tabs/home_tab.dart';
import 'package:ararat/screens/main/main_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FavoritesTab extends StatefulWidget {
  const FavoritesTab({super.key});

  @override
  State<FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends State<FavoritesTab> {
  // Используем общий менеджер избранного
  final _favoritesManager = FavoritesManager();
  // Добавляем менеджер корзины
  final _cartManager = CartManager();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFA99378),
      body: SafeArea(
        bottom: false, // Важно отключить отступ безопасной зоны снизу
        child: ValueListenableBuilder<List<Map<String, dynamic>>>(
          valueListenable: _favoritesManager.favoritesNotifier,
          builder: (context, favoritesList, child) {
            if (favoritesList.isEmpty) {
              return _buildEmptyState();
            }
            
            return ListView.builder(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 90), // Больший отступ снизу для навигации
              itemCount: favoritesList.length,
              itemBuilder: (context, index) {
                final item = favoritesList[index];
                return _buildFavoriteItem(item, index);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite,
            size: 80,
            color: Colors.white.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          const Text(
            'Ничего нет',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Добавляйте товары в избранное, чтобы вернуться к ним позже',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.normal,
              color: Color(0xFFD5D5D5),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                onPressed: () {
                  // Переход на главную страницу
                  HomeTabNavigationRequest(2).dispatch(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF50321B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                  splashFactory: NoSplash.splashFactory,
                ),
                child: const Text(
                  'Каталог',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteItem(Map<String, dynamic> item, int index) {
    final String productName = item['name'];
    final int originalQuantity = item['originalQuantity'] ?? 1;
    
    // Получаем локальное доступное количество товара
    final int localQuantity = _cartManager.getLocalQuantity(productName, originalQuantity);
    final bool canAddToCart = localQuantity > 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF6C4425),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Изображение товара
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 80,
                        height: 80,
                        child: item['imageUrl'] != null 
                            ? CachedNetworkImage(
                                imageUrl: item['imageUrl'],
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF4B260A),
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.white,
                                  child: const Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey,
                                  ),
                                ),
                              )
                            : Image.asset(
                                'assets/icons/placeholder.png',
                                fit: BoxFit.cover,
                                width: 80,
                                height: 80,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Информация о товаре
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'],
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item['price']}₽',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            item['weight'],
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Color(0xFF8E8B8B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            canAddToCart ? 'Доступно: $localQuantity шт' : 'Нет в наличии',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: canAddToCart ? Colors.white70 : Colors.red[300],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Кнопка добавления в корзину
              Container(
                width: double.infinity,
                height: 40,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: ElevatedButton(
                  onPressed: canAddToCart ? () {
                    // Добавляем товар в корзину (один раз)
                    final product = {
                      'name': item['name'],
                      'price': item['price'],
                      'weight': item['weight'],
                      'imageUrl': item['imageUrl'],
                      'quantity': originalQuantity,
                      'inStock': true,
                    };
                    
                    _cartManager.addToCart(product);
                    
                    // Обновляем UI для отображения нового локального количества
                    setState(() {});
                    
                    // Показываем уведомление
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${item['name']} добавлен в корзину'),
                        backgroundColor: const Color(0xFF6C4425),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canAddToCart ? const Color(0xFF4B260A) : Colors.grey[400],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text(
                    'Добавить в корзину',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // Кнопка удаления из избранного в правом верхнем углу
          Positioned(
            top: 10,
            right: 10,
            child: GestureDetector(
              onTap: () {
                _favoritesManager.removeFromFavorites(item['name']);
              },
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: Colors.red,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 