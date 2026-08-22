import 'package:flutter/material.dart';
import 'features/home/home_page.dart';
import 'package:device_preview/device_preview.dart';
import 'data/money_manager_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = SqliteMoneyManagerRepository();
  runApp(DevicePreview(builder: ((context) => MyApp(repository: repository))));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.repository});

  final MoneyManagerRepository repository;

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jieddev Money Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: MoneyManagerHomePage(repository: repository),
    );
  }
}
