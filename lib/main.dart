import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_miniproject/config/default_theme.dart';
import 'package:delivery_miniproject/firebase_options.dart';
import 'package:delivery_miniproject/pages/registerPage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: defaultTheme.theme,
      themeMode: ThemeMode.light,
      home: RegisterPage(),
    );
  }
}
