import 'package:flutter/material.dart';
import 'package:ararat/screens/registration/registration_screen.dart';
import 'package:ararat/screens/login/login_screen.dart';
import 'package:ararat/screens/main_screen.dart';
import 'package:ararat/utils/font_loader.dart';
import 'package:ararat/services/image_cache_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:ararat/screens/product/add_product_screen.dart';
import 'package:ararat/screens/product/product_list_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyAppLoader());
}

class MyAppLoader extends StatelessWidget {
  const MyAppLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ARARAT',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF50321B)),
        useMaterial3: true,
      ),
      home: FutureBuilder(
        future: _initializeApp(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return const MyApp();
          }
          
          // Пока идет загрузка, показываем индикатор
          return const Scaffold(
            backgroundColor: Color(0xFFFAF6F1),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF50321B),
              ),
            ),
          );
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
  
  Future<void> _initializeApp() async {
    try {
      print('Инициализация Firebase...');
      
      // Инициализируем Firebase с обновленными настройками
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      print('Firebase успешно инициализирован');
      
      // Проверяем аутентификацию
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;
      if (user != null) {
        print('Пользователь авторизован: ${user.uid}');
        print('Email: ${user.email}');
        print('Анонимная авторизация: ${user.isAnonymous}');
      } else {
        print('Пользователь не авторизован');
      }
      
      // Проверяем доступ к Firestore
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
    } catch (e) {
      print('Ошибка инициализации приложения: $e');
      // Продолжаем выполнение даже при ошибке Firebase
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ARARAT',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF50321B)),
        useMaterial3: true,
        fontFamily: 'Inter',
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontFamily: 'Inter'),
          bodyMedium: TextStyle(fontFamily: 'Inter'),
          bodySmall: TextStyle(fontFamily: 'Inter'),
          titleLarge: TextStyle(fontFamily: 'Inter'),
          titleMedium: TextStyle(fontFamily: 'Inter'),
          titleSmall: TextStyle(fontFamily: 'Inter'),
          displayLarge: TextStyle(fontFamily: 'Inter'),
          displayMedium: TextStyle(fontFamily: 'Inter'),
          displaySmall: TextStyle(fontFamily: 'Inter'),
          headlineLarge: TextStyle(fontFamily: 'Inter'),
          headlineMedium: TextStyle(fontFamily: 'Inter'),
          headlineSmall: TextStyle(fontFamily: 'Inter'),
          labelLarge: TextStyle(fontFamily: 'Inter'),
          labelMedium: TextStyle(fontFamily: 'Inter'),
          labelSmall: TextStyle(fontFamily: 'Inter'),
        ),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/registration': (context) => const RegistrationScreen(),
        '/main': (context) => const MainScreen(),
        '/add_product': (context) => const AddProductScreen(),
        '/product_list': (context) => const ProductListScreen(),
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const Scaffold(
            body: Center(
              child: Text('Страница не найдена'),
            ),
          ),
        );
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
