import 'package:flutter/material.dart';
import 'package:ararat/screens/registration/registration_screen.dart';
import 'package:ararat/screens/login/login_screen.dart';
import 'package:ararat/screens/main/main_screen.dart';
import 'package:ararat/screens/main/tabs/other_profile_tabs/orders_tab.dart';
import 'package:ararat/utils/font_loader.dart';
import 'package:ararat/services/image_cache_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:ararat/screens/product/product_list_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Обработчик фоновых сообщений
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // Проверяем инициализирован ли Firebase
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    print('Получено фоновое сообщение: ${message.messageId}');
  } catch (e) {
    print('Ошибка в обработчике фоновых сообщений: $e');
  }
}

// Канал для уведомлений
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'Уведомления о заказах',
  description: 'Этот канал используется для важных уведомлений о заказах',
  importance: Importance.high,
);

// Инициализация локальных уведомлений
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Инициализация Firebase
  try {
    // Проверяем инициализирован ли Firebase
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    print('Ошибка при инициализации Firebase: $e');
  }
  
  // Настройка обработчика фоновых сообщений
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Инициализация локальных уведомлений
  await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
      
  // Настройка параметров iOS уведомлений
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );
  
  runApp(const MyAppLoader());
}

class MyAppLoader extends StatefulWidget {
  const MyAppLoader({super.key});

  @override
  State<MyAppLoader> createState() => _MyAppLoaderState();
}

class _MyAppLoaderState extends State<MyAppLoader> {
  bool _initialized = false;
  bool _error = false;

  // Настройка Firebase
  Future<void> _initializeApp() async {
    try {
      // Проверка соединения с Firestore
      try {
        print('Проверка соединения с Firestore...');
        final testDoc = await FirebaseFirestore.instance
            .collection('system')
            .doc('app_info')
            .get();
        
        if (!testDoc.exists) {
          // Создаем тестовый документ
          await FirebaseFirestore.instance
              .collection('system')
              .doc('app_info')
              .set({
                'appName': 'ARARAT',
                'version': '1.0.0',
                'lastStarted': FieldValue.serverTimestamp(),
              });
          print('Тестовый документ в Firestore создан');
        } else {
          // Обновляем существующий документ
          await FirebaseFirestore.instance
              .collection('system')
              .doc('app_info')
              .update({
                'lastStarted': FieldValue.serverTimestamp(),
              });
          print('Тестовый документ в Firestore обновлен');
        }
        
        print('Соединение с Firestore установлено');
      } catch (e) {
        print('Ошибка при проверке соединения с Firestore: $e');
      }
      
      // Загружаем шрифты
      await FontLoader.loadFonts();
      print('Шрифты загружены');
      
      // Инициализируем кэш для изображений
      print('Инициализация кэша изображений...');
      try {
        // Запускаем инициализацию в фоне, чтобы не блокировать запуск приложения
        ImageCacheService().initialize().then((_) {
          print('Кэш изображений инициализирован');
        });
      } catch (e) {
        print('Ошибка при инициализации кэша изображений: $e');
      }
      
      // Настройка обработчиков сообщений
      _setupMessaging();
      
      setState(() {
        _initialized = true;
      });
    } catch (e) {
      print('Ошибка инициализации: $e');
      setState(() {
        _error = true;
      });
    }
  }
  
  // Настройка Firebase Messaging
  Future<void> _setupMessaging() async {
    try {
      // Получение токена устройства
      final token = await FirebaseMessaging.instance.getToken();
      print('FCM Token получен: $token');
      
      // Сохраняем токен в Firestore для текущего пользователя
      if (token != null) {
        _saveUserToken(token);
      } else {
        print('ОШИБКА: FCM токен не получен!');
      }
      
      // Обработка при получении нового токена
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        print('FCM Token обновлен: $newToken');
        _saveUserToken(newToken);
      });
      
      // Обработка сообщений при открытом приложении
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('ПОЛУЧЕНО СООБЩЕНИЕ: ${message.notification?.title}');
        print('Данные сообщения: ${message.data}');
        
        final notification = message.notification;
        final android = message.notification?.android;
        
        if (notification != null && android != null) {
          print('Показываем локальное уведомление для Android');
          try {
            flutterLocalNotificationsPlugin.show(
              notification.hashCode,
              notification.title,
              notification.body,
              NotificationDetails(
                android: AndroidNotificationDetails(
                  channel.id,
                  channel.name,
                  channelDescription: channel.description,
                  icon: 'launch_background',
                  importance: Importance.high,
                  priority: Priority.high,
                ),
              ),
              payload: message.data['orderId'],
            );
            print('Локальное уведомление показано успешно');
          } catch (e) {
            print('ОШИБКА при показе локального уведомления: $e');
          }
        } else {
          print('Не удалось показать уведомление: notification=${notification != null}, android=${android != null}');
        }
      });
      
      // Тестовое локальное уведомление для проверки
      await Future.delayed(const Duration(seconds: 5));
      try {
        print('Отправка тестового локального уведомления...');
        await flutterLocalNotificationsPlugin.show(
          0,
          'Тестовое уведомление',
          'Проверка работы уведомлений',
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: 'launch_background',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
        print('Тестовое локальное уведомление отправлено успешно');
      } catch (e) {
        print('ОШИБКА при отправке тестового уведомления: $e');
      }
      
      // Обработка нажатия на уведомление
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('Нажатие на уведомление: ${message.notification?.title}');
        _handleNotificationClick(message);
      });
      
      // Проверка, было ли приложение открыто по нажатию на уведомление
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationClick(initialMessage);
      }
      
      // Запрос разрешений для iOS
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      
      print('Статус разрешений на уведомления: ${settings.authorizationStatus}');
      
    } catch (e) {
      print('Ошибка при настройке уведомлений: $e');
    }
  }
  
  // Сохраняем токен устройства пользователя
  Future<void> _saveUserToken(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('tokens')
            .doc(token)
            .set({
              'token': token,
              'platform': _getPlatform(),
              'createdAt': FieldValue.serverTimestamp(),
              'lastUpdated': FieldValue.serverTimestamp(),
            });
        
        print('FCM токен сохранен для пользователя ${user.uid}');
      }
    } catch (e) {
      print('Ошибка при сохранении токена: $e');
    }
  }
  
  // Определяем платформу устройства
  String _getPlatform() {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return 'iOS';
    } else if (Theme.of(context).platform == TargetPlatform.android) {
      return 'Android';
    } else {
      return 'web';
    }
  }
  
  // Обработка нажатия на уведомление
  void _handleNotificationClick(RemoteMessage message) {
    try {
      // Здесь можно добавить навигацию на экран заказа
      print('Обработка нажатия на уведомление');
      
      final orderId = message.data['orderId'];
      if (orderId != null && orderId.isNotEmpty) {
        // Дополнительная логика навигации будет добавлена позже
        print('Открытие деталей заказа: $orderId');
      }
    } catch (e) {
      print('Ошибка при обработке нажатия на уведомление: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  Widget build(BuildContext context) {
    // Показываем индикатор загрузки, пока приложение инициализируется
    if (!_initialized) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/logo/logo-ararat-final.png',
                  width: 120,
                  height: 120,
                ),
                const SizedBox(height: 20),
                const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      );
    }

    // Показываем сообщение об ошибке, если что-то пошло не так
    if (_error) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Произошла ошибка при загрузке приложения'),
          ),
        ),
      );
    }

    // Основное приложение
    return MaterialApp(
      title: 'ARARAT',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF50321B)),
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      home: FirebaseAuth.instance.currentUser != null
          ? const MainScreen()
          : const LoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/registration': (context) => const RegistrationScreen(),
        '/main': (context) => const MainScreen(),
        '/profile/orders': (context) => const OrdersTab(),
        '/product_list': (context) => const ProductListScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
