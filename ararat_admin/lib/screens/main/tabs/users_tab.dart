import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ararat/constants/colors.dart';
import 'package:ararat/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UsersTab extends StatefulWidget {
  const UsersTab({super.key});

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await _firestore.collection('users').get();
      
      final users = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      
      if (!mounted) return;
      
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при загрузке пользователей: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.people_outline,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Пользователи отсутствуют',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loadUsers,
                        child: const Text('Обновить'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadUsers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      final email = user['email'] as String? ?? 'Нет email';
                      final displayName = user['displayName'] as String? ?? 'Пользователь';
                      final role = user['role'] as String? ?? AuthService.ROLE_USER;
                      final isAdmin = role == AuthService.ROLE_ADMIN;
                      final timestamp = user['createdAt'] as Timestamp?;
                      final date = timestamp != null
                          ? DateTime.fromMillisecondsSinceEpoch(
                              timestamp.millisecondsSinceEpoch)
                          : null;
                      final formattedDate = date != null
                          ? '${date.day}.${date.month}.${date.year}'
                          : 'Нет данных';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isAdmin ? AppColors.primary : Colors.grey[300],
                            child: Text(
                              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                              style: TextStyle(
                                color: isAdmin ? Colors.white : Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(email),
                              Text(
                                'Дата регистрации: $formattedDate',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isAdmin ? AppColors.primary.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isAdmin ? 'Администратор' : 'Пользователь',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isAdmin ? AppColors.primary : Colors.grey[600],
                              ),
                            ),
                          ),
                          onTap: () {
                            // Показать подробную информацию о пользователе
                            _showUserDetails(user);
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  void _showUserDetails(Map<String, dynamic> user) {
    final email = user['email'] as String? ?? 'Нет email';
    final displayName = user['displayName'] as String? ?? 'Пользователь';
    final role = user['role'] as String? ?? AuthService.ROLE_USER;
    final isAdmin = role == AuthService.ROLE_ADMIN;
    
    // Получаем текущего пользователя
    final currentUser = FirebaseAuth.instance.currentUser;
    
    // Определяем, может ли текущий пользователь менять роль этого пользователя
    // Администратор может понизить только себя, но не других администраторов
    final canChangeRole = !isAdmin || (currentUser != null && currentUser.uid == user['id']);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Информация о пользователе'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: const Text('Имя'),
              subtitle: Text(displayName),
            ),
            ListTile(
              title: const Text('Email'),
              subtitle: Text(email),
            ),
            ListTile(
              title: const Text('Роль'),
              subtitle: Text(isAdmin ? 'Администратор' : 'Пользователь'),
            ),
            if (isAdmin && !canChangeRole)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Примечание: Вы не можете изменить роль другого администратора',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Закрыть'),
          ),
          TextButton(
            onPressed: canChangeRole
                ? () {
                    // Изменить роль пользователя
                    _changeUserRole(user);
                    Navigator.of(context).pop();
                  }
                : null, // Кнопка будет неактивна, если нельзя менять роль
            style: TextButton.styleFrom(
              foregroundColor: canChangeRole ? null : Colors.grey,
            ),
            child: Text(isAdmin ? 'Сделать пользователем' : 'Сделать администратором'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeUserRole(Map<String, dynamic> user) async {
    final userId = user['id'];
    final email = user['email'] as String? ?? '';
    final displayName = user['displayName'] as String? ?? 'Пользователь';
    final currentRole = user['role'] as String? ?? AuthService.ROLE_USER;
    final newRole = currentRole == AuthService.ROLE_ADMIN
        ? AuthService.ROLE_USER
        : AuthService.ROLE_ADMIN;
    
    // Получаем текущего пользователя (администратора, который выполняет действие)
    final currentUser = FirebaseAuth.instance.currentUser;
    
    // Проверяем, не пытается ли администратор понизить роль другого администратора
    if (currentRole == AuthService.ROLE_ADMIN && newRole == AuthService.ROLE_USER) {
      // Если ID текущего пользователя не совпадает с ID пользователя, которого мы хотим понизить
      if (currentUser != null && userId != currentUser.uid) {
        // Показываем сообщение об ошибке
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Вы не можете понизить роль другого администратора'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return; // Прерываем выполнение метода
      }
    }

    try {
      // Обновляем роль в документе пользователя
      await _firestore.collection('users').doc(userId).update({
        'role': newRole,
        'roleUpdatedAt': FieldValue.serverTimestamp(),
      });
      
      // Если новая роль - администратор, добавляем в коллекцию admins
      if (newRole == AuthService.ROLE_ADMIN) {
        print('Добавление пользователя в коллекцию admins: $userId');
        Map<String, dynamic> adminData = {
          'email': email,
          'displayName': displayName,
          'createdAt': FieldValue.serverTimestamp(),
          'addedBy': 'admin_panel',
        };
        await _firestore.collection('admins').doc(userId).set(adminData);
        print('Пользователь успешно добавлен в коллекцию admins');
      } 
      // Если роль была понижена с администратора до обычного пользователя, удаляем из коллекции admins
      else if (currentRole == AuthService.ROLE_ADMIN && newRole == AuthService.ROLE_USER) {
        print('Удаление пользователя из коллекции admins: $userId');
        await _firestore.collection('admins').doc(userId).delete();
        print('Пользователь успешно удален из коллекции admins');
      }
      
      // Проверяем mounted перед обновлением списка пользователей
      if (!mounted) return;
      
      // Обновляем список пользователей
      await _loadUsers();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newRole == AuthService.ROLE_ADMIN 
              ? 'Пользователь назначен администратором' 
              : 'Пользователь лишен прав администратора'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Ошибка при изменении роли пользователя: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при изменении роли: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 