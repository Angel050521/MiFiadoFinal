import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // <-- Añadido
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize(); // <-- Inicializa AdMob
  runApp(const FiadosApp());
}

class FiadosApp extends StatelessWidget {
  const FiadosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi fiado',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
