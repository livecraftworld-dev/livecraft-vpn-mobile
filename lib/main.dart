import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: LiveCraftTheme.background,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const LiveCraftVpnApp());
}

class LiveCraftVpnApp extends StatelessWidget {
  const LiveCraftVpnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Live Craft VPN',
      debugShowCheckedModeBanner: false,
      theme: LiveCraftTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
