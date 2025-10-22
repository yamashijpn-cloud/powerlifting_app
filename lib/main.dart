import 'package:flutter/material.dart';
import 'package:powerlifting_app/screens/big3_screen.dart';
import 'package:powerlifting_app/screens/plan_screen.dart';
import 'package:powerlifting_app/screens/profile_screen.dart';
import 'package:powerlifting_app/screens/records_screen.dart';
import 'package:intl/date_symbol_data_local.dart'; // 追加
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async { // asyncを追加
  WidgetsFlutterBinding.ensureInitialized(); // 追加
  await initializeDateFormatting('ja_JP', null); // 追加
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    PlanScreen(), // トレーニング
    RecordsScreen(), // 記録
    Big3Screen(), // BIG3
    ProfileScreen(), // 個人情報
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Powerlifting App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja', ''), // Japanese
      ],
      home: Scaffold(

        body: Center(
          child: _widgetOptions.elementAt(_selectedIndex),
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed, // Add this line
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.fitness_center),
              label: 'トレーニング',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt),
              label: '記録',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.sports_gymnastics),
              label: 'BIG3',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: '個人情報',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.blue,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}